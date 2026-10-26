"""Platform administrator endpoints for pharmacy onboarding and oversight."""

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import func, or_
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.auth.dependencies import require_platform_admin
from app.database import get_local_db
from app.schemas.common import PaginatedResponse
from app.models.pharmacy import Pharmacy
from app.models.pos_sale import POSSale
from app.models.sales import Sale
from app.models.user import User, UserRole
from app.schemas.pharmacy import (
    PLAN_MAX_USERS,
    PharmacyOnboardRequest,
    PharmacyOnboardResponse,
    PharmacyResponse,
    PharmacyStatusRequest,
    PharmacyUpdateRequest,
    PlatformAccountCreateRequest,
    PlatformAccountResponse,
    PlatformMetricsResponse,
    PlatformPasswordResetRequest,
    PlatformPharmacyMetricsResponse,
)
from app.utils.security import hash_password
from app.utils.security import verify_password

router = APIRouter()


def _pharmacy_or_404(db: Session, pharmacy_id: int) -> Pharmacy:
    pharmacy = db.query(Pharmacy).filter(Pharmacy.id == pharmacy_id).first()
    if pharmacy is None:
        raise HTTPException(status_code=404, detail="Pharmacy not found")
    return pharmacy


def _metrics(db: Session, pharmacy_id: int | None = None) -> dict:
    pharmacy_filter = []
    if pharmacy_id is not None:
        pharmacy_filter = [Pharmacy.id == pharmacy_id]

    pharmacies = db.query(Pharmacy).filter(*pharmacy_filter)
    user_query = db.query(func.count(User.id))
    legacy_sales = db.query(
        func.count(Sale.id), func.coalesce(func.sum(Sale.total_amount), 0.0)
    )
    pos_sales = db.query(
        func.count(POSSale.id), func.coalesce(func.sum(POSSale.total_amount), 0.0)
    )
    if pharmacy_id is not None:
        user_query = user_query.filter(User.pharmacy_id == pharmacy_id)
        legacy_sales = legacy_sales.filter(Sale.pharmacy_id == pharmacy_id)
        pos_sales = pos_sales.filter(POSSale.pharmacy_id == pharmacy_id)

    legacy_count, legacy_revenue = legacy_sales.one()
    pos_count, pos_revenue = pos_sales.one()
    return {
        "pharmacy_count": pharmacies.count() if pharmacy_id is None else 1,
        "active_pharmacy_count": pharmacies.filter(Pharmacy.is_active.is_(True)).count(),
        "user_count": user_query.scalar() or 0,
        "sale_count": int(legacy_count or 0) + int(pos_count or 0),
        "total_revenue": float(legacy_revenue or 0) + float(pos_revenue or 0),
    }


@router.get("/pharmacies", response_model=PaginatedResponse[PharmacyResponse])
def list_pharmacies(
    page: int = Query(1, ge=1),
    page_size: int = Query(25, ge=1, le=100),
    search: str | None = Query(None, max_length=100),
    _admin: User = Depends(require_platform_admin),
    db: Session = Depends(get_local_db),
):
    query = db.query(Pharmacy)
    search_term = (search or "").strip()
    if search_term:
        pattern = f"%{search_term}%"
        query = query.filter(or_(
            Pharmacy.name.ilike(pattern),
            Pharmacy.code.ilike(pattern),
            Pharmacy.city.ilike(pattern),
        ))

    total = query.count()
    pharmacies = (
        query.order_by(Pharmacy.name.asc(), Pharmacy.id.asc())
        .offset((page - 1) * page_size)
        .limit(page_size)
        .all()
    )
    return PaginatedResponse.create(
        items=pharmacies,
        total=total,
        page=page,
        page_size=page_size,
    )


@router.get("/pharmacies/{pharmacy_id}", response_model=PharmacyResponse)
def get_pharmacy(
    pharmacy_id: int,
    _admin: User = Depends(require_platform_admin),
    db: Session = Depends(get_local_db),
):
    return _pharmacy_or_404(db, pharmacy_id)


@router.post(
    "/pharmacies",
    response_model=PharmacyOnboardResponse,
    status_code=status.HTTP_201_CREATED,
)
def onboard_pharmacy(
    payload: PharmacyOnboardRequest,
    _admin: User = Depends(require_platform_admin),
    db: Session = Depends(get_local_db),
):
    if db.query(Pharmacy).filter(Pharmacy.code == payload.code).first():
        raise HTTPException(status_code=409, detail="Pharmacy code already exists")
    if db.query(User).filter(User.username == payload.admin_username).first():
        raise HTTPException(status_code=409, detail="Admin username already exists")

    pharmacy = Pharmacy(
        name=payload.name,
        code=payload.code,
        address=payload.address,
        phone=payload.phone,
        email=payload.email,
        country=payload.country,
        city=payload.city,
        plan=payload.plan,
        max_users=payload.max_users,
        license_expires_at=payload.license_expires_at,
        license_is_trial=payload.license_is_trial,
        notes=payload.notes,
        is_active=True,
    )
    db.add(pharmacy)
    try:
        db.flush()
        pharmacy_admin = User(
            username=payload.admin_username,
            password_hash=hash_password(payload.admin_password),
            role=UserRole.ADMIN,
            is_active=True,
            must_change_password=True,
            pharmacy_id=pharmacy.id,
        )
        db.add(pharmacy_admin)
        db.commit()
        db.refresh(pharmacy)
    except IntegrityError as exc:
        db.rollback()
        raise HTTPException(status_code=409, detail="Pharmacy or admin already exists") from exc

    return {"pharmacy": pharmacy, "admin_username": pharmacy_admin.username}


@router.put("/pharmacies/{pharmacy_id}", response_model=PharmacyResponse)
def update_pharmacy(
    pharmacy_id: int,
    payload: PharmacyUpdateRequest,
    _admin: User = Depends(require_platform_admin),
    db: Session = Depends(get_local_db),
):
    pharmacy = _pharmacy_or_404(db, pharmacy_id)
    updates = payload.model_dump(exclude_unset=True)
    updated_plan = updates.get("plan", pharmacy.plan)
    updated_max_users = updates.get("max_users", pharmacy.max_users)
    if updated_max_users > PLAN_MAX_USERS.get(updated_plan, 0):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"The {updated_plan} plan allows at most {PLAN_MAX_USERS.get(updated_plan, 0)} users",
        )

    if "max_users" in updates:
        active_user_count = db.query(func.count(User.id)).filter(
            User.pharmacy_id == pharmacy.id,
            User.is_active.is_(True),
        ).scalar() or 0
        if updates["max_users"] < 1000 and updates["max_users"] < active_user_count:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="max_users cannot be lower than active user count",
            )

    for field, value in updates.items():
        setattr(pharmacy, field, value)
    db.commit()
    db.refresh(pharmacy)
    return pharmacy


@router.patch("/pharmacies/{pharmacy_id}/status", response_model=PharmacyResponse)
def set_pharmacy_status(
    pharmacy_id: int,
    payload: PharmacyStatusRequest,
    _admin: User = Depends(require_platform_admin),
    db: Session = Depends(get_local_db),
):
    pharmacy = _pharmacy_or_404(db, pharmacy_id)
    pharmacy.is_active = payload.is_active
    db.commit()
    db.refresh(pharmacy)
    return pharmacy


@router.get("/metrics", response_model=PlatformMetricsResponse)
def get_platform_metrics(
    _admin: User = Depends(require_platform_admin),
    db: Session = Depends(get_local_db),
):
    return _metrics(db)


@router.get(
    "/pharmacies/{pharmacy_id}/metrics",
    response_model=PlatformPharmacyMetricsResponse,
)
def get_pharmacy_metrics(
    pharmacy_id: int,
    _admin: User = Depends(require_platform_admin),
    db: Session = Depends(get_local_db),
):
    pharmacy = _pharmacy_or_404(db, pharmacy_id)
    return {"pharmacy": pharmacy, **_metrics(db, pharmacy_id)}


@router.get("/accounts", response_model=list[PlatformAccountResponse])
def list_platform_accounts(
    _admin: User = Depends(require_platform_admin),
    db: Session = Depends(get_local_db),
):
    """List platform admins and pharmacy admins without exposing credentials."""
    accounts = (
        db.query(User, Pharmacy.name)
        .outerjoin(Pharmacy, User.pharmacy_id == Pharmacy.id)
        .filter(User.role.in_([UserRole.PLATFORM_ADMIN, UserRole.ADMIN]))
        .order_by(User.role.asc(), User.username.asc())
        .all()
    )
    return [
        {
            "id": user.id,
            "username": user.username,
            "role": user.role.value if isinstance(user.role, UserRole) else user.role,
            "is_active": user.is_active,
            "must_change_password": user.must_change_password,
            "pharmacy_id": user.pharmacy_id,
            "pharmacy_name": pharmacy_name,
        }
        for user, pharmacy_name in accounts
    ]


@router.post(
    "/accounts/platform-admin",
    response_model=PlatformAccountResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_platform_account(
    payload: PlatformAccountCreateRequest,
    _admin: User = Depends(require_platform_admin),
    db: Session = Depends(get_local_db),
):
    """Create a platform administrator with a forced first-login password change."""
    if db.query(User).filter(User.username == payload.username).first():
        raise HTTPException(status_code=409, detail="Username already exists")

    user = User(
        username=payload.username,
        password_hash=hash_password(payload.password),
        role=UserRole.PLATFORM_ADMIN,
        is_active=True,
        must_change_password=True,
        pharmacy_id=None,
    )
    db.add(user)
    try:
        db.commit()
        db.refresh(user)
    except IntegrityError as exc:
        db.rollback()
        raise HTTPException(status_code=409, detail="Username already exists") from exc

    return {
        "id": user.id,
        "username": user.username,
        "role": UserRole.PLATFORM_ADMIN.value,
        "is_active": user.is_active,
        "must_change_password": user.must_change_password,
        "pharmacy_id": None,
        "pharmacy_name": None,
    }


@router.put(
    "/accounts/{user_id}/password",
    status_code=status.HTTP_200_OK,
)
def reset_admin_password(
    user_id: int,
    payload: PlatformPasswordResetRequest,
    current_admin: User = Depends(require_platform_admin),
    db: Session = Depends(get_local_db),
):
    """Set a temporary password for a platform or pharmacy administrator."""
    user = db.query(User).filter(
        User.id == user_id,
        User.role.in_([UserRole.PLATFORM_ADMIN, UserRole.ADMIN]),
    ).first()
    if user is None:
        raise HTTPException(status_code=404, detail="Administrator account not found")
    if user.id == current_admin.id:
        if not payload.current_password or not verify_password(
            payload.current_password, current_admin.password_hash
        ):
            raise HTTPException(status_code=400, detail="Current password is incorrect")

    user.password_hash = hash_password(payload.temporary_password)
    user.must_change_password = True
    db.info["pharmacy_scope_enabled"] = False
    db.commit()
    return {"message": "Temporary password set; change required at next login"}
"""
License routes - Public endpoint for license status checks.
"""

from fastapi import APIRouter, Depends, Body, HTTPException, status
from sqlalchemy import func
from sqlalchemy.orm import Session
from datetime import datetime
from typing import Optional

from app.database import get_local_db
from app.core.license import license_service
from app.models.user import User
from app.models.pharmacy import Pharmacy
from app.models.settings import Settings
from app.auth.dependencies import get_current_user, get_super_admin_user_bypass_license
from app.models.user import UserRole
from app.core.license_guard import PLAN_FEATURES

router = APIRouter()

@router.get("/status")
def get_license_status(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_local_db),
):
    """
    Return the license status for the authenticated user's pharmacy.
    """
    if not current_user.is_active:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Inactive user",
        )
    if current_user.role == UserRole.PLATFORM_ADMIN:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Platform administrators do not have a pharmacy license",
        )

    pharmacy = db.query(Pharmacy).filter(
        Pharmacy.id == current_user.pharmacy_id
    ).first()
    if pharmacy is None:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="User is not assigned to a pharmacy",
        )
    plan = (pharmacy.plan or "").lower()
    if plan not in PLAN_FEATURES:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Unsupported pharmacy plan",
        )
    active_user_count = db.query(func.count(User.id)).filter(
        User.pharmacy_id == pharmacy.id,
        User.is_active.is_(True),
    ).scalar() or 0

    status = license_service.get_license_status(db)
    
    # Map backend format to frontend format
    is_expired = status["status"] == "expired"
    is_valid = status["status"] in ["valid", "warning"]
    days_remaining = status.get("days_remaining", 0)
    
    return {
        "is_valid": is_valid,
        "is_expired": is_expired,
        "days_remaining": days_remaining,
        "message": status.get("message", ""),
        "plan": plan,
        "max_users": pharmacy.max_users,
        "active_users": active_user_count,
        "available_features": sorted(PLAN_FEATURES[plan]),
    }


@router.put("/update", summary="Update license (Super Admin only)")
def update_license(
    expiration_date: str = Body(..., description="New expiration date (YYYY-MM-DD)"),
    warning_days: Optional[int] = Body(90, description="Warning threshold in days"),
    warning_message: Optional[str] = Body(None, description="Custom warning message"),
    current_user: User = Depends(get_super_admin_user_bypass_license),
    db: Session = Depends(get_local_db)
):
    """
    Update license configuration.
    Only accessible by Super Admin, even when license is expired.
    
    Args:
        expiration_date: New license expiration date (YYYY-MM-DD format)
        warning_days: Days before expiration to show warning
        warning_message: Custom message to display when license is expiring
        
    Returns:
        Updated license status
    """
    # Validate date format
    try:
        datetime.strptime(expiration_date, "%Y-%m-%d")
    except ValueError:
        return {
            "success": False,
            "message": "Format de date invalide. Utilisez YYYY-MM-DD"
        }
    
    # Update expiration date
    setting = db.query(Settings).filter(Settings.key == "license_expiry_date").first()
    if setting:
        setting.value = expiration_date
    else:
        db.add(Settings(key="license_expiry_date", value=expiration_date))
    
    # Update warning days
    if warning_days is not None:
        setting = db.query(Settings).filter(Settings.key == "license_warning_bdays").first()
        if setting:
            setting.value = str(warning_days)
        else:
            db.add(Settings(key="license_warning_bdays", value=str(warning_days)))
    
    # Update warning message
    if warning_message is not None:
        setting = db.query(Settings).filter(Settings.key == "license_warning_message").first()
        if setting:
            setting.value = warning_message
        else:
            db.add(Settings(key="license_warning_message", value=warning_message))
    
    db.commit()

    license_service.invalidate_cache()
    
    # Get updated status
    status = license_service.get_license_status(db)
    
    return {
        "success": True,
        "message": "Licence mise à jour avec succès",
        "license_status": status
    }



import secrets
from pydantic import BaseModel
from typing import List
from app.models.license_key import LicenseKey
from app.auth.dependencies import require_platform_admin

class LicenseGenerateRequest(BaseModel):
    plan: str
    duration_days: int
    max_users: int = 3
    quantity: int = 1
    notes: Optional[str] = None
    pharmacy_id: Optional[int] = None

class LicenseKeyResponse(BaseModel):
    id: int
    key: str
    plan: str
    duration_days: int
    max_users: int
    pharmacy_id: Optional[int] = None
    pharmacy_name: Optional[str] = None
    used_at: Optional[datetime] = None
    is_active: bool
    notes: Optional[str] = None
    created_at: Optional[datetime] = None

    class Config:
        from_attributes = True

class LicenseRedeemRequest(BaseModel):
    key: str

def _generate_key_string(plan: str, duration_days: int) -> str:
    prefix = {"basic": "BSC", "pro": "PRO", "enterprise": "ENT"}.get(plan.lower(), "KEY")
    token = secrets.token_hex(8).upper()
    return f"{prefix}-{token[:4]}-{token[4:8]}-{duration_days}D"

@router.post("/platform/generate", summary="Generate license keys (Platform Admin)")
def generate_license_keys(
    payload: LicenseGenerateRequest,
    current_admin: User = Depends(require_platform_admin),
    db: Session = Depends(get_local_db),
):
    created_keys = []
    qty = max(1, min(payload.quantity, 50))
    for _ in range(qty):
        key_str = _generate_key_string(payload.plan, payload.duration_days)
        # Ensure uniqueness
        while db.query(LicenseKey).filter(LicenseKey.key == key_str).first():
            key_str = _generate_key_string(payload.plan, payload.duration_days)

        l_key = LicenseKey(
            key=key_str,
            plan=payload.plan.lower(),
            duration_days=payload.duration_days,
            max_users=payload.max_users,
            created_by_id=current_admin.id,
            is_active=True,
            notes=payload.notes,
            pharmacy_id=payload.pharmacy_id,
        )
        db.add(l_key)
        created_keys.append(l_key)

    db.commit()
    return [
        {
            "id": k.id,
            "key": k.key,
            "plan": k.plan,
            "duration_days": k.duration_days,
            "max_users": k.max_users,
            "is_active": k.is_active,
            "notes": k.notes,
        }
        for k in created_keys
    ]

@router.get("/platform/keys", summary="List all generated license keys (Platform Admin)")
def list_license_keys(
    plan: Optional[str] = None,
    is_active: Optional[bool] = None,
    current_admin: User = Depends(require_platform_admin),
    db: Session = Depends(get_local_db),
):
    query = db.query(LicenseKey, Pharmacy.name).outerjoin(Pharmacy, LicenseKey.pharmacy_id == Pharmacy.id)
    if plan:
        query = query.filter(LicenseKey.plan == plan.lower())
    if is_active is not None:
        query = query.filter(LicenseKey.is_active == is_active)

    results = query.order_by(LicenseKey.id.desc()).all()
    return [
        {
            "id": k.id,
            "key": k.key,
            "plan": k.plan,
            "duration_days": k.duration_days,
            "max_users": k.max_users,
            "pharmacy_id": k.pharmacy_id,
            "pharmacy_name": p_name,
            "used_at": k.used_at.isoformat() if k.used_at else None,
            "is_active": k.is_active,
            "notes": k.notes,
            "created_at": k.created_at.isoformat() if hasattr(k, "created_at") and k.created_at else None,
        }
        for k, p_name in results
    ]

@router.put("/platform/keys/{key_id}/revoke", summary="Revoke a license key (Platform Admin)")
def revoke_license_key(
    key_id: int,
    current_admin: User = Depends(require_platform_admin),
    db: Session = Depends(get_local_db),
):
    l_key = db.query(LicenseKey).filter(LicenseKey.id == key_id).first()
    if not l_key:
        raise HTTPException(status_code=404, detail="Cle de licence non trouvee")
    if l_key.used_at:
        raise HTTPException(status_code=400, detail="Impossible de revoquer une cle deja activee")
    l_key.is_active = False
    db.commit()
    return {"message": "Cle revoquee avec succes"}

@router.post("/redeem", summary="Redeem a license key (Pharmacy Admin)")
def redeem_license_key(
    payload: LicenseRedeemRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_local_db),
):
    if not current_user.pharmacy_id:
        raise HTTPException(status_code=400, detail="Utilisateur non rattache a une pharmacie")

    pharmacy = db.query(Pharmacy).filter(Pharmacy.id == current_user.pharmacy_id).first()
    if not pharmacy:
        raise HTTPException(status_code=404, detail="Pharmacie non trouvee")

    key_clean = payload.key.strip()
    l_key = db.query(LicenseKey).filter(LicenseKey.key == key_clean).first()
    if not l_key:
        raise HTTPException(status_code=404, detail="Cle de licence invalide ou inexistante")
    if not l_key.is_active:
        raise HTTPException(status_code=400, detail="Cette cle de licence a ete revoquee ou d�sactiv�e")
    if l_key.used_at:
        raise HTTPException(status_code=400, detail="Cette cle de licence a deja ete activee")

    from datetime import date, timedelta
    today = date.today()
    current_exp = pharmacy.license_expires_at or today
    base_date = max(today, current_exp)
    new_exp = base_date + timedelta(days=l_key.duration_days)

    pharmacy.license_expires_at = new_exp
    pharmacy.plan = l_key.plan
    if l_key.max_users:
        pharmacy.max_users = l_key.max_users

    l_key.used_at = datetime.utcnow()
    l_key.pharmacy_id = pharmacy.id
    l_key.is_active = False

    db.commit()
    license_service.invalidate_cache()

    return {
        "success": True,
        "message": f"Licence renouvelee avec succes pour {l_key.duration_days} jours (Plan {l_key.plan.upper()})",
        "plan": pharmacy.plan,
        "license_expires_at": pharmacy.license_expires_at.isoformat(),
        "max_users": pharmacy.max_users,
    }

@router.get("/history", summary="License activation history (Pharmacy Admin)")
def get_license_history(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_local_db),
):
    if not current_user.pharmacy_id:
        raise HTTPException(status_code=400, detail="Utilisateur non rattache a une pharmacie")

    keys = (
        db.query(LicenseKey)
        .filter(LicenseKey.pharmacy_id == current_user.pharmacy_id)
        .order_by(LicenseKey.used_at.desc())
        .all()
    )
    return [
        {
            "id": k.id,
            "key": k.key,
            "plan": k.plan,
            "duration_days": k.duration_days,
            "used_at": k.used_at.isoformat() if k.used_at else None,
            "notes": k.notes,
        }
        for k in keys
    ]
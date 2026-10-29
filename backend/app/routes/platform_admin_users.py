"""Platform administrator management routes."""

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from pydantic import BaseModel, EmailStr
from typing import Optional, List
from datetime import datetime

from app.auth.dependencies import require_platform_admin
from app.database import get_local_db
from app.models.user import User, UserRole
from app.utils.security import hash_password

router = APIRouter(prefix="/platform/admins", tags=["Platform Admins"])


class PlatformAdminCreateRequest(BaseModel):
    username: str
    password: str
    first_name: Optional[str] = None
    last_name: Optional[str] = None
    email: Optional[str] = None
    phone: Optional[str] = None


class PlatformAdminUpdateRequest(BaseModel):
    first_name: Optional[str] = None
    last_name: Optional[str] = None
    email: Optional[str] = None
    phone: Optional[str] = None
    password: Optional[str] = None
    is_active: Optional[bool] = None


class PlatformAdminResponse(BaseModel):
    id: int
    username: str
    first_name: Optional[str] = None
    last_name: Optional[str] = None
    email: Optional[str] = None
    phone: Optional[str] = None
    is_active: bool
    is_super_platform_admin: bool = False
    created_at: Optional[datetime] = None

    class Config:
        from_attributes = True


@router.get("", response_model=List[PlatformAdminResponse])
def list_platform_admins(
    current_admin: User = Depends(require_platform_admin),
    db: Session = Depends(get_local_db),
):
    """List all platform administrators."""
    admins = (
        db.query(User)
        .filter(User.role == UserRole.PLATFORM_ADMIN)
        .order_by(User.id.asc())
        .all()
    )
    return [
        PlatformAdminResponse(
            id=admin.id,
            username=admin.username,
            first_name=admin.first_name,
            last_name=admin.last_name,
            email=admin.email,
            phone=admin.phone,
            is_active=admin.is_active,
            is_super_platform_admin=getattr(admin, "is_super_platform_admin", False),
            created_at=getattr(admin, "created_at", None),
        )
        for admin in admins
    ]


@router.post("", response_model=PlatformAdminResponse, status_code=status.HTTP_201_CREATED)
def create_platform_admin(
    payload: PlatformAdminCreateRequest,
    current_admin: User = Depends(require_platform_admin),
    db: Session = Depends(get_local_db),
):
    """Create a new platform administrator."""
    if db.query(User).filter(User.username == payload.username).first():
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Le nom d'utilisateur existe déjà",
        )

    user = User(
        username=payload.username,
        password_hash=hash_password(payload.password),
        role=UserRole.PLATFORM_ADMIN,
        first_name=payload.first_name,
        last_name=payload.last_name,
        email=payload.email,
        phone=payload.phone,
        is_active=True,
        must_change_password=True,
        pharmacy_id=None,
        is_super_platform_admin=False,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return PlatformAdminResponse(
        id=user.id,
        username=user.username,
        first_name=user.first_name,
        last_name=user.last_name,
        email=user.email,
        phone=user.phone,
        is_active=user.is_active,
        is_super_platform_admin=getattr(user, "is_super_platform_admin", False),
        created_at=getattr(user, "created_at", None),
    )


@router.put("/{admin_id}", response_model=PlatformAdminResponse)
def update_platform_admin(
    admin_id: int,
    payload: PlatformAdminUpdateRequest,
    current_admin: User = Depends(require_platform_admin),
    db: Session = Depends(get_local_db),
):
    """Update a platform administrator."""
    admin = db.query(User).filter(
        User.id == admin_id,
        User.role == UserRole.PLATFORM_ADMIN,
    ).first()
    if not admin:
        raise HTTPException(status_code=404, detail="Administrateur plateforme non trouvé")

    if payload.first_name is not None:
        admin.first_name = payload.first_name
    if payload.last_name is not None:
        admin.last_name = payload.last_name
    if payload.email is not None:
        admin.email = payload.email
    if payload.phone is not None:
        admin.phone = payload.phone
    if payload.password:
        admin.password_hash = hash_password(payload.password)
    if payload.is_active is not None:
        if getattr(admin, "is_super_platform_admin", False) and not payload.is_active:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Impossible de désactiver le super administrateur plateforme principal",
            )
        admin.is_active = payload.is_active

    db.commit()
    db.refresh(admin)
    return PlatformAdminResponse(
        id=admin.id,
        username=admin.username,
        first_name=admin.first_name,
        last_name=admin.last_name,
        email=admin.email,
        phone=admin.phone,
        is_active=admin.is_active,
        is_super_platform_admin=getattr(admin, "is_super_platform_admin", False),
        created_at=getattr(admin, "created_at", None),
    )


@router.delete("/{admin_id}")
def delete_platform_admin(
    admin_id: int,
    current_admin: User = Depends(require_platform_admin),
    db: Session = Depends(get_local_db),
):
    """Deactivate (soft delete) a platform administrator."""
    if current_admin.id == admin_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Vous ne pouvez pas supprimer votre propre compte administrateur",
        )

    admin = db.query(User).filter(
        User.id == admin_id,
        User.role == UserRole.PLATFORM_ADMIN,
    ).first()
    if not admin:
        raise HTTPException(status_code=404, detail="Administrateur non trouvé")

    if getattr(admin, "is_super_platform_admin", False):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Impossible de supprimer le super administrateur plateforme principal",
        )

    admin.is_active = False
    db.commit()
    return {"message": "Administrateur désactivé avec succès"}


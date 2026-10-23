"""
Authentication dependencies for FastAPI endpoints.
Handles token extraction, verification, and role-based access control.
"""

from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.orm import Session
from dataclasses import dataclass
from typing import Optional
import time

from app.database import get_local_db
from app.models.pharmacy import Pharmacy
from app.models.user import User, UserRole
from app.utils.security import decode_token, verify_token
from app.schemas.auth import TokenData

# OAuth2 scheme for token extraction
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/login")


@dataclass(frozen=True)
class PharmacyContext:
    pharmacy_id: Optional[int]
    is_platform_admin: bool
    pharmacy: Optional[Pharmacy] = None

# ── Cache token → user_id  (30s TTL) ─────────────────────────────────────────
# On cache UNIQUEMENT l'user_id déduit du token, pas l'objet ORM.
# L'objet ORM est toujours récupéré depuis la session courante (pas de DetachedInstance).
# Gain : on évite decode_token() (pure Python, rapide) + la query DB sur /auth/login déjà
# faite → mais surtout la licence check qui coûte 3 queries Aiven.
_token_to_username: dict = {}   # token_key → {"username": str, "ts": float}
_TOKEN_CACHE_TTL = 30           # secondes


def _tkey(token: str) -> str:
    return token[-32:] if len(token) >= 32 else token


def _evict_expired():
    now = time.time()
    expired = [k for k, v in _token_to_username.items() if now - v["ts"] > _TOKEN_CACHE_TTL]
    for k in expired:
        _token_to_username.pop(k, None)


# ============================================================================
# CREDENTIALS EXCEPTION
# ============================================================================

credentials_exception = HTTPException(
    status_code=status.HTTP_401_UNAUTHORIZED,
    detail="Could not validate credentials",
    headers={"WWW-Authenticate": "Bearer"},
)


def _set_user_pharmacy_scope(user: User, db: Session) -> None:
    if user.role == UserRole.PLATFORM_ADMIN:
        if user.pharmacy_id is not None:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Platform administrator must not be assigned to a pharmacy",
            )
        db.info.update({
            "pharmacy_scope_enabled": True,
            "pharmacy_id": None,
            "is_platform_admin": False,
        })
        return

    if user.pharmacy_id is None:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="User is not assigned to a pharmacy",
        )
    pharmacy = db.query(Pharmacy).filter(Pharmacy.id == user.pharmacy_id).first()
    if pharmacy is None or not pharmacy.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Pharmacy is unavailable",
        )
    db.info.update({
        "pharmacy_scope_enabled": True,
        "pharmacy_id": pharmacy.id,
        "is_platform_admin": False,
    })


# ============================================================================
# AUTHENTICATION DEPENDENCIES
# ============================================================================

async def get_current_user(
    token: str = Depends(oauth2_scheme),
    db: Session = Depends(get_local_db)
) -> User:
    """
    Get current authenticated user from JWT token.

    Cache le username issu du token (30s) pour éviter de décoder le JWT
    et de faire la query User à chaque requête.
    L'objet User est toujours chargé depuis la session courante (pas de DetachedInstance).
    """
    key = _tkey(token)
    now_ts = time.time()

    cached = _token_to_username.get(key)
    if cached and now_ts - cached["ts"] < _TOKEN_CACHE_TTL:
        username = cached.get("username")
        user_id = cached.get("user_id")
    else:
        payload = verify_token(token)
        if payload is None:
            raise credentials_exception
        username = payload.get("sub")
        user_id = payload.get("user_id")
        # Stocker dans le cache
        _token_to_username[key] = {"username": username, "user_id": user_id, "ts": now_ts}
        # Nettoyage périodique
        if len(_token_to_username) > 500:
            _evict_expired()

    # Charger l'objet depuis la session courante (sans filtre tenant préalable afin de trouver l'utilisateur)
    prev_scope = db.info.get("pharmacy_scope_enabled")
    db.info["pharmacy_scope_enabled"] = False
    try:
        if user_id:
            user = db.query(User).filter(User.id == user_id).first()
        else:
            user = db.query(User).filter(User.username == username).first()
    finally:
        if prev_scope is not None:
            db.info["pharmacy_scope_enabled"] = prev_scope

    if user is None:
        # Token valide mais user supprimé → invalider le cache
        _token_to_username.pop(key, None)
        raise credentials_exception

    _set_user_pharmacy_scope(user, db)

    return user


from app.core.license import license_service

# Track verified users to log verification only once and avoid flooding console logs
_verified_users = set()

async def get_current_active_user(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_local_db)
) -> User:
    """
    Ensure current user is active.
    Also checks the authenticated pharmacy's license expiration.
    La vérification de licence est mise en cache 60s dans license_service.
    """
    global _verified_users
    is_first_time = current_user.username not in _verified_users

    if is_first_time:
        print(f"[DEBUG] get_current_active_user: Verifying user {current_user.username}")

    if not current_user.is_active:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Inactive user"
        )

    # Check license status (résultat caché 60s dans license_service)
    if current_user.role != UserRole.PLATFORM_ADMIN:
        if is_first_time:
            print("[DEBUG] get_current_active_user: Checking license...")
        license_status = license_service.get_license_status(db)
        if is_first_time:
            print(f"[DEBUG] get_current_active_user: License status: {license_status.get('status')}")
        if license_status["status"] == "expired":
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=license_status["message"]
            )

    if is_first_time:
        print("[DEBUG] get_current_active_user: Verification complete.")
        _verified_users.add(current_user.username)

    return current_user


async def get_current_pharmacy_context(
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_local_db),
) -> PharmacyContext:
    """Resolve the tenant from the authenticated database user, never from the request."""
    if current_user.role == UserRole.PLATFORM_ADMIN:
        if current_user.pharmacy_id is not None:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Platform administrator must not be assigned to a pharmacy",
            )
        return PharmacyContext(pharmacy_id=None, is_platform_admin=True)

    if current_user.pharmacy_id is None:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="User is not assigned to a pharmacy",
        )

    pharmacy = db.query(Pharmacy).filter(Pharmacy.id == current_user.pharmacy_id).first()
    if pharmacy is None or not pharmacy.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Pharmacy is unavailable",
        )

    return PharmacyContext(
        pharmacy_id=pharmacy.id,
        is_platform_admin=False,
        pharmacy=pharmacy,
    )


async def require_platform_admin(
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_local_db),
) -> User:
    """Restrict platform administration endpoints to platform administrators."""
    if current_user.role != UserRole.PLATFORM_ADMIN:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access reserved for platform administrators",
        )
    db.info.update({
        "pharmacy_scope_enabled": True,
        "pharmacy_id": None,
        "is_platform_admin": True,
    })
    return current_user


# ============================================================================
# AUTHORIZATION DEPENDENCIES (ROLE-BASED)
# ============================================================================

async def get_admin_user(
    current_user: User = Depends(get_current_active_user)
) -> User:
    """Ensure current user has admin role (or super admin)."""
    if current_user.role not in [UserRole.ADMIN, UserRole.SUPER_ADMIN]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access forbidden: Admin privileges required"
        )
    return current_user


async def get_pharmacist_user(
    current_user: User = Depends(get_current_active_user)
) -> User:
    """Ensure current user has pharmacist or admin role."""
    if current_user.role not in [UserRole.ADMIN, UserRole.PHARMACIST, UserRole.SUPER_ADMIN]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access forbidden: Pharmacist or Admin privileges required"
        )
    return current_user


async def get_super_admin_user(
    current_user: User = Depends(get_current_active_user)
) -> User:
    """Ensure current user has super admin role."""
    if current_user.role != UserRole.SUPER_ADMIN:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access forbidden: Super Admin privileges required"
        )
    return current_user


async def get_super_admin_user_bypass_license(
    token: str = Depends(oauth2_scheme),
    db: Session = Depends(get_local_db)
) -> User:
    """
    Get Super Admin user WITHOUT checking license status.
    This allows Super Admin to access license management even when license is expired.
    """
    payload = verify_token(token)
    if payload is None:
        raise credentials_exception

    user_id = payload.get("user_id")
    username = payload.get("sub")
    if user_id:
        user = db.query(User).filter(User.id == user_id).first()
    else:
        user = db.query(User).filter(User.username == username).first()

    if user is None:
        raise credentials_exception

    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Inactive user"
        )

    if user.role != UserRole.SUPER_ADMIN:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access forbidden: Super Admin privileges required"
        )

    _set_user_pharmacy_scope(user, db)

    return user

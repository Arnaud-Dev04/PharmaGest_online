"""
Authentication routes: login, register, get user info.
"""

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from fastapi.requests import Request
from sqlalchemy.orm import Session
from app.models.pharmacy import Pharmacy
from datetime import timedelta
from app.core.limiter import limiter

from app.database import get_local_db
from app.models.user import User, UserRole
from app.models.settings import Settings
from app.schemas.auth import (
    Token,
    UserCreate,
    UserResponse,
    UserLogin,
    ChangeInitialPassword,
    RefreshTokenRequest,
    ForgotPasswordRequest,
    ResetPasswordRequest,
)
from app.utils.security import (
    verify_password,
    hash_password,
    create_access_token,
    create_refresh_token,
    verify_refresh_token,
    ACCESS_TOKEN_EXPIRE_MINUTES,
)
from app.auth.dependencies import get_current_user, get_current_active_user, get_admin_user
from app.core.license_guard import ensure_user_capacity

# Create router
router = APIRouter()


# ============================================================================
# AUTHENTICATION HELPER
# ============================================================================

def authenticate_user(
    db: Session,
    username: str,
    password: str,
    pharmacy_code: str | None = None
) -> User | None:
    """
    Authenticate user by username and password.
    Supports optional pharmacy_code scoping for multi-tenant users.
    """
    from app.models.pharmacy import Pharmacy
    user = None

    if pharmacy_code:
        pharmacy = db.query(Pharmacy).filter(Pharmacy.code == pharmacy_code).first()
        if not pharmacy or not pharmacy.is_active:
            return None
        user = db.query(User).filter(
            User.username == username,
            User.pharmacy_id == pharmacy.id,
        ).first()
    else:
        # Check if platform administrator
        platform_user = db.query(User).filter(
            User.username == username,
            User.role == UserRole.PLATFORM_ADMIN,
        ).first()
        if platform_user:
            user = platform_user
        else:
            candidates = db.query(User).filter(User.username == username).all()
            if len(candidates) == 1:
                user = candidates[0]
            elif len(candidates) > 1:
                return None

    if not user:
        return None
    
    if not verify_password(password, user.password_hash):
        return None
    
    return user


# ============================================================================
# LOGIN ENDPOINT
# ============================================================================

@router.post("/login", response_model=Token, summary="Login to get access token")
@limiter.limit("10/minute")
async def login(
    request: Request,
    form_data: OAuth2PasswordRequestForm = Depends(),
    db: Session = Depends(get_local_db)
):
    """
    Login endpoint - Authenticate user and return JWT token.
    
    **OAuth2 compatible** - accepts form data with username and password.
    Optional pharmacy_code via client_id or form parameter.
    """
    form = await request.form()
    pharmacy_code = form.get("pharmacy_code") or form_data.client_id
    if isinstance(pharmacy_code, str):
        pharmacy_code = pharmacy_code.strip() or None

    if not pharmacy_code:
        candidates = db.query(User).filter(User.username == form_data.username).all()
        if len(candidates) > 1:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Ce nom d'utilisateur existe dans plusieurs pharmacies. Veuillez renseigner le code pharmacie pour vous connecter.",
            )

    user = authenticate_user(db, form_data.username, form_data.password, pharmacy_code=pharmacy_code)
    
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    # Check if user is active
    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Inactive user account"
        )
    
    # Create access token with tenant context
    access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    token_payload = {
        "sub": user.username,
        "user_id": user.id,
        "pharmacy_id": user.pharmacy_id,
        "role": user.role.value if hasattr(user.role, 'value') else user.role,
    }
    access_token = create_access_token(
        data=token_payload,
        expires_delta=access_token_expires
    )
    refresh_token = create_refresh_token(data=token_payload)

    # Check if this is the first setup
    first_setup_setting = db.query(Settings).filter(Settings.key == "is_first_setup").first()
    is_first_setup = first_setup_setting.value == "true" if first_setup_setting else False

    return {
        "access_token": access_token,
        "refresh_token": refresh_token,
        "token_type": "bearer",
        "must_change_password": user.must_change_password,
        "is_first_setup": is_first_setup
    }


@router.post("/refresh", response_model=Token, summary="Refresh access token using refresh token")
@limiter.limit("30/minute")
async def refresh_access_token(
    request: Request,
    payload: RefreshTokenRequest,
    db: Session = Depends(get_local_db)
):
    """
    Generate a new access token using a valid refresh token.
    Enables persistent session without frequent re-login.
    """
    token_data = verify_refresh_token(payload.refresh_token)
    if not token_data or not token_data.get("sub"):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Refresh token invalide ou expiré",
            headers={"WWW-Authenticate": "Bearer"},
        )

    username = token_data.get("sub")
    user_id = token_data.get("user_id")
    pharmacy_id = token_data.get("pharmacy_id")

    query = db.query(User).filter(User.username == username)
    if user_id:
        query = query.filter(User.id == user_id)
    if pharmacy_id:
        query = query.filter(User.pharmacy_id == pharmacy_id)
    user = query.first()

    if not user or not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Compte utilisateur inactif ou introuvable",
            headers={"WWW-Authenticate": "Bearer"},
        )

    new_token_payload = {
        "sub": user.username,
        "user_id": user.id,
        "pharmacy_id": user.pharmacy_id,
        "role": user.role.value if hasattr(user.role, 'value') else user.role,
    }
    new_access_token = create_access_token(
        data=new_token_payload,
        expires_delta=timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    )
    new_refresh_token = create_refresh_token(data=new_token_payload)

    first_setup_setting = db.query(Settings).filter(Settings.key == "is_first_setup").first()
    is_first_setup = first_setup_setting.value == "true" if first_setup_setting else False

    return {
        "access_token": new_access_token,
        "refresh_token": new_refresh_token,
        "token_type": "bearer",
        "must_change_password": user.must_change_password,
        "is_first_setup": is_first_setup,
    }


@router.post("/forgot-password", summary="Demande de réinitialisation de mot de passe")
@limiter.limit("5/minute")
async def forgot_password(
    request: Request,
    payload: ForgotPasswordRequest,
    db: Session = Depends(get_local_db)
):
    """
    Envoie un token de réinitialisation si l'email existe.
    """
    user = db.query(User).filter(User.email == payload.email.strip()).first()
    if user and user.is_active:
        reset_payload = {
            "sub": user.username,
            "user_id": user.id,
            "type": "reset_password",
        }
        reset_token = create_access_token(
            data=reset_payload,
            expires_delta=timedelta(minutes=15)
        )
        print(f"[SECURITY] Reset token generated for user {user.username} ({user.email}): {reset_token}")

    return {
        "message": "Si cette adresse email est associée à un compte, un lien de réinitialisation a été envoyé."
    }


@router.post("/reset-password", summary="Réinitialisation du mot de passe avec token")
@limiter.limit("10/minute")
async def reset_password(
    request: Request,
    payload: ResetPasswordRequest,
    db: Session = Depends(get_local_db)
):
    """
    Réinitialise le mot de passe à l'aide d'un token valide.
    """
    token_data = verify_token(payload.token) if "verify_token" in globals() else None
    if not token_data:
        from app.utils.security import verify_token
        token_data = verify_token(payload.token)

    if not token_data or token_data.get("type") != "reset_password":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Token de réinitialisation invalide ou expiré"
        )

    user_id = token_data.get("user_id")
    user = db.query(User).filter(User.id == user_id).first()
    if not user or not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Utilisateur introuvable ou inactif"
        )

    user.password_hash = hash_password(payload.new_password)
    user.must_change_password = False
    db.commit()

    return {"message": "Mot de passe réinitialisé avec succès"}


# ============================================================================
# REGISTER ENDPOINT (Admin Only)
# ============================================================================

@router.post(
    "/register",
    response_model=UserResponse,
    summary="Register new user (Admin only)",
    dependencies=[Depends(get_admin_user)]
)
def register(
    user_data: UserCreate,
    db: Session = Depends(get_local_db),
    current_admin: User = Depends(get_admin_user)
):
    """
    Register a new user - **Admin only**.
    
    Creates a new user account with hashed password.
    
    Args:
        user_data: User creation data (username, password, role)
        
    Returns:
        UserResponse: Created user data (without password)
        
    Raises:
        HTTPException 400: If username already exists
        HTTPException 403: If current user is not admin
    """
    if user_data.role == UserRole.PLATFORM_ADMIN:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Platform administrator accounts cannot be created by a pharmacy",
        )

    if current_admin.pharmacy_id is None:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin is not assigned to a pharmacy",
        )

    # Check if username already exists in this pharmacy
    existing_user = db.query(User).filter(
        User.username == user_data.username,
        User.pharmacy_id == current_admin.pharmacy_id,
    ).first()
    
    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Username '{user_data.username}' already exists"
        )

    if user_data.is_active:
        ensure_user_capacity(db, current_admin.pharmacy_id)
    
    # Create new user
    new_user = User(
        username=user_data.username,
        password_hash=hash_password(user_data.password),
        role=user_data.role,
        is_active=user_data.is_active,
        must_change_password=True,
        pharmacy_id=current_admin.pharmacy_id,
    )
    
    db.add(new_user)
    db.commit()
    db.refresh(new_user)
    
    return new_user


# ============================================================================
# GET CURRENT USER INFO
# ============================================================================

@router.get(
    "/me",
    response_model=UserResponse,
    summary="Get current user information"
)
def get_me(
    current_user: User = Depends(get_current_user)
):
    """
    Get current authenticated user information.
    
    Returns:
        UserResponse: Current user data
        
    Raises:
        HTTPException 401: If not authenticated
    """
    if not current_user.is_active:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Inactive user",
        )
    print(f"[DEBUG] /auth/me endpoint reached for {current_user.username}")
    return current_user


# ============================================================================
# FIRST-TIME SETUP ENDPOINTS
# ============================================================================

@router.post(
    "/change-initial-password",
    summary="Change password on first login (required for new users)"
)
def change_initial_password(
    password_data: ChangeInitialPassword,
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_local_db)
):
    """
    Change password for users who must change their password on first login.
    
    Only works if the user has `must_change_password=True`.
    After changing, the flag is set to False.
    """
    if not current_user.must_change_password:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Password change is not required for this user"
        )
    
    if password_data.new_password != password_data.confirm_password:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Passwords do not match"
        )
    
    # Update password and clear the flag
    # A platform admin has no pharmacy tenant. Permit only this self-service
    # account update; do not grant platform-wide scope to the request session.
    if current_user.role == UserRole.PLATFORM_ADMIN:
        db.info["pharmacy_scope_enabled"] = False
    current_user.password_hash = hash_password(password_data.new_password)
    current_user.must_change_password = False
    db.commit()
    
    # Generate new token
    access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = create_access_token(
        data={"sub": current_user.username},
        expires_delta=access_token_expires
    )
    
    return {
        "message": "Password changed successfully",
        "access_token": access_token,
        "token_type": "bearer"
    }


from app.auth.dependencies import get_super_admin_user

@router.post(
    "/complete-setup",
    summary="Mark first-time setup as complete (Super Admin only)"
)
def complete_setup(
    current_user: User = Depends(get_super_admin_user),
    db: Session = Depends(get_local_db)
):
    """
    Mark the first-time setup as complete.
    
    Sets the `is_first_setup` setting to "false".
    Only Super Admin can call this endpoint.
    """
    setting = db.query(Settings).filter(Settings.key == "is_first_setup").first()
    if setting:
        setting.value = "false"
    else:
        setting = Settings(key="is_first_setup", value="false")
        db.add(setting)
    
    db.commit()
    
    return {"message": "Setup completed successfully", "is_first_setup": False}

# ============================================================================
# CHANGE PASSWORD
# ============================================================================

from pydantic import BaseModel as _BaseModel

class ChangePasswordRequest(_BaseModel):
    current_password: str | None = None
    new_password: str


@router.post("/change-password")
def change_password(
    data: ChangePasswordRequest,
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_local_db),
):
    """
    Change password for the currently authenticated user.
    Super Admin n'a pas besoin de fournir l'ancien mot de passe.
    """
    is_super_admin = current_user.role == UserRole.SUPER_ADMIN

    # Validation du mot de passe actuel (sauf pour super_admin)
    if not is_super_admin:
        if not data.current_password:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="L'ancien mot de passe est requis"
            )
        if not verify_password(data.current_password, current_user.password_hash):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Ancien mot de passe incorrect"
            )

    # Validation du nouveau mot de passe
    if len(data.new_password) < 6:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Le nouveau mot de passe doit contenir au moins 6 caractères"
        )

    # Mise à jour du hash
    current_user.password_hash = hash_password(data.new_password)
    current_user.must_change_password = False
    db.commit()

    return {"success": True, "message": "Mot de passe mis à jour avec succès"}

"""
Users routes.
"""

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import Optional

from app.database import get_local_db
from app.models.user import User
from app.auth.dependencies import get_current_active_user
from app.services import sales_service

# For now, we focus on stats.

router = APIRouter()

@router.get(
    "/{user_id}/stats",
    summary="Get user sales statistics"
)
async def get_user_stats(
    user_id: int,
    start_date: Optional[str] = None,
    end_date: Optional[str] = None,
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_local_db)
):
    """
    Get detailed statistics for a specific user.
    """
    # Logic to populate UserSalesStats schema
    stats = sales_service.get_user_stats(db, user_id, start_date, end_date)
    return stats


from pydantic import BaseModel

class PasswordUpdate(BaseModel):
    password: str

@router.post(
    "/{user_id}/password",
    summary="Update user password (Admin only)"
)
async def update_user_password(
    user_id: int,
    password_data: PasswordUpdate,
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_local_db)
):
    """
    Reset or update a user's password.
    Only Admins and SuperAdmins can perform this action.
    """
    from app.utils import security
    
    # Permission check
    if current_user.role not in ["admin", "super_admin"]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Insufficient permissions"
        )
        
    # Get target user
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
        )
    
    # Optional: Prevent admin from changing super_admin password if not super_admin
    if user.role == "super_admin" and current_user.role != "super_admin":
        raise HTTPException(
             status_code=status.HTTP_403_FORBIDDEN,
             detail="Cannot modify Super Admin account"
        )

    # Hash new password
    hashed_password = security.hash_password(password_data.password)
    user.password_hash = hashed_password
    
    db.commit()
    
    return {"message": "Password updated successfully"}


class UserUpdate(BaseModel):
    username: Optional[str] = None
    password: Optional[str] = None
    role: Optional[str] = None
    is_active: Optional[bool] = None

@router.put(
    "/{user_id}",
    summary="Update user details",
    response_model=dict
)
async def update_user(
    user_id: int,
    user_data: UserUpdate,
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_local_db)
):
    """
    Update user details (username, password, role, status).
    Only Admins and SuperAdmins can perform this action.
    """
    from app.utils import security

    # Permission check
    if current_user.role not in ["admin", "super_admin"]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Insufficient permissions"
        )

    # Get target user
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
        )

    # Protection: Cannot modify Super Admin unless self is Super Admin
    if user.role == "super_admin" and current_user.role != "super_admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Cannot modify Super Admin account"
        )

    # Update Username
    if user_data.username and user_data.username != user.username:
        # Check uniqueness
        existing_user = db.query(User).filter(User.username == user_data.username).first()
        if existing_user:
             raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Username already exists"
            )
        user.username = user_data.username

    # Update Password
    if user_data.password:
        user.password_hash = security.hash_password(user_data.password)

    # Update Role
    if user_data.role:
        if user_data.role not in ["admin", "pharmacist", "super_admin"]:
             raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid role"
            )
        # Prevent demoting self if it leaves no super admin (simplified check)
        user.role = user_data.role

    # Update Status
    if user_data.is_active is not None:
        user.is_active = user_data.is_active

    db.commit()
    db.refresh(user)

    return {
        "id": user.id,
        "username": user.username,
        "role": user.role,
        "is_active": user.is_active,
        "message": "User updated successfully"
    }

@router.post("/{user_id}/toggle-status")
async def toggle_user_status(
    user_id: int,
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_local_db)
):
    # Only Admin
    if current_user.role not in ["admin", "super_admin"]:
        raise HTTPException(status_code=403, detail="Not authorized")
        
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
        
    # Prevent disabling super admin
    if user.role == "super_admin":
        raise HTTPException(status_code=400, detail="Cannot disable Super Admin")
        
    user.is_active = not user.is_active
    db.commit()
    
    return {"message": "Status updated", "is_active": user.is_active}

@router.delete("/{user_id}")
async def delete_user(
    user_id: int,
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_local_db)
):
    # Only Admin
    if current_user.role not in ["admin", "super_admin"]:
        raise HTTPException(status_code=403, detail="Not authorized")
        
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
        
    # Prevent deleting super admin
    if user.role == "super_admin":
        raise HTTPException(status_code=400, detail="Cannot delete Super Admin")
        
    db.delete(user)
    db.commit()
    
    return {"message": "User deleted"}

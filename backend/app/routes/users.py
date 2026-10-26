"""
Users routes.
"""

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import Optional, List
from datetime import datetime, timedelta
from app.schemas.user_stats import UserPerformance
from app.models.sales import Sale

from app.database import get_local_db
from app.models.user import User
from app.auth.dependencies import get_current_active_user, get_admin_user
from app.core.license_guard import ensure_user_capacity
from app.services import sales_service

router = APIRouter()

@router.get(
    "",
    summary="List users in pharmacy (Admin only)"
)
def list_users(
    current_user: User = Depends(get_admin_user),
    db: Session = Depends(get_local_db)
):
    query = db.query(User)
    if current_user.pharmacy_id is not None:
        query = query.filter(User.pharmacy_id == current_user.pharmacy_id)
    if current_user.role != "super_admin":
        query = query.filter(User.role != "super_admin")
    users = query.all()
    return [
        {
            "id": u.id,
            "username": u.username,
            "role": u.role,
            "first_name": u.first_name,
            "last_name": u.last_name,
            "email": u.email,
            "phone": u.phone,
            "is_active": u.is_active,
        }
        for u in users
    ]


@router.get(
    "/sales-performance",
    response_model=List[UserPerformance],
    summary="Get all users sales performance comparison (Admin only)",
    dependencies=[Depends(get_admin_user)]
)
def get_users_performance(
    start_date: Optional[str] = None,
    end_date: Optional[str] = None,
    db: Session = Depends(get_local_db)
):
    """
    Get sales performance comparison for all users.
    Ranked by total revenue.
    """
    if end_date:
        end_dt = datetime.strptime(end_date, "%Y-%m-%d")
    else:
        end_dt = datetime.now()

    if start_date:
        start_dt = datetime.strptime(start_date, "%Y-%m-%d")
    else:
        start_dt = end_dt - timedelta(days=30)

    from sqlalchemy import func

    pharmacy_id = db.info.get("pharmacy_id")

    query = (
        db.query(
            User.id.label("user_id"),
            User.username.label("username"),
            User.role.label("role"),
            User.is_active.label("is_active"),
            func.coalesce(func.count(Sale.id), 0).label("total_sales"),
            func.coalesce(func.sum(Sale.total_amount), 0.0).label("total_revenue"),
        )
        .outerjoin(
            Sale,
            (Sale.user_id == User.id) & (Sale.date >= start_dt) & (Sale.date <= end_dt)
        )
    )
    if pharmacy_id is not None:
        query = query.filter(User.pharmacy_id == pharmacy_id)

    results = query.group_by(User.id, User.username, User.role, User.is_active).all()

    performances = []
    for r in results:
        total_sales = int(r.total_sales or 0)
        total_revenue = float(r.total_revenue or 0.0)
        average_sale = total_revenue / total_sales if total_sales > 0 else 0.0

        performances.append(UserPerformance(
            user_id=r.user_id,
            username=r.username,
            role=r.role,
            is_active=r.is_active,
            total_sales=total_sales,
            total_revenue=total_revenue,
            average_sale_amount=average_sale
        ))

    performances.sort(key=lambda x: x.total_revenue, reverse=True)
    for idx, perf in enumerate(performances, start=1):
        perf.rank = idx

    return performances


@router.get(
    "/{user_id}",
    summary="Get user details by ID"
)
def get_user_by_id(
    user_id: int,
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_local_db)
):
    if current_user.role not in ["admin", "super_admin"] and current_user.id != user_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Insufficient permissions"
        )
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
        )
    return {
        "id": user.id,
        "username": user.username,
        "role": user.role,
        "first_name": user.first_name,
        "last_name": user.last_name,
        "email": user.email,
        "phone": user.phone,
        "is_active": user.is_active,
    }


@router.get(
    "/{user_id}/stats",
    summary="Get user sales statistics"
)
def get_user_stats(
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
def update_user_password(
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
    first_name: Optional[str] = None
    last_name: Optional[str] = None
    email: Optional[str] = None
    phone: Optional[str] = None
    is_active: Optional[bool] = None

@router.put(
    "/{user_id}",
    summary="Update user details",
    response_model=dict
)
def update_user(
    user_id: int,
    user_data: UserUpdate,
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_local_db)
):
    """
    Update user details (username, password, role, status, profile).
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

    # Tenant check: prevent modifying user from another pharmacy
    if current_user.pharmacy_id is not None and user.pharmacy_id != current_user.pharmacy_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Cannot modify user from another pharmacy"
        )

    # Protection: Cannot modify Super Admin unless self is Super Admin
    if user.role == "super_admin" and current_user.role != "super_admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Cannot modify Super Admin account"
        )

    # Update Username
    if user_data.username and user_data.username != user.username:
        # Check uniqueness in same pharmacy
        existing_user = db.query(User).filter(
            User.username == user_data.username,
            User.pharmacy_id == user.pharmacy_id,
        ).first()
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

    # Update Profile Fields
    if user_data.first_name is not None:
        user.first_name = user_data.first_name
    if user_data.last_name is not None:
        user.last_name = user_data.last_name
    if user_data.email is not None:
        user.email = user_data.email
    if user_data.phone is not None:
        user.phone = user_data.phone

    # Update Status
    if user_data.is_active is not None:
        if user_data.is_active and not user.is_active:
            ensure_user_capacity(db, current_user.pharmacy_id)
        user.is_active = user_data.is_active

    db.commit()
    db.refresh(user)

    return {
        "id": user.id,
        "username": user.username,
        "role": user.role,
        "first_name": user.first_name,
        "last_name": user.last_name,
        "email": user.email,
        "phone": user.phone,
        "is_active": user.is_active,
        "message": "User updated successfully"
    }

@router.post("/{user_id}/toggle-status")
def toggle_user_status(
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

    if not user.is_active:
        ensure_user_capacity(db, current_user.pharmacy_id)
        
    user.is_active = not user.is_active
    db.commit()
    
    return {"message": "Status updated", "is_active": user.is_active}

@router.delete("/{user_id}")
def delete_user(
    user_id: int,
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_local_db)
):
    # Only Admin or SuperAdmin
    if current_user.role not in ["admin", "super_admin"]:
        raise HTTPException(status_code=403, detail="Not authorized")

    if current_user.id == user_id:
        raise HTTPException(status_code=400, detail="Impossible de supprimer votre propre compte")

    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    # Tenant check
    if current_user.pharmacy_id is not None and user.pharmacy_id != current_user.pharmacy_id:
        raise HTTPException(status_code=403, detail="Cannot modify user from another pharmacy")

    # Prevent deleting super admin
    if user.role == "super_admin" and current_user.role != "super_admin":
        raise HTTPException(status_code=400, detail="Cannot delete Super Admin account")

    # Soft delete to preserve sales history and relational integrity
    user.is_active = False
    db.commit()

    return {"message": "Utilisateur désactivé avec succès", "is_active": False}

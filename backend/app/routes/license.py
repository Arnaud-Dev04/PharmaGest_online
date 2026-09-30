"""
License routes - Public endpoint for license status checks.
"""

from fastapi import APIRouter, Depends, Body
from sqlalchemy.orm import Session
from datetime import datetime
from typing import Optional

from app.database import get_local_db
from app.core.license import license_service
from app.models.user import User
from app.models.settings import Settings
from app.auth.dependencies import get_super_admin_user_bypass_license

router = APIRouter()

@router.get("/status")
async def get_license_status(db: Session = Depends(get_local_db)):
    """
    Get current license status.
    Public endpoint - no authentication required.
    Returns license validity and expiration information.
    """
    status = license_service.get_license_status(db)
    
    # Map backend format to frontend format
    is_expired = status["status"] == "expired"
    is_valid = status["status"] in ["valid", "warning"]
    days_remaining = status.get("days_remaining", 0)
    
    return {
        "is_valid": is_valid,
        "is_expired": is_expired,
        "days_remaining": days_remaining,
        "message": status.get("message", "")
    }


@router.put("/update", summary="Update license (Super Admin only)")
async def update_license(
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
    
    # Get updated status
    status = license_service.get_license_status(db)
    
    return {
        "success": True,
        "message": "Licence mise à jour avec succès",
        "license_status": status
    }


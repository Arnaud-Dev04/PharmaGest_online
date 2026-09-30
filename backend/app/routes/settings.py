"""
Settings Routes - Dynamic configuration management.
"""

from fastapi import APIRouter, Depends, Body
from sqlalchemy.orm import Session
from typing import Dict, Any

from app.database import get_local_db
from app.models.settings import Settings
from app.models.user import User
from app.auth.dependencies import get_current_active_user
from app.schemas.settings import SettingsUpdate, SettingsResponse

router = APIRouter()

@router.get(
    "",
    response_model=SettingsResponse,
    summary="Get all settings"
)
async def get_settings(
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_local_db)
):
    """
    Retrieve all configuration settings.
    Aggregates key-value rows into a single object.
    """
    all_settings = db.query(Settings).all()
    settings_dict = {s.key: s.value for s in all_settings}
    
    # Cast basic types for the response model
    # Note: In a real app we might store type info or use JSON column
    response_data = {}
    
    # Mapping with default fallback/type casting
    response_data["pharmacy_name"] = settings_dict.get("pharmacy_name", "Ma Pharmacie")
    response_data["pharmacy_address"] = settings_dict.get("pharmacy_address", "")
    response_data["pharmacy_phone"] = settings_dict.get("pharmacy_phone", "")
    response_data["currency"] = settings_dict.get("currency", "FBu")
    response_data["pharmacy_nif"] = settings_dict.get("pharmacy_nif", "")
    response_data["logo_url"] = settings_dict.get("logo_url", None)
    
    try:
        response_data["bonus_percentage"] = float(settings_dict.get("bonus_percentage", 0.0))
    except ValueError:
        response_data["bonus_percentage"] = 0.0
        
    try:
        response_data["license_warning_bdays"] = int(settings_dict.get("license_warning_bdays", 60))
    except (ValueError, TypeError):
        response_data["license_warning_bdays"] = 60
        
    response_data["license_warning_message"] = settings_dict.get(
        "license_warning_message", 
        "Votre licence expire bientôt. Veuillez contacter le concepteur pour une mise à jour."
    )
    
    try:
        response_data["license_warning_duration"] = int(settings_dict.get("license_warning_duration", 30))
    except (ValueError, TypeError):
        response_data["license_warning_duration"] = 30
        
    return response_data


@router.put(
    "",
    response_model=SettingsResponse,
    summary="Update settings"
)
async def update_settings(
    settings_update: SettingsUpdate,
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_local_db)
):
    """
    Update configuration settings.
    Upserts keys into the database.
    """
    update_data = settings_update.model_dump(exclude_unset=True)
    
    for key, value in update_data.items():
        if value is None:
            continue
            
        setting = db.query(Settings).filter(Settings.key == key).first()
        str_value = str(value) # Store everything as string for simplicity in this MVP
        
        if setting:
            setting.value = str_value
        else:
            new_setting = Settings(key=key, value=str_value)
            db.add(new_setting)
            
    db.commit()
    
    # Return updated state
    return await get_settings(current_user, db)

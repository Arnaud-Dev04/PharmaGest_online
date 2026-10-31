"""
Settings Routes - Dynamic configuration management.
"""

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.database import get_local_db
from app.models.settings import Settings
from app.models.user import User
from app.models.pharmacy import Pharmacy
from app.auth.dependencies import get_current_active_user
from app.schemas.settings import SettingsUpdate, SettingsResponse

router = APIRouter()

@router.get(
    "",
    response_model=SettingsResponse,
    summary="Get all settings"
)
def get_settings(
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_local_db)
):
    """
    Retrieve all configuration settings for the current pharmacy.
    Defaults to the pharmacy's official registration identity.
    """
    pharmacy = None
    if current_user.pharmacy_id:
        pharmacy = db.query(Pharmacy).filter(Pharmacy.id == current_user.pharmacy_id).first()
        query = db.query(Settings).filter(Settings.pharmacy_id == current_user.pharmacy_id)
    else:
        query = db.query(Settings)
        
    all_settings = query.all()
    settings_dict = {s.key: s.value for s in all_settings}
    
    response_data = {}
    
    def _val(key: str, default: str = "") -> str:
        v = settings_dict.get(key)
        if v is not None and str(v).strip() != "" and str(v).strip() != "Ma Pharmacie":
            return str(v).strip()
        return default

    # Pharmacy Identity mapping with defaults from the Pharmacy entity
    if pharmacy:
        response_data["pharmacy_name"] = _val("pharmacy_name", pharmacy.name or "Ma Pharmacie")
        response_data["pharmacy_code"] = pharmacy.code
        response_data["pharmacy_email"] = _val("pharmacy_email", pharmacy.email or "")
        
        # Combine address or city/country if address is blank
        default_addr = pharmacy.address or ""
        if not default_addr and pharmacy.city:
            default_addr = f"{pharmacy.city}, {pharmacy.country}".strip(", ")
        response_data["pharmacy_address"] = _val("pharmacy_address", default_addr)
        
        response_data["pharmacy_phone"] = _val("pharmacy_phone", pharmacy.phone or "")
        response_data["pharmacy_nif"] = _val("pharmacy_nif", pharmacy.nif or "")
    else:
        response_data["pharmacy_name"] = _val("pharmacy_name", "Ma Pharmacie")
        response_data["pharmacy_code"] = None
        response_data["pharmacy_email"] = _val("pharmacy_email", "")
        response_data["pharmacy_address"] = _val("pharmacy_address", "")
        response_data["pharmacy_phone"] = _val("pharmacy_phone", "")
        response_data["pharmacy_nif"] = _val("pharmacy_nif", "")
        
    response_data["currency"] = settings_dict.get("currency", "FBu") or "FBu"
    response_data["logo_url"] = settings_dict.get("logo_url", None)
    
    try:
        response_data["bonus_percentage"] = float(settings_dict.get("bonus_percentage", 0.0))
    except (ValueError, TypeError):
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
def update_settings(
    settings_update: SettingsUpdate,
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_local_db)
):
    """
    Update configuration settings.
    Synchronizes both the Settings key-value store and the Pharmacy record.
    """
    update_data = settings_update.model_dump(exclude_unset=True)
    
    # 1. Update Settings key-values with pharmacy scoping
    for key, value in update_data.items():
        if value is None:
            continue
            
        query = db.query(Settings).filter(Settings.key == key)
        if current_user.pharmacy_id:
            query = query.filter(Settings.pharmacy_id == current_user.pharmacy_id)
        setting = query.first()
        str_value = str(value)
        
        if setting:
            setting.value = str_value
        else:
            new_setting = Settings(key=key, value=str_value, pharmacy_id=current_user.pharmacy_id)
            db.add(new_setting)
            
    # 2. Synchronize the official Pharmacy entity
    if current_user.pharmacy_id:
        pharmacy = db.query(Pharmacy).filter(Pharmacy.id == current_user.pharmacy_id).first()
        if pharmacy:
            if "pharmacy_name" in update_data and update_data["pharmacy_name"]:
                pharmacy.name = update_data["pharmacy_name"].strip()
            if "pharmacy_address" in update_data and update_data["pharmacy_address"] is not None:
                pharmacy.address = update_data["pharmacy_address"].strip()
            if "pharmacy_phone" in update_data and update_data["pharmacy_phone"] is not None:
                pharmacy.phone = update_data["pharmacy_phone"].strip()
            if "pharmacy_email" in update_data and update_data["pharmacy_email"] is not None:
                pharmacy.email = update_data["pharmacy_email"].strip()
            if "pharmacy_nif" in update_data and update_data["pharmacy_nif"] is not None:
                pharmacy.nif = update_data["pharmacy_nif"].strip()
                
    db.commit()
    
    return get_settings(current_user, db)

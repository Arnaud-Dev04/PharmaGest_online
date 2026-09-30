"""
Settings Schemas.
"""
from pydantic import BaseModel, Field, HttpUrl
from typing import Optional, List, Any

class SettingsUpdate(BaseModel):
    """Schema for updating settings."""
    pharmacy_name: Optional[str] = None
    pharmacy_address: Optional[str] = None
    pharmacy_phone: Optional[str] = None
    pharmacy_nif: Optional[str] = None
    bonus_percentage: Optional[float] = None
    currency: Optional[str] = "FBu"
    logo_url: Optional[str] = None # Can be URL or Base64 string
    
    # License Warning Config
    license_warning_bdays: Optional[int] = 60
    license_warning_message: Optional[str] = None
    license_warning_duration: Optional[int] = 30
    
    # We could allow arbitrary keys too, but explicit is better for now
    
class SettingsResponse(BaseModel):
    """Schema for returning aggregated settings."""
    pharmacy_name: str = "Ma Pharmacie"
    pharmacy_address: str = ""
    pharmacy_phone: str = ""
    pharmacy_nif: str = ""
    bonus_percentage: float = 0.0
    currency: str = "FBu"
    logo_url: Optional[str] = None
    
    license_warning_bdays: int = 60
    license_warning_message: str = "Ce logiciel nécessite une mise à jour de licence. Veuillez contacter le concepteur."
    license_warning_duration: int = 30
    
    class Config:
        from_attributes = True

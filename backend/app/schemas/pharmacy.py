"""Schemas for platform-managed pharmacies."""

from datetime import datetime, date as PyDate
from typing import Literal, Optional

from pydantic import BaseModel, Field, model_validator


LicensePlan = Literal["basic", "pro", "enterprise"]
PLAN_MAX_USERS = {"basic": 3, "pro": 10, "enterprise": 1000}


class PharmacyResponse(BaseModel):
    id: int
    name: str
    code: str
    address: Optional[str] = None
    phone: Optional[str] = None
    email: Optional[str] = None
    country: Optional[str] = None
    city: Optional[str] = None
    is_active: bool
    status: str = "active"  # "active", "pending_approval", "suspended", "rejected"
    plan: str
    max_users: int
    license_expires_at: Optional[PyDate] = None
    license_is_trial: bool = False
    license_key: Optional[str] = None
    notes: Optional[str] = None
    # Fiscalité OBR
    nif: Optional[str] = None
    rc_number: Optional[str] = None
    tax_center: Optional[str] = None
    obr_enabled: bool = False
    obr_environment: str = "sandbox"
    obr_system_id: Optional[str] = None
    obr_api_username: Optional[str] = None
    tp_type: Optional[str] = "2"
    tp_legal_form: Optional[str] = "SUARL"
    tp_activity_sector: Optional[str] = None
    tp_address_province: Optional[str] = None
    tp_address_commune: Optional[str] = None
    tp_address_quartier: Optional[str] = None
    tp_address_avenue: Optional[str] = None
    tp_address_rue: Optional[str] = None
    tp_address_number: Optional[str] = None
    vat_taxpayer: Optional[str] = "1"
    ct_taxpayer: Optional[str] = "0"
    tl_taxpayer: Optional[str] = "0"
    created_at: datetime

    model_config = {"from_attributes": True}


class PharmacyOnboardRequest(BaseModel):
    name: str = Field(min_length=2, max_length=200)
    code: str = Field(min_length=2, max_length=50, pattern=r"^[A-Za-z0-9_-]+$")
    address: Optional[str] = Field(default=None, max_length=500)
    phone: Optional[str] = Field(default=None, max_length=50)
    email: Optional[str] = Field(default=None, max_length=200)
    country: Optional[str] = Field(default=None, max_length=100)
    city: Optional[str] = Field(default=None, max_length=100)
    plan: LicensePlan = "basic"
    max_users: int = Field(default=3, ge=1, le=10000)
    license_expires_at: Optional[PyDate] = None
    license_is_trial: bool = False
    grant_trial: bool = True
    trial_days: int = Field(default=14, ge=1, le=365)
    notes: Optional[str] = Field(default=None, max_length=500)
    # Fiscalité OBR
    nif: Optional[str] = Field(default=None, max_length=50)
    rc_number: Optional[str] = Field(default=None, max_length=100)
    tax_center: Optional[str] = Field(default=None, max_length=50)
    obr_enabled: bool = False
    obr_environment: str = "sandbox"
    obr_system_id: Optional[str] = Field(default=None, max_length=100)
    obr_api_username: Optional[str] = Field(default=None, max_length=100)
    obr_api_password: Optional[str] = Field(default=None, max_length=255)
    tp_type: Optional[str] = "2"
    tp_legal_form: Optional[str] = "SUARL"
    tp_activity_sector: Optional[str] = None
    tp_address_province: Optional[str] = None
    tp_address_commune: Optional[str] = None
    tp_address_quartier: Optional[str] = None
    tp_address_avenue: Optional[str] = None
    tp_address_rue: Optional[str] = None
    tp_address_number: Optional[str] = None
    vat_taxpayer: Optional[str] = "1"
    ct_taxpayer: Optional[str] = "0"
    tl_taxpayer: Optional[str] = "0"
    # Admin initial
    admin_username: str = Field(min_length=3, max_length=50)
    admin_password: str = Field(min_length=8, max_length=128)

    @model_validator(mode="after")
    def validate_plan_user_limit(self):
        if self.max_users > PLAN_MAX_USERS[self.plan]:
            raise ValueError(
                f"The {self.plan} plan allows at most {PLAN_MAX_USERS[self.plan]} users"
            )
        return self


class PharmacyRegisterRequest(BaseModel):
    """Self-service registration from public client."""
    name: str = Field(min_length=2, max_length=200, description="Nom de la pharmacie")
    code: Optional[str] = Field(default=None, max_length=50, description="Code unique souhaité ou auto-généré")
    address: Optional[str] = Field(default=None, max_length=500)
    phone: str = Field(min_length=4, max_length=50, description="Numéro de téléphone de contact")
    email: str = Field(min_length=5, max_length=200, description="Adresse email de contact")
    country: str = Field(default="Burundi", max_length=100)
    city: str = Field(default="Bujumbura", max_length=100)
    
    # Responsable / Admin initial
    admin_username: str = Field(min_length=3, max_length=50, description="Nom d'utilisateur admin")
    admin_password: str = Field(min_length=6, max_length=128, description="Mot de passe")
    admin_name: Optional[str] = Field(default=None, max_length=120, description="Nom complet du titulaire")
    
    # Fiscalité OBR
    nif: str = Field(min_length=4, max_length=50, description="Numéro d'Identification Fiscale (NIF)")
    rc_number: Optional[str] = Field(default=None, max_length=100, description="Registre de commerce")
    tax_center: Optional[str] = Field(default="DPMC", max_length=50)
    tp_type: str = Field(default="2", max_length=5)
    tp_legal_form: Optional[str] = Field(default="SUARL", max_length=50)
    tp_activity_sector: Optional[str] = Field(default="Commerce de détail de produits pharmaceutiques", max_length=250)
    tp_address_province: Optional[str] = Field(default="BUJUMBURA MAIRIE", max_length=50)
    tp_address_commune: Optional[str] = Field(default="MUKAZA", max_length=50)
    tp_address_quartier: Optional[str] = Field(default="ROHERO", max_length=50)
    tp_address_avenue: Optional[str] = Field(default="", max_length=50)
    tp_address_rue: Optional[str] = Field(default="", max_length=50)
    tp_address_number: Optional[str] = Field(default="", max_length=20)
    vat_taxpayer: str = Field(default="1", max_length=3)
    ct_taxpayer: str = Field(default="0", max_length=3)
    tl_taxpayer: str = Field(default="0", max_length=3)
    
    # Plan souhaité
    plan: LicensePlan = "basic"
    notes: Optional[str] = Field(default=None, max_length=500)


class PharmacyApprovalRequest(BaseModel):
    """Approval parameters by Platform Admin."""
    trial_days: int = Field(default=14, ge=1, le=365)
    plan: Optional[LicensePlan] = None
    max_users: Optional[int] = None


class PharmacyApprovalResponse(BaseModel):
    success: bool
    message: str
    pharmacy: PharmacyResponse
    license_key: str
    license_expires_at: Optional[PyDate] = None
    plan: str


class PharmacyUpdateRequest(BaseModel):
    name: Optional[str] = Field(default=None, min_length=2, max_length=200)
    address: Optional[str] = Field(default=None, max_length=500)
    phone: Optional[str] = Field(default=None, max_length=50)
    email: Optional[str] = Field(default=None, max_length=200)
    country: Optional[str] = Field(default=None, max_length=100)
    city: Optional[str] = Field(default=None, max_length=100)
    plan: Optional[LicensePlan] = None
    max_users: Optional[int] = Field(default=None, ge=1, le=10000)
    license_expires_at: Optional[PyDate] = None
    license_is_trial: Optional[bool] = None
    notes: Optional[str] = Field(default=None, max_length=500)
    nif: Optional[str] = Field(default=None, max_length=50)
    rc_number: Optional[str] = Field(default=None, max_length=100)
    tax_center: Optional[str] = Field(default=None, max_length=50)
    obr_enabled: Optional[bool] = None
    obr_environment: Optional[str] = None
    obr_system_id: Optional[str] = Field(default=None, max_length=100)
    obr_api_username: Optional[str] = Field(default=None, max_length=100)
    obr_api_password: Optional[str] = Field(default=None, max_length=255)
    tp_type: Optional[str] = None
    tp_legal_form: Optional[str] = None
    tp_activity_sector: Optional[str] = None
    tp_address_province: Optional[str] = None
    tp_address_commune: Optional[str] = None
    tp_address_quartier: Optional[str] = None
    tp_address_avenue: Optional[str] = None
    tp_address_rue: Optional[str] = None
    tp_address_number: Optional[str] = None
    vat_taxpayer: Optional[str] = None
    ct_taxpayer: Optional[str] = None
    tl_taxpayer: Optional[str] = None


class PharmacyStatusRequest(BaseModel):
    is_active: bool


class PlatformAccountResponse(BaseModel):
    id: int
    username: str
    role: str
    is_active: bool
    must_change_password: bool
    pharmacy_id: Optional[int] = None
    pharmacy_name: Optional[str] = None


class PlatformAccountCreateRequest(BaseModel):
    username: str = Field(min_length=3, max_length=50)
    password: str = Field(min_length=8, max_length=128)


class PlatformPasswordResetRequest(BaseModel):
    temporary_password: str = Field(min_length=8, max_length=128)
    current_password: Optional[str] = Field(default=None, min_length=1, max_length=128)


class PharmacyOnboardResponse(BaseModel):
    pharmacy: PharmacyResponse
    admin_username: str
    license_key: Optional[str] = None


class PlatformMetricsResponse(BaseModel):
    pharmacy_count: int
    active_pharmacy_count: int
    pending_pharmacy_count: int = 0
    user_count: int
    sale_count: int
    total_revenue: float


class PlatformPharmacyMetricsResponse(PlatformMetricsResponse):
    pharmacy: PharmacyResponse


class PharmacyOBRConfigRequest(BaseModel):
    nif: Optional[str] = None
    rc_number: Optional[str] = None
    tax_center: Optional[str] = None
    obr_enabled: Optional[bool] = None
    obr_environment: Optional[str] = "sandbox"
    obr_system_id: Optional[str] = None
    obr_api_username: Optional[str] = None
    obr_api_password: Optional[str] = None
    tp_type: Optional[str] = "2"
    tp_legal_form: Optional[str] = "SUARL"
    tp_activity_sector: Optional[str] = None
    tp_address_province: Optional[str] = None
    tp_address_commune: Optional[str] = None
    tp_address_quartier: Optional[str] = None
    tp_address_avenue: Optional[str] = None
    tp_address_rue: Optional[str] = None
    tp_address_number: Optional[str] = None
    vat_taxpayer: Optional[str] = "1"
    ct_taxpayer: Optional[str] = "0"
    tl_taxpayer: Optional[str] = "0"

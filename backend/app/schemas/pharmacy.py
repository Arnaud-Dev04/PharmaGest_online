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
    plan: str
    max_users: int
    license_expires_at: Optional[PyDate] = None
    license_is_trial: bool = False
    notes: Optional[str] = None
    # Fiscalité OBR
    nif: Optional[str] = None
    rc_number: Optional[str] = None
    tax_center: Optional[str] = None
    obr_enabled: bool = False
    obr_environment: str = "sandbox"
    obr_system_id: Optional[str] = None
    obr_api_username: Optional[str] = None
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
    notes: Optional[str] = Field(default=None, max_length=500)
    nif: Optional[str] = Field(default=None, max_length=50)
    rc_number: Optional[str] = Field(default=None, max_length=100)
    tax_center: Optional[str] = Field(default=None, max_length=50)
    obr_enabled: bool = False
    obr_environment: str = "sandbox"
    obr_system_id: Optional[str] = Field(default=None, max_length=100)
    obr_api_username: Optional[str] = Field(default=None, max_length=100)
    obr_api_password: Optional[str] = Field(default=None, max_length=255)
    admin_username: str = Field(min_length=3, max_length=50)
    admin_password: str = Field(min_length=8, max_length=128)

    @model_validator(mode="after")
    def validate_plan_user_limit(self):
        if self.max_users > PLAN_MAX_USERS[self.plan]:
            raise ValueError(
                f"The {self.plan} plan allows at most {PLAN_MAX_USERS[self.plan]} users"
            )
        return self


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


class PlatformMetricsResponse(BaseModel):
    pharmacy_count: int
    active_pharmacy_count: int
    user_count: int
    sale_count: int
    total_revenue: float


class PlatformPharmacyMetricsResponse(PlatformMetricsResponse):
    pharmacy: PharmacyResponse
"""Schemas for platform-managed pharmacies."""

from datetime import datetime
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


class PharmacyStatusRequest(BaseModel):
    is_active: bool


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
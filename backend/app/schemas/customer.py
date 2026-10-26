"""
Customer schemas for POS system.
"""

from pydantic import BaseModel, Field
from datetime import datetime
from typing import Optional


class CustomerCreate(BaseModel):
    """Schema for creating a customer."""
    first_name: str = Field(..., min_length=1, max_length=100, description="First name")
    last_name: str = Field(..., min_length=1, max_length=100, description="Last name")
    phone: str = Field(..., min_length=1, max_length=20, description="Phone number (unique)")
    customer_nif: Optional[str] = Field(None, max_length=50, description="NIF du client (si entreprise ou assujetti)")
    customer_tax_center: Optional[str] = Field(None, max_length=50, description="Centre fiscal du client")
    
    model_config = {
        "json_schema_extra": {
            "examples": [
                {
                    "first_name": "Jean",
                    "last_name": "Dupont",
                    "phone": "+25771234567",
                    "customer_nif": "4000123456"
                }
            ]
        }
    }


class CustomerUpdate(BaseModel):
    """Schema for updating a customer."""
    first_name: Optional[str] = Field(None, min_length=1, max_length=100)
    last_name: Optional[str] = Field(None, min_length=1, max_length=100)
    customer_nif: Optional[str] = Field(None, max_length=50)
    customer_tax_center: Optional[str] = Field(None, max_length=50)


class CustomerResponse(BaseModel):
    """Schema for customer in responses."""
    id: int
    first_name: str
    last_name: str
    phone: str
    total_points: int
    customer_nif: Optional[str] = None
    customer_tax_center: Optional[str] = None
    created_at: datetime
    updated_at: datetime
    
    model_config = {"from_attributes": True}

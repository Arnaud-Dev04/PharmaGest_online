"""
Supplier schemas for CRUD operations.
"""

from pydantic import BaseModel, Field, EmailStr, field_validator
from datetime import datetime
from typing import Optional


class SupplierCreate(BaseModel):
    """Schema for creating a supplier."""
    name: str = Field(..., min_length=1, max_length=200, description="Supplier/company name")
    phone: Optional[str] = Field(None, max_length=20, description="Contact phone number")
    email: Optional[EmailStr] = Field(None, description="Contact email")
    contact_name: Optional[str] = Field(None, max_length=100, description="Contact person name")

    @field_validator('email', 'phone', 'contact_name', mode='before')
    @classmethod
    def empty_str_to_none(cls, v):
        """Convertit les chaînes vides en None pour les champs optionnels."""
        if isinstance(v, str) and v.strip() == '':
            return None
        return v

    model_config = {
        "json_schema_extra": {
            "examples": [
                {
                    "name": "Pharma Distributeur SA",
                    "phone": "+25771234567",
                    "email": "contact@pharmadist.bi",
                    "contact_name": "Jean Dupont"
                }
            ]
        }
    }


class SupplierUpdate(BaseModel):
    """Schema for updating a supplier (all fields optional)."""
    name: Optional[str] = Field(None, min_length=1, max_length=200)
    phone: Optional[str] = Field(None, max_length=20)
    email: Optional[EmailStr] = None
    contact_name: Optional[str] = Field(None, max_length=100)

    @field_validator('email', 'phone', 'contact_name', mode='before')
    @classmethod
    def empty_str_to_none(cls, v):
        """Convertit les chaînes vides en None pour les champs optionnels."""
        if isinstance(v, str) and v.strip() == '':
            return None
        return v


class SupplierResponse(BaseModel):
    """Schema for supplier in responses."""
    id: int
    name: str
    phone: Optional[str]
    email: Optional[str]
    contact_name: Optional[str]
    created_at: datetime
    updated_at: datetime
    
    model_config = {"from_attributes": True}

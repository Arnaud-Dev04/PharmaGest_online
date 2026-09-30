"""
Sales schemas for POS system.
"""

from pydantic import BaseModel, Field
from datetime import datetime
from typing import List, Optional
from app.models.sales import PaymentMethod, SaleType


# ============================================================================
# SALE ITEM SCHEMAS
# ============================================================================

class SaleItemCreate(BaseModel):
    """Schema for creating a sale item."""
    medicine_id: int = Field(..., gt=0, description="Medicine ID")
    quantity: int = Field(..., gt=0, description="Quantity to sell")
    sale_type: SaleType = Field(default=SaleType.PACKAGING, description="Unit type (packaging or unit)")
    discount_percent: float = Field(default=0.0, ge=0, le=100, description="Discount percentage")
    
    model_config = {
        "json_schema_extra": {
            "examples": [
                {
                    "medicine_id": 1,
                    "quantity": 10,
                    "sale_type": "packaging",
                    "discount_percent": 0.0
                }
            ]
        }
    }


class SaleItemResponse(BaseModel):
    """Schema for sale item in responses."""
    id: int
    medicine_id: int
    medicine_name: str
    medicine_code: str
    quantity: int
    unit_price: float
    total_price: float
    sale_type: SaleType = SaleType.PACKAGING
    discount_percent: float = 0.0
    
    model_config = {"from_attributes": True}


# ============================================================================
# SALE SCHEMAS
# ============================================================================

class SaleCreate(BaseModel):
    """Schema for creating a sale."""
    items: List[SaleItemCreate] = Field(..., min_length=1, description="List of items to sell")
    payment_method: PaymentMethod = Field(default=PaymentMethod.CASH, description="Payment method")
    discount_percent: Optional[float] = Field(default=0.0, ge=0, le=100, description="Discount percentage (0-100)")
    customer_id: Optional[int] = Field(None, description="Existing Customer ID")
    customer_phone: Optional[str] = Field(None, max_length=20, description="Customer phone (for bonus)")
    customer_first_name: Optional[str] = Field(None, max_length=100, description="Customer first name (if new)")
    customer_last_name: Optional[str] = Field(None, max_length=100, description="Customer last name (if new)")
    
    # Insurance info
    insurance_provider: Optional[str] = None
    insurance_card_id: Optional[str] = None
    coverage_percent: Optional[float] = 0.0
    
    model_config = {
        "json_schema_extra": {
            "examples": [
                {
                    "items": [
                        {"medicine_id": 1, "quantity": 10},
                        {"medicine_id": 2, "quantity": 5}
                    ],
                    "payment_method": "cash",
                    "discount_percent": 10.0,
                    "customer_phone": "+25771234567",
                    "customer_first_name": "Jean",
                    "customer_last_name": "Dupont"
                }
            ]
        }
    }


class SaleResponse(BaseModel):
    """Schema for sale in responses."""
    id: int
    code: str
    total_amount: float
    payment_method: PaymentMethod
    date: datetime
    user_id: int
    user_name: Optional[str] = None
    status: str = "completed"
    cancelled_at: Optional[datetime] = None
    cancelled_by: Optional[str] = None
    customer_id: Optional[int]
    
    # Insurance info
    insurance_provider: Optional[str] = None
    insurance_card_id: Optional[str] = None
    coverage_percent: Optional[float] = 0.0
    
    items: List[SaleItemResponse]
    customer: Optional[dict] = None
    bonus_earned: int = 0
    
    model_config = {"from_attributes": True}

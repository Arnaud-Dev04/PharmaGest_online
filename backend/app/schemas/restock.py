"""
Restock schemas.
"""
from typing import List, Optional
from pydantic import BaseModel, Field
from datetime import date
from enum import Enum

# Shared Enums (matching models)
class RestockStatus(str, Enum):
    DRAFT = "draft"
    CONFIRMED = "confirmed"
    RECEIVED = "received"
    CANCELLED = "cancelled"

# --- Items ---

class RestockItemCreate(BaseModel):
    medicine_id: int
    quantity: int = Field(..., gt=0)
    price_buy: float = Field(..., ge=0)
    expiry_date: Optional[date] = None


class RestockItemResponse(BaseModel):
    id: int
    medicine_id: int
    medicine_name: str # Enriched in service
    quantity: int
    price_buy: float
    expiry_date: Optional[date] = None
    
    class Config:
        from_attributes = True


# --- Orders ---

class RestockOrderCreate(BaseModel):
    supplier_id: int
    date: date = Field(default_factory=date.today)
    items: List[RestockItemCreate]


class RestockOrderResponse(BaseModel):
    id: int
    supplier_id: int
    supplier_name: Optional[str] = None # Enriched
    status: RestockStatus
    date: date
    total_amount: float
    items: List[RestockItemResponse] = []
    
    class Config:
        from_attributes = True

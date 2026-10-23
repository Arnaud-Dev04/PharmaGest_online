"""
Sync schemas for batch operations and incremental transfers.
"""

from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime


class SyncBatchSaleItemPayload(BaseModel):
    medicine_code: str
    quantity: float = Field(..., gt=0)
    unit_price: float = Field(..., ge=0)
    total_price: float = Field(..., ge=0)
    batch_number: Optional[str] = None


class SyncSalePayload(BaseModel):
    sale_uuid: str = Field(..., min_length=1, max_length=64)
    code: str = Field(..., min_length=1, max_length=50)
    total_amount: float = Field(..., ge=0)
    payment_method: str = Field(default="cash")
    date: Optional[datetime] = None
    cash_session_uuid: Optional[str] = None
    customer_phone: Optional[str] = None
    customer_name: Optional[str] = None
    notes: Optional[str] = None
    items: List[SyncBatchSaleItemPayload] = []


class SyncBatchUpRequest(BaseModel):
    """Batch payload containing up to 100 sales."""
    sales: List[SyncSalePayload] = Field(..., max_length=100)


class SyncBatchUpResponse(BaseModel):
    total_received: int
    total_inserted: int
    total_skipped: int
    errors: List[dict] = []

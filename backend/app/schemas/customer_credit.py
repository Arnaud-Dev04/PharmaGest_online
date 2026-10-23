"""
Customer Credit and Payment schemas.
"""

from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import date, datetime


class CreditPaymentCreate(BaseModel):
    amount: float = Field(..., gt=0, description="Montant remboursé")
    payment_method: str = Field(default="cash")
    notes: Optional[str] = None


class CreditPaymentResponse(BaseModel):
    id: int
    credit_id: int
    amount: float
    payment_method: str
    payment_date: datetime
    received_by: Optional[int] = None
    notes: Optional[str] = None

    model_config = {"from_attributes": True}


class CustomerCreditCreate(BaseModel):
    customer_id: int
    sale_id: Optional[int] = None
    amount: float = Field(..., gt=0)
    due_date: Optional[date] = None
    notes: Optional[str] = None


class CustomerCreditResponse(BaseModel):
    id: int
    customer_id: int
    sale_id: Optional[int] = None
    amount: float
    amount_paid: float
    remaining_amount: float
    due_date: Optional[date] = None
    status: str
    notes: Optional[str] = None
    created_at: datetime
    payments: List[CreditPaymentResponse] = []

    model_config = {"from_attributes": True}


class CreditSummaryResponse(BaseModel):
    total_credit: float
    total_paid: float
    total_outstanding: float
    pending_count: int
    overdue_count: int
    paid_count: int

"""Request and response schemas for cashier sessions."""

from datetime import datetime
from typing import Literal, Optional

from pydantic import BaseModel, Field


class CashSessionOpenRequest(BaseModel):
    opening_amount: float = Field(ge=0, le=1_000_000_000)
    notes: Optional[str] = Field(default=None, max_length=500)


class CashMovementCreate(BaseModel):
    movement_type: Literal["cash_in", "cash_out"]
    amount: float = Field(gt=0, le=1_000_000_000)
    reason: str = Field(min_length=2, max_length=255)


class CashSessionCloseRequest(BaseModel):
    counted_amount: float = Field(ge=0, le=1_000_000_000)
    notes: Optional[str] = Field(default=None, max_length=500)


class CashMovementResponse(BaseModel):
    id: int
    movement_uuid: str
    session_uuid: str
    session_id: int
    cashier_id: int
    movement_type: str
    amount: float
    reason: str
    occurred_at: datetime

    model_config = {"from_attributes": True}


class CashSessionResponse(BaseModel):
    id: int
    session_uuid: str
    pharmacy_id: int
    cashier_id: int
    cashier_username: str
    opened_at: datetime
    opening_amount: float
    closed_at: Optional[datetime] = None
    expected_amount: Optional[float] = None
    current_expected_amount: float = 0.0
    counted_amount: Optional[float] = None
    variance: Optional[float] = None
    status: str
    notes: Optional[str] = None
    cash_sales_total: float = 0.0
    cash_in_total: float = 0.0
    cash_out_total: float = 0.0
    movements: list[CashMovementResponse] = Field(default_factory=list)


class CashSessionListResponse(BaseModel):
    items: list[CashSessionResponse]
    total: int
    page: int
    page_size: int
    total_pages: int
"""Cashier-session and cash reconciliation API."""

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.auth.dependencies import get_current_active_user
from app.database import get_local_db
from app.models.user import User
from app.schemas.cash_register import (
    CashMovementCreate,
    CashSessionCloseRequest,
    CashSessionOpenRequest,
    CashSessionResponse,
)
from app.services import cash_register_service

router = APIRouter()


@router.get("/current", response_model=CashSessionResponse | None)
def get_current_cash_session(
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_local_db),
):
    return cash_register_service.get_current_session(db, current_user)


@router.post("/open", response_model=CashSessionResponse, status_code=status.HTTP_201_CREATED)
def open_cash_session(
    payload: CashSessionOpenRequest,
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_local_db),
):
    return cash_register_service.open_session(
        db,
        current_user,
        payload.opening_amount,
        payload.notes,
    )


@router.post("/{session_id}/movements", response_model=CashSessionResponse)
def create_cash_movement(
    session_id: int,
    payload: CashMovementCreate,
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_local_db),
):
    return cash_register_service.add_movement(
        db,
        session_id,
        current_user,
        payload.movement_type,
        payload.amount,
        payload.reason,
    )


@router.post("/{session_id}/close", response_model=CashSessionResponse)
def close_cash_session(
    session_id: int,
    payload: CashSessionCloseRequest,
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_local_db),
):
    return cash_register_service.close_session(
        db,
        session_id,
        current_user,
        payload.counted_amount,
        payload.notes,
    )


@router.get("/sessions")
def list_cash_sessions(
    page: int = Query(1, ge=1),
    page_size: int = Query(25, ge=1, le=100),
    status_filter: str | None = Query(None, pattern="^(open|closed)$"),
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_local_db),
):
    return cash_register_service.list_sessions(
        db,
        current_user,
        page,
        page_size,
        status_filter,
    )
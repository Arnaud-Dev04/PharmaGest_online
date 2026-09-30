"""
Restock Routes - Supplier orders and inventory replenishment.
"""

from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.database import get_local_db
from app.models.user import User
from app.auth.dependencies import get_current_active_user
from app.schemas.restock import RestockOrderCreate, RestockOrderResponse, RestockItemResponse
from app.schemas.medicine import MedicineResponse
from app.services import restock_service

router = APIRouter()

@router.post(
    "/create",
    response_model=RestockOrderResponse,
    summary="Create a draft restock order"
)
async def create_restock_order(
    order: RestockOrderCreate,
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_local_db)
):
    """
    Create a new restock order in DRAFT status.
    Does not update stock yet.
    """
    new_order = restock_service.create_order(db, order)
    
    # Enrichment for response
    # We need to manually populate supplier_name and medicine_names if response model demands it
    # Pydantic's from_attributes handles relations if they are loaded.
    # We might need to refresh or eager load.
    
    return new_order


@router.post(
    "/{id}/confirm",
    response_model=RestockOrderResponse,
    summary="Confirm order and update stock"
)
async def confirm_restock_order(
    id: int,
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_local_db)
):
    """
    Confirm a draft order.
    Increments stock quantities for all items in the order.
    """
    return restock_service.confirm_order(db, id)


@router.post(
    "/{id}/cancel",
    response_model=RestockOrderResponse,
    summary="Cancel a restock order"
)
async def cancel_restock_order(
    id: int,
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_local_db)
):
    """
    Cancel an order.
    If it was confirmed, stock will be reverted.
    """
    return restock_service.cancel_order(db, id)


@router.get(
    "/low-stock",
    response_model=List[MedicineResponse],
    summary="Get medicines with low stock"
)
async def get_low_stock_medicines(
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_local_db)
):
    """
    List all medicines where quantity <= min_stock_alert.
    Use this to identify what needs ordering.
    """
    return restock_service.get_low_stock_medicines(db)

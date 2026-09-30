"""
Customer management routes.
"""

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List, Optional

from app.database import get_local_db
from app.models.user import User
from app.auth.dependencies import get_current_active_user
from app.services import customer_service
from app.schemas.customer import CustomerResponse, CustomerCreate, CustomerUpdate
from app.schemas.common import PaginatedResponse

router = APIRouter()

@router.post(
    "/",
    response_model=CustomerResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create a new customer"
)
async def create_customer(
    customer_data: CustomerCreate,
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_local_db)
):
    """
    Create a new customer.
    """
    customer = customer_service.create_customer(db, customer_data)
    return customer

@router.get(
    "/",
    response_model=PaginatedResponse[CustomerResponse],
    summary="Get customers list"
)
async def get_customers(
    page: int = 1,
    page_size: int = 50,
    search: Optional[str] = None,
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_local_db)
):
    """
    Get all customers with pagination and search.
    """
    customers, total = customer_service.get_customers(
        db=db, 
        page=page, 
        page_size=page_size, 
        search=search
    )
    
    return PaginatedResponse(
        total=total,
        page=page,
        page_size=page_size,
        total_pages=(total + page_size - 1) // page_size,
        items=[CustomerResponse.model_validate(c) for c in customers]
    )

@router.get(
    "/{customer_id}",
    response_model=CustomerResponse,
    summary="Get customer details"
)
async def get_customer(
    customer_id: int,
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_local_db)
):
    customer = customer_service.get_customer_by_id(db, customer_id)
    if not customer:
        raise HTTPException(status_code=404, detail="Customer not found")
    return customer

@router.put(
    "/{customer_id}",
    response_model=CustomerResponse,
    summary="Update customer details"
)
async def update_customer(
    customer_id: int,
    customer_data: CustomerUpdate,
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_local_db)
):
    """
    Update customer information.
    """
    customer = customer_service.update_customer(db, customer_id, customer_data)
    if not customer:
        raise HTTPException(status_code=404, detail="Customer not found")
    return customer

@router.delete(
    "/{customer_id}",
    summary="Delete customer"
)
async def delete_customer(
    customer_id: int,
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_local_db)
):
    """
    Delete a customer. 
    Fails if the customer has sales history.
    """
    # Only Admin or Pharmacist? Let's say anyone can delete for now if safe
    if current_user.role not in ["admin", "super_admin", "pharmacist"]:
         raise HTTPException(status_code=403, detail="Not authorized")

    success = customer_service.delete_customer(db, customer_id)
    if not success:
         # Note: service might raise HTTPException directly for safety logic
         raise HTTPException(status_code=404, detail="Customer not found")
         
    return {"message": "Customer deleted successfully"}

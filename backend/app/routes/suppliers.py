"""
Supplier routes - CRUD operations for suppliers.
"""

from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session

from app.database import get_local_db
from app.models.user import User
from app.auth.dependencies import get_current_active_user, get_admin_user
from app.schemas.supplier import SupplierCreate, SupplierUpdate, SupplierResponse
from app.schemas.common import PaginatedResponse
from app.services import supplier_service

# Create router
router = APIRouter()


@router.get(
    "",
    response_model=PaginatedResponse[SupplierResponse],
    summary="List suppliers with pagination"
)
async def list_suppliers(
    page: int = Query(1, ge=1, description="Page number"),
    page_size: int = Query(50, ge=1, le=100, description="Items per page"),
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_local_db)
):
    """
    Get suppliers list with pagination.
    
    **Accessible to**: All authenticated users
    """
    suppliers, total = supplier_service.get_suppliers(db, page, page_size)
    
    return PaginatedResponse.create(
        items=suppliers,
        total=total,
        page=page,
        page_size=page_size
    )


@router.get(
    "/{supplier_id}",
    response_model=SupplierResponse,
    summary="Get a specific supplier"
)
async def get_supplier(
    supplier_id: int,
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_local_db)
):
    """
    Get a single supplier by ID.
    
    **Accessible to**: All authenticated users
    """
    supplier = supplier_service.get_supplier_by_id(db, supplier_id)
    if not supplier:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Supplier with ID {supplier_id} not found"
        )
    
    return supplier


@router.post(
    "",
    response_model=SupplierResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create a new supplier (Admin only)"
)
async def create_supplier(
    supplier_data: SupplierCreate,
    current_admin: User = Depends(get_admin_user),
    db: Session = Depends(get_local_db)
):
    """
    Create a new supplier.
    
    **Accessible to**: Admin only
    """
    supplier = supplier_service.create_supplier(db, supplier_data)
    return supplier


@router.put(
    "/{supplier_id}",
    response_model=SupplierResponse,
    summary="Update a supplier (Admin only)"
)
async def update_supplier(
    supplier_id: int,
    supplier_data: SupplierUpdate,
    current_admin: User = Depends(get_admin_user),
    db: Session = Depends(get_local_db)
):
    """
    Update a supplier.
    
    **Accessible to**: Admin only
    """
    supplier = supplier_service.update_supplier(db, supplier_id, supplier_data)
    if not supplier:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Supplier with ID {supplier_id} not found"
        )
    
    return supplier


@router.delete(
    "/{supplier_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Delete a supplier (Admin only)"
)
async def delete_supplier(
    supplier_id: int,
    current_admin: User = Depends(get_admin_user),
    db: Session = Depends(get_local_db)
):
    """
    Delete a supplier.
    
    **Accessible to**: Admin only
    """
    success = supplier_service.delete_supplier(db, supplier_id)
    if not success:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Supplier with ID {supplier_id} not found"
        )

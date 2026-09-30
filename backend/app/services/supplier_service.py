"""
Supplier service layer - Business logic for suppliers.
"""

from sqlalchemy.orm import Session
from typing import List, Optional, Tuple

from app.models.supplier import Supplier
from app.schemas.supplier import SupplierCreate, SupplierUpdate


def get_suppliers(
    db: Session,
    page: int = 1,
    page_size: int = 50
) -> Tuple[List[Supplier], int]:
    """
    Get suppliers with pagination.
    
    Returns:
        Tuple of (suppliers list, total count)
    """
    query = db.query(Supplier)
    
    # Get total count
    total = query.count()
    
    # Apply pagination
    offset = (page - 1) * page_size
    suppliers = query.order_by(Supplier.name).offset(offset).limit(page_size).all()
    
    return suppliers, total


def get_supplier_by_id(db: Session, supplier_id: int) -> Optional[Supplier]:
    """Get a supplier by ID."""
    return db.query(Supplier).filter(Supplier.id == supplier_id).first()


def create_supplier(db: Session, supplier_data: SupplierCreate) -> Supplier:
    """Create a new supplier."""
    supplier = Supplier(**supplier_data.model_dump())
    db.add(supplier)
    db.commit()
    db.refresh(supplier)
    return supplier


def update_supplier(db: Session, supplier_id: int, supplier_data: SupplierUpdate) -> Optional[Supplier]:
    """Update a supplier."""
    supplier = get_supplier_by_id(db, supplier_id)
    if not supplier:
        return None
    
    # Update only provided fields
    update_data = supplier_data.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(supplier, field, value)
    
    db.commit()
    db.refresh(supplier)
    return supplier


def delete_supplier(db: Session, supplier_id: int) -> bool:
    """Delete a supplier if not used in any restock order."""
    supplier = get_supplier_by_id(db, supplier_id)
    if not supplier:
        return False
    
    # Check if supplier has linked medicines (supplied_by?)
    # Note: Medicine model doesn't link directly to supplier in our schema explicitly in `medicines` table 
    # but `RestockOrder` definitely links to it.
    
    from app.models.restock import RestockOrder
    
    # Check checks
    order_count = db.query(RestockOrder).filter(RestockOrder.supplier_id == supplier_id).count()
    if order_count > 0:
        from fastapi import HTTPException
        raise HTTPException(
            status_code=400,
            detail=f"Cannot delete supplier. They are linked to {order_count} restock orders."
        )
            
    db.delete(supplier)
    db.commit()
    return True

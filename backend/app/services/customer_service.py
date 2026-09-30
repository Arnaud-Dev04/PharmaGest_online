"""
Customer service layer - Business logic for customer management and bonus points.
"""

from sqlalchemy.orm import Session
from typing import List, Optional, Tuple

from app.models.customer import Customer
from app.schemas.customer import CustomerCreate, CustomerUpdate


def get_customer_by_phone(db: Session, phone: str) -> Optional[Customer]:
    """
    Get a customer by phone number.
    
    Args:
        db: Database session
        phone: Customer phone number
        
    Returns:
        Customer if found, None otherwise
    """
    return db.query(Customer).filter(Customer.phone == phone).first()


def get_customer_by_id(db: Session, customer_id: int) -> Optional[Customer]:
    """Get a customer by ID."""
    return db.query(Customer).filter(Customer.id == customer_id).first()


def create_customer(db: Session, customer_data: CustomerCreate) -> Customer:
    """
    Create a new customer.
    
    Args:
        db: Database session
        customer_data: Customer creation data
        
    Returns:
        Created customer
    """
    customer = Customer(**customer_data.model_dump())
    db.add(customer)
    db.commit()
    db.refresh(customer)
    return customer


def create_or_get_customer(
    db: Session,
    phone: str,
    first_name: Optional[str] = None,
    last_name: Optional[str] = None
) -> Customer:
    """
    Get existing customer or create new one (auto-registration).
    
    Args:
        db: Database session
        phone: Customer phone number
        first_name: First name (required if customer doesn't exist)
        last_name: Last name (required if customer doesn't exist)
        
    Returns:
        Existing or newly created customer
        
    Raises:
        ValueError: If customer doesn't exist and names not provided
    """
    # Try to find existing customer
    customer = get_customer_by_phone(db, phone)
    
    if customer:
        return customer
    
    # Create new customer
    if not first_name or not last_name:
        raise ValueError(
            "Customer not found. first_name and last_name are required to create a new customer."
        )
    
    customer_data = CustomerCreate(
        first_name=first_name,
        last_name=last_name,
        phone=phone
    )
    return create_customer(db, customer_data)


def add_bonus_points(db: Session, customer_id: int, points: int) -> Customer:
    """
    Add bonus points to a customer.
    
    Args:
        db: Database session
        customer_id: Customer ID
        points: Points to add
        
    Returns:
        Updated customer
    """
    customer = get_customer_by_id(db, customer_id)
    if not customer:
        raise ValueError(f"Customer with ID {customer_id} not found")
    
    customer.total_points += points
    db.commit()
    db.refresh(customer)
    return customer


def update_customer(db: Session, customer_id: int, customer_data: CustomerUpdate) -> Optional[Customer]:
    """Update a customer."""
    customer = get_customer_by_id(db, customer_id)
    if not customer:
        return None
    
    update_data = customer_data.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(customer, field, value)
    
    db.commit()
    db.refresh(customer)
    return customer


def get_customers(
    db: Session, 
    page: int = 1, 
    page_size: int = 50, 
    search: Optional[str] = None
) -> Tuple[List[Customer], int]:
    """
    Get customers with pagination and optional search.
    """
    query = db.query(Customer)
    
    if search:
        search_term = f"%{search}%"
        query = query.filter(
            (Customer.first_name.ilike(search_term)) |
            (Customer.last_name.ilike(search_term)) |
            (Customer.phone.ilike(search_term))
        )
        
    total = query.count()
    
    offset = (page - 1) * page_size
    customers = query.order_by(Customer.last_name).offset(offset).limit(page_size).all()
    
    return customers, total


def delete_customer(db: Session, customer_id: int) -> bool:
    """
    Delete a customer safely.
    Prevent deletion if customer has sales history.
    """
    customer = get_customer_by_id(db, customer_id)
    if not customer:
        return False
        
    # Check for sales history
    if customer.sales:
        from fastapi import HTTPException
        raise HTTPException(
            status_code=400, 
            detail="Cannot delete customer with existing sales history."
        )
        
    db.delete(customer)
    db.commit()
    return True

"""
Supplier model for managing medicine suppliers.
"""

from sqlalchemy import Column, String
from app.database import Base
from app.models.base import BaseModelMixin
from sqlalchemy.orm import relationship


class Supplier(Base, BaseModelMixin):
    """
    Supplier model.
    
    Attributes:
        name: Company/supplier name
        phone: Contact phone number
        email: Contact email
        contact_name: Name of contact person
    """
    __tablename__ = "suppliers"
    
    name = Column(String(200), nullable=False, index=True)
    phone = Column(String(20), nullable=True)
    email = Column(String(100), nullable=True)
    contact_name = Column(String(100), nullable=True)
    
    # Relationships
    restock_orders = relationship("RestockOrder", back_populates="supplier")
    
    def __repr__(self):
        return f"<Supplier(id={self.id}, name='{self.name}')>"

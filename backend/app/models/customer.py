"""
Customer model for managing customer loyalty and bonus points.
"""

from sqlalchemy import Column, String, Integer
from app.database import Base
from app.models.base import BaseModelMixin
from sqlalchemy.orm import relationship


class Customer(Base, BaseModelMixin):
    """
    Customer model for loyalty program.
    
    Attributes:
        first_name: Customer first name
        last_name: Customer last name
        phone: Phone number (unique identifier)
        total_points: Accumulated bonus points
    """
    __tablename__ = "customers"
    
    first_name = Column(String(100), nullable=False)
    last_name = Column(String(100), nullable=False)
    phone = Column(String(20), unique=True, nullable=False, index=True)
    total_points = Column(Integer, default=0, nullable=False)
    
    # Relationships
    sales = relationship("Sale", back_populates="customer")
    
    def __repr__(self):
        return f"<Customer(id={self.id}, name='{self.first_name} {self.last_name}', points={self.total_points})>"

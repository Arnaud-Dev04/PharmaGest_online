"""
Customer model for managing customer loyalty and bonus points.
"""

from sqlalchemy import Column, Integer, String, UniqueConstraint
from app.database import Base
from app.models.base import BaseModelMixin, PharmacyScopedMixin
from sqlalchemy.orm import relationship


class Customer(Base, BaseModelMixin, PharmacyScopedMixin):
    """
    Customer model for loyalty program.
    
    Attributes:
        first_name: Customer first name
        last_name: Customer last name
        phone: Phone number (unique identifier)
        total_points: Accumulated bonus points
    """
    __tablename__ = "customers"
    __table_args__ = (
        UniqueConstraint("pharmacy_id", "phone", name="uq_customers_pharmacy_phone"),
    )
    
    first_name = Column(String(100), nullable=False)
    last_name = Column(String(100), nullable=False)
    phone = Column(String(20), nullable=False, index=True)
    total_points = Column(Integer, default=0, nullable=False)
    
    # Informations fiscales OBR
    customer_nif = Column(String(50), nullable=True, index=True)
    customer_tax_center = Column(String(50), nullable=True)
    
    # Relationships
    sales = relationship("Sale", back_populates="customer")
    
    def __repr__(self):
        return f"<Customer(id={self.id}, name='{self.first_name} {self.last_name}', points={self.total_points})>"

"""
Batch (Lot) model for pharmacy stock management.
Each medicine can have multiple batches with different expiration dates.
Used for FEFO (First Expired First Out) stock management.
"""

from sqlalchemy import Column, String, Integer, Float, Date, ForeignKey, Boolean
from sqlalchemy.orm import relationship
from app.database import Base
from app.models.base import BaseModelMixin


class Batch(Base, BaseModelMixin):
    """
    Represents a specific lot/batch of a medicine.
    
    Each batch tracks:
    - batch_number: The supplier's lot number
    - expiration_date: When this batch expires (used for FEFO ordering)
    - quantity: Remaining stock in this specific batch
    - purchase_price: Cost price for this particular batch
    
    FEFO Logic:
        When selling, batches are consumed in order of expiration_date ASC
        (earliest expiring batch is sold first).
    """
    __tablename__ = "batches"
    
    batch_number = Column(String(100), nullable=False, index=True)
    medicine_id = Column(Integer, ForeignKey("medicines.id"), nullable=False)
    expiration_date = Column(Date, nullable=False, index=True)
    quantity = Column(Float, default=0.0, nullable=False)
    purchase_price = Column(Float, nullable=True)
    is_active = Column(Boolean, default=True, nullable=False)
    
    # Relationships
    medicine = relationship("Medicine", back_populates="batches")
    pos_sale_items = relationship("POSSaleItem", back_populates="batch")
    
    def __repr__(self):
        return (
            f"<Batch(id={self.id}, batch_number='{self.batch_number}', "
            f"medicine_id={self.medicine_id}, qty={self.quantity}, "
            f"exp={self.expiration_date})>"
        )

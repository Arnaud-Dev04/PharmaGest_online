"""
Restock models: RestockOrder and RestockItem.
"""

from sqlalchemy import Column, String, Float, Date, Integer, ForeignKey, Enum as SQLEnum
from sqlalchemy.orm import relationship
from app.database import Base
from app.models.base import BaseModelMixin
import enum
from datetime import date


class RestockStatus(str, enum.Enum):
    """Restock order status enumeration."""
    DRAFT = "draft"
    CONFIRMED = "confirmed"
    RECEIVED = "received"
    CANCELLED = "cancelled"


class RestockOrder(Base, BaseModelMixin):
    """
    Restock order header model.
    
    Attributes:
        supplier_id: Supplier reference
        status: Order status (draft/confirmed/received)
        date: Order date
        total_amount: Total order value in FBu
    """
    __tablename__ = "restock_orders"
    
    supplier_id = Column(Integer, ForeignKey("suppliers.id"), nullable=False)
    status = Column(SQLEnum(RestockStatus), default=RestockStatus.DRAFT, nullable=False)
    date = Column(Date, default=date.today, nullable=False, index=True)
    total_amount = Column(Float, default=0.0, nullable=False)
    
    # Relationships
    supplier = relationship("Supplier", back_populates="restock_orders")
    items = relationship("RestockItem", back_populates="order", cascade="all, delete-orphan")
    
    def __repr__(self):
        return f"<RestockOrder(id={self.id}, supplier_id={self.supplier_id}, status='{self.status}', total={self.total_amount} FBu)>"


class RestockItem(Base, BaseModelMixin):
    """
    Restock order line item model.
    
    Attributes:
        order_id: Parent order reference
        medicine_id: Medicine/product reference
        quantity: Quantity ordered
        price_buy: Purchase price per unit
    """
    __tablename__ = "restock_items"
    
    order_id = Column(Integer, ForeignKey("restock_orders.id", ondelete="CASCADE"), nullable=False)
    medicine_id = Column(Integer, ForeignKey("medicines.id"), nullable=False)
    quantity = Column(Integer, nullable=False)
    price_buy = Column(Float, nullable=False)
    expiry_date = Column(Date, nullable=True) # New: Track expiry for this batch update
    
    # Relationships
    order = relationship("RestockOrder", back_populates="items")
    medicine = relationship("Medicine", back_populates="restock_items")
    
    def __repr__(self):
        return f"<RestockItem(id={self.id}, order_id={self.order_id}, medicine_id={self.medicine_id}, qty={self.quantity})>"

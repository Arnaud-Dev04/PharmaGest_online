"""
Sales models: Sale and SaleItem.
"""

from sqlalchemy import Column, String, Float, DateTime, Integer, ForeignKey, Enum as SQLEnum
from sqlalchemy.orm import relationship
from app.database import Base
from app.models.base import BaseModelMixin
import enum
from datetime import datetime


class PaymentMethod(str, enum.Enum):
    """Payment method enumeration."""
    CASH = "cash"
    CARD = "card"
    MOBILE_MONEY = "mobile_money"
    CREDIT = "credit"
    INSURANCE_CARD = "insurance_card"


class SyncStatus(str, enum.Enum):
    """Synchronization status enumeration."""
    PENDING = "pending"
    SYNCED = "synced"
    FAILED = "failed"


class SaleStatus(str, enum.Enum):
    """Sale status enumeration."""
    COMPLETED = "completed"
    CANCELLED = "cancelled"


class SaleType(str, enum.Enum):
    """Type of sale item unit."""
    CARTON = "carton"       # Carton
    PACKAGING = "packaging" # Boîte
    BLISTER = "blister"     # Plaquette
    UNIT = "unit"           # Comprimé/Unité (Detailed)


class Sale(Base, BaseModelMixin):
    """
    Sale/Transaction header model.
    
    Attributes:
        code: Unique invoice code (auto-generated, e.g., INV-2023-0001)
        total_amount: Total sale amount in FBu
        payment_method: Method of payment
        date: Transaction date/time
        user_id: Seller (User) reference
        customer_id: Customer reference (optional)
        sync_status: Synchronization status for offline mode
    """
    __tablename__ = "sales"
    
    code = Column(String(50), unique=True, nullable=False, index=True)
    total_amount = Column(Float, nullable=False)
    payment_method = Column(String(20), nullable=False, default="cash")
    date = Column(DateTime, default=datetime.utcnow, nullable=False, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    customer_id = Column(Integer, ForeignKey("customers.id"), nullable=True)
    sync_status = Column(String(20), default="pending", nullable=False)
    
    # Cancellation fields
    status = Column(String(20), default="completed", nullable=False) # completed, cancelled
    cancelled_at = Column(DateTime, nullable=True)
    cancelled_by = Column(Integer, ForeignKey("users.id"), nullable=True)

    # Insurance fields
    insurance_provider = Column(String(100), nullable=True)
    insurance_card_id = Column(String(50), nullable=True)
    coverage_percent = Column(Float, default=0.0, nullable=True)
    
    # Relationships
    user = relationship("User", foreign_keys=[user_id])
    cancelled_by_user = relationship("User", foreign_keys=[cancelled_by])
    customer = relationship("Customer", back_populates="sales")
    items = relationship("SaleItem", back_populates="sale", cascade="all, delete-orphan")
    
    def __repr__(self):
        return f"<Sale(id={self.id}, code='{self.code}', total={self.total_amount} FBu, status='{self.status}')>"


class SaleItem(Base, BaseModelMixin):
    """
    Sale line item model.
    
    Attributes:
        sale_id: Parent sale reference
        medicine_id: Medicine/product reference
        quantity: Quantity sold (of the chosen unit type)
        unit_price: Price per unit at time of sale (adjusted for sale_type and discount)
        total_price: Line total (quantity * unit_price)
        sale_type: Unit used (Packaging or Unit)
        discount_percent: Discount applied to this item
    """
    __tablename__ = "sale_items"
    
    sale_id = Column(Integer, ForeignKey("sales.id", ondelete="CASCADE"), nullable=False)
    medicine_id = Column(Integer, ForeignKey("medicines.id"), nullable=False)
    quantity = Column(Integer, nullable=False)
    unit_price = Column(Float, nullable=False)
    total_price = Column(Float, nullable=False)
    sale_type = Column(String(50), default="packaging", nullable=False)
    discount_percent = Column(Float, default=0.0, nullable=False)
    
    # Relationships
    sale = relationship("Sale", back_populates="items")
    medicine = relationship("Medicine", back_populates="sale_items")
    
    def __repr__(self):
        return f"<SaleItem(id={self.id}, sale_id={self.sale_id}, qty={self.quantity}, total={self.total_price} FBu)>"

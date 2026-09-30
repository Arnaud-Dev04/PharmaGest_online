"""
POS Sale models: POSSale and POSSaleItem.
Dedicated POS transaction models with batch-level tracking.
Separated from legacy Sale/SaleItem to avoid breaking existing functionality.
"""

from sqlalchemy import Column, String, Float, DateTime, Integer, ForeignKey
from sqlalchemy.orm import relationship
from app.database import Base
from app.models.base import BaseModelMixin
from datetime import datetime
import uuid as uuid_lib


class POSSale(Base, BaseModelMixin):
    """
    POS Sale transaction header.

    Attributes:
        sale_uuid   : UUID universel pour la synchronisation cloud (unique)
        code        : Code lisible (POS-YYYY-NNNN)
        total_amount: Montant total en FBu
        sync_status : 'local_only' | 'pending' | 'synced' | 'error'
        synced_at   : Timestamp de la dernière sync réussie
    """
    __tablename__ = "pos_sales"

    sale_uuid = Column(
        String(36),
        unique=True,
        nullable=False,
        index=True,
        default=lambda: str(uuid_lib.uuid4())
    )
    code = Column(String(50), unique=True, nullable=False, index=True)
    total_amount = Column(Float, nullable=False)
    payment_method = Column(String(20), nullable=False, default="cash")
    date = Column(DateTime, default=datetime.now, nullable=False, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    customer_id = Column(Integer, ForeignKey("customers.id"), nullable=True)
    customer_name = Column(String(200), nullable=True)
    customer_phone = Column(String(30), nullable=True)
    status = Column(String(20), default="completed", nullable=False)
    notes = Column(String(500), nullable=True)

    # Cancellation
    cancelled_at = Column(DateTime, nullable=True)
    cancelled_by = Column(Integer, ForeignKey("users.id"), nullable=True)

    # Insurance fields
    insurance_provider = Column(String(100), nullable=True)
    insurance_card_id = Column(String(50), nullable=True)
    coverage_percent = Column(Float, default=0.0, nullable=True)

    # Champs de synchronisation cloud
    # 'local_only' -> jamais envoye
    # 'pending'    -> en file d'attente
    # 'synced'     -> confirme dans la DB MySQL remote
    # 'error'      -> echec de sync
    sync_status = Column(String(20), default="local_only", nullable=False, index=True)
    synced_at = Column(DateTime, nullable=True)

    # Relationships
    user = relationship("User", foreign_keys=[user_id])
    cancelled_by_user = relationship("User", foreign_keys=[cancelled_by])
    customer = relationship("Customer")
    items = relationship("POSSaleItem", back_populates="sale", cascade="all, delete-orphan")

    def __repr__(self):
        return (
            f"<POSSale(id={self.id}, uuid='{self.sale_uuid}', code='{self.code}', "
            f"total={self.total_amount} FBu, status='{self.status}', sync='{self.sync_status}')>"
        )


class POSSaleItem(Base, BaseModelMixin):
    """
    POS Sale line item — always linked to a specific batch.

    Note: A single product may have multiple line items if the quantity
    spans across multiple batches (FEFO allocation).
    """
    __tablename__ = "pos_sale_items"

    sale_id = Column(Integer, ForeignKey("pos_sales.id", ondelete="CASCADE"), nullable=False)
    medicine_id = Column(Integer, ForeignKey("medicines.id"), nullable=False)
    batch_id = Column(Integer, ForeignKey("batches.id"), nullable=True)  # nullable pour compat legacy
    quantity = Column(Integer, nullable=False)
    unit_price = Column(Float, nullable=False)
    total_price = Column(Float, nullable=False)
    sale_type = Column(String(20), default="packaging", nullable=True)
    discount_percent = Column(Float, default=0.0, nullable=True)

    # Relationships
    sale = relationship("POSSale", back_populates="items")
    medicine = relationship("Medicine")
    batch = relationship("Batch", back_populates="pos_sale_items")

    def __repr__(self):
        return (
            f"<POSSaleItem(id={self.id}, sale_id={self.sale_id}, "
            f"medicine_id={self.medicine_id}, batch_id={self.batch_id}, "
            f"qty={self.quantity}, total={self.total_price} FBu)>"
        )

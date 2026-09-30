"""
Audit Log model for tracking sensitive operations (deletions, cancellations, etc.).
"""

from sqlalchemy import Column, Integer, String, DateTime, Text
from datetime import datetime
from app.database import Base
from app.models.base import BaseModelMixin


class DeletionLog(Base, BaseModelMixin):
    """
    Tracks deleted medicines, pricing entries, and cancelled invoices.
    
    Attributes:
        action: Type of action (e.g. DELETE_MEDICINE, DELETE_PRICING, CANCEL_SALE)
        entity_type: Type of item (medicine, pricing, sale)
        entity_id: ID of the item
        entity_name: Name or reference of the item (e.g. 'Paracetamol 500mg (MED-0012)')
        user_id: ID of the user who performed the deletion
        username: Username of the user who performed the deletion
        user_role: Role of the user ('admin', 'pharmacist', 'super_admin')
        details: Additional context (lot, initial stock, amount, etc.)
        created_at: Exact timestamp of the deletion
    """
    __tablename__ = "deletion_logs"

    action = Column(String(50), nullable=False, index=True)
    entity_type = Column(String(50), nullable=False, index=True)
    entity_id = Column(Integer, nullable=True)
    entity_name = Column(String(255), nullable=False)
    user_id = Column(Integer, nullable=True)
    username = Column(String(100), nullable=False, index=True)
    user_role = Column(String(50), nullable=True)
    details = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False, index=True)

    def to_dict(self):
        return {
            "id": self.id,
            "action": self.action,
            "entity_type": self.entity_type,
            "entity_id": self.entity_id,
            "entity_name": self.entity_name,
            "user_id": self.user_id,
            "username": self.username,
            "user_role": self.user_role,
            "details": self.details,
            "created_at": self.created_at.isoformat() if self.created_at else None,
        }

"""
Settings model for dynamic application configuration.
"""

from sqlalchemy import Column, String, Text, UniqueConstraint
from app.database import Base
from app.models.base import BaseModelMixin, PharmacyScopedMixin


class Settings(Base, BaseModelMixin, PharmacyScopedMixin):
    """
    Settings model for key-value configuration storage.
    
    Stores dynamic settings like:
    - pharmacy_name
    - pharmacy_logo (URL or base64)
    - bonus_percentage
    - currency (default: FBu)
    - bonus_eligible_products (JSON)
    - etc.
    
    Attributes:
        key: Setting key/identifier (unique)
        value: Setting value (JSON or text)
    """
    __tablename__ = "settings"
    __table_args__ = (
        UniqueConstraint("pharmacy_id", "key", name="uq_settings_pharmacy_key"),
    )
    
    key = Column(String(100), nullable=False)
    value = Column(Text, nullable=True)
    
    def __repr__(self):
        return f"<Settings(id={self.id}, key='{self.key}')>"

"""
Settings model for dynamic application configuration.
"""

from sqlalchemy import Column, String, Text
from app.database import Base
from app.models.base import BaseModelMixin


class Settings(Base, BaseModelMixin):
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
    
    key = Column(String(100), unique=True, nullable=False, index=True)
    value = Column(Text, nullable=True)
    
    def __repr__(self):
        return f"<Settings(id={self.id}, key='{self.key}')>"

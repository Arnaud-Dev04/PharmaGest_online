"""
User model for authentication and authorization.
"""

from sqlalchemy import Column, String, Boolean, Enum as SQLEnum
from app.database import Base
from app.models.base import BaseModelMixin
import enum


class UserRole(str, enum.Enum):
    """User role enumeration."""
    ADMIN = "admin"
    PHARMACIST = "pharmacist"
    SUPER_ADMIN = "super_admin"


class User(Base, BaseModelMixin):
    """
    User model for system authentication.
    
    Attributes:
        username: Unique username for login
        password_hash: Hashed password (bcrypt)
        role: User role (admin or pharmacist)
        is_active: Whether the user account is active
    """
    __tablename__ = "users"
    
    username = Column(String(50), unique=True, nullable=False, index=True)
    password_hash = Column(String(255), nullable=False)
    role = Column(String(20), nullable=False, default="pharmacist")
    is_active = Column(Boolean, default=True, nullable=False)
    must_change_password = Column(Boolean, default=False, nullable=False)
    
    def __repr__(self):
        return f"<User(id={self.id}, username='{self.username}', role='{self.role}')>"

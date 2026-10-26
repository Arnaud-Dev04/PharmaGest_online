"""
User model for authentication and authorization.
"""

from sqlalchemy import Boolean, Column, String, UniqueConstraint
from sqlalchemy.orm import relationship
from app.database import Base
from app.models.base import BaseModelMixin, PharmacyScopedMixin
import enum


class UserRole(str, enum.Enum):
    """User role enumeration."""
    ADMIN = "admin"
    PHARMACIST = "pharmacist"
    SUPER_ADMIN = "super_admin"
    PLATFORM_ADMIN = "platform_admin"


class User(Base, BaseModelMixin, PharmacyScopedMixin):
    """
    User model for system authentication.
    
    Attributes:
        username: Username for login (scoped per pharmacy)
        password_hash: Hashed password (bcrypt)
        role: User role (admin, pharmacist, super_admin, platform_admin)
        is_active: Whether the user account is active
    """
    __tablename__ = "users"
    __table_args__ = (
        UniqueConstraint("pharmacy_id", "username", name="uq_users_pharmacy_username"),
    )
    
    username = Column(String(50), nullable=False, index=True)
    password_hash = Column(String(255), nullable=False)
    role = Column(String(20), nullable=False, default="pharmacist")
    first_name = Column(String(60), nullable=True)
    last_name = Column(String(60), nullable=True)
    email = Column(String(120), nullable=True)
    phone = Column(String(30), nullable=True)
    is_active = Column(Boolean, default=True, nullable=False)
    must_change_password = Column(Boolean, default=False, nullable=False)
    pharmacy = relationship("Pharmacy", back_populates="users")
    
    def __repr__(self):
        return f"<User(id={self.id}, username='{self.username}', role='{self.role}')>"

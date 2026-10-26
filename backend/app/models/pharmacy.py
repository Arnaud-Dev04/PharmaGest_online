"""Pharmacy tenant model."""

from sqlalchemy import Boolean, Column, Date, Integer, String
from sqlalchemy.orm import relationship

from app.database import Base
from app.models.base import BaseModelMixin


class Pharmacy(Base, BaseModelMixin):
    """A pharmacy account managed by the platform."""

    __tablename__ = "pharmacies"

    name = Column(String(200), nullable=False)
    code = Column(String(50), unique=True, nullable=False, index=True)
    address = Column(String(500), nullable=True)
    phone = Column(String(50), nullable=True)
    email = Column(String(200), nullable=True)
    country = Column(String(100), nullable=True)
    city = Column(String(100), nullable=True)
    is_active = Column(Boolean, default=True, nullable=False)
    plan = Column(String(30), default="basic", nullable=False)
    max_users = Column(Integer, default=3, nullable=False)
    license_expires_at = Column(Date, nullable=True)
    license_is_trial = Column(Boolean, default=False, nullable=False)
    notes = Column(String(500), nullable=True)

    # Fiscalité & Liaison OBR EBMS Burundi
    nif = Column(String(50), nullable=True, index=True)
    rc_number = Column(String(100), nullable=True)
    tax_center = Column(String(50), nullable=True)
    obr_enabled = Column(Boolean, default=False, nullable=False)
    obr_environment = Column(String(20), default="sandbox", nullable=False)  # 'sandbox' ou 'production'
    obr_system_id = Column(String(100), nullable=True)
    obr_api_username = Column(String(100), nullable=True)
    obr_api_password = Column(String(255), nullable=True)

    users = relationship("User", back_populates="pharmacy")

    def __repr__(self):
        return f"<Pharmacy(id={self.id}, code='{self.code}', name='{self.name}')>"
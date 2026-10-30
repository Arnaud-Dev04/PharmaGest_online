"""Pharmacy tenant model."""

from sqlalchemy import Boolean, Column, Date, Integer, JSON, String
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
    status = Column(String(30), default="active", nullable=False)  # "active", "pending_approval", "suspended", "rejected"
    plan = Column(String(30), default="basic", nullable=False)
    deployment_env = Column(String(20), default="basic", nullable=False)
    """Instance Docker cible pour cette pharmacie: basic, pro, enterprise"""
    max_users = Column(Integer, default=3, nullable=False)
    license_expires_at = Column(Date, nullable=True)
    license_is_trial = Column(Boolean, default=False, nullable=False)
    notes = Column(String(500), nullable=True)

    # Feature access control (overrides plan defaults when set)
    enabled_features = Column(JSON, nullable=True, default=None)
    """List[str] of feature keys explicitly enabled for this pharmacy.
    When None, the plan-based defaults from PLAN_FEATURES are used."""

    # Fiscalité & Liaison OBR EBMS Burundi
    nif = Column(String(50), nullable=True, index=True)
    rc_number = Column(String(100), nullable=True)
    tax_center = Column(String(50), nullable=True)
    obr_enabled = Column(Boolean, default=False, nullable=False)
    obr_environment = Column(String(20), default="sandbox", nullable=False)  # 'sandbox' ou 'production'
    obr_system_id = Column(String(100), nullable=True)
    obr_api_username = Column(String(100), nullable=True)
    obr_api_password = Column(String(255), nullable=True)

    # Spécifications OBR EBMS V0.5
    tp_type = Column(String(5), default="2", nullable=False)  # "1" = physique, "2" = morale
    tp_legal_form = Column(String(50), default="SUARL", nullable=True)
    tp_activity_sector = Column(String(250), default="Commerce de détail de produits pharmaceutiques", nullable=True)
    tp_address_province = Column(String(50), default="BUJUMBURA MAIRIE", nullable=True)
    tp_address_commune = Column(String(50), default="MUKAZA", nullable=True)
    tp_address_quartier = Column(String(50), default="ROHERO", nullable=True)
    tp_address_avenue = Column(String(50), default="", nullable=True)
    tp_address_rue = Column(String(50), default="", nullable=True)
    tp_address_number = Column(String(20), default="", nullable=True)
    vat_taxpayer = Column(String(3), default="1", nullable=False)  # "1" = Assujetti TVA, "0" = Non assujetti
    ct_taxpayer = Column(String(3), default="0", nullable=False)   # "1" = Assujetti TC, "0" = Non
    tl_taxpayer = Column(String(3), default="0", nullable=False)   # "1" = Assujetti TL, "0" = Non

    users = relationship("User", back_populates="pharmacy")

    def __repr__(self):
        return f"<Pharmacy(id={self.id}, code='{self.code}', name='{self.name}')>"

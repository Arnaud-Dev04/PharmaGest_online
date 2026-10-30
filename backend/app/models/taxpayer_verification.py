"""
Model for caching and auditing OBR Taxpayer NIF (TIN) verifications.
"""

from datetime import datetime, timedelta
from sqlalchemy import Boolean, Column, DateTime, Integer, JSON, String, UniqueConstraint
from app.database import Base
from app.models.base import BaseModelMixin, PharmacyScopedMixin


class TaxpayerVerification(Base, BaseModelMixin, PharmacyScopedMixin):
    """
    Cache et historique de vérification des NIF clients auprès de l'OBR (EBMS checkTIN).
    Permet un fonctionnement fluide hors-ligne et évite de surcharger l'API de l'OBR.
    """

    __tablename__ = "taxpayer_verifications"
    __table_args__ = (
        UniqueConstraint("pharmacy_id", "tin", name="uq_taxpayer_pharmacy_tin"),
    )

    tin = Column(String(50), nullable=False, index=True)
    taxpayer_name = Column(String(255), nullable=True)
    taxpayer_address = Column(String(255), nullable=True)

    # Status: 'VALID', 'INVALID', 'UNREACHABLE', 'CACHED', 'FORMAT_ERROR'
    status = Column(String(30), nullable=False, default="UNREACHABLE")
    is_valid = Column(Boolean, default=False, nullable=False)

    # Réponse brute OBR pour audit
    raw_response = Column(JSON, nullable=True)

    # Horodatages
    verified_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    expires_at = Column(DateTime, nullable=True)

    def is_cache_fresh(self) -> bool:
        """Vérifie si la vérification est encore fraîche (moins de 30 jours par défaut)."""
        if not self.expires_at:
            return False
        return datetime.utcnow() < self.expires_at

    def __repr__(self):
        return f"<TaxpayerVerification(tin='{self.tin}', name='{self.taxpayer_name}', status='{self.status}')>"


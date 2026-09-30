"""
Stock Movement model — Journal de tous les mouvements de stock.
Chaque entrée ou sortie de stock est tracée ici.

Types de mouvements:
    - 'entree'        : Enregistrement / Réapprovisionnement
    - 'sortie_vente'  : Validation d'une vente POS
    - 'ajustement'    : Contrôle d'inventaire (écart constaté)
    - 'perte'         : Déclaration de perte / casse / périmé
"""

from sqlalchemy import Column, String, Integer, Float, ForeignKey, DateTime
from sqlalchemy.orm import relationship
from app.database import Base
from app.models.base import BaseModelMixin
from datetime import datetime


class StockMovement(Base, BaseModelMixin):
    """
    Journal des mouvements de stock.
    
    Chaque action sur le stock est tracée avec:
    - Le médicament concerné
    - Le lot (batch) concerné (optionnel)
    - Le type de mouvement (entree/sortie_vente/ajustement/perte)
    - La quantité (positive = entrée, négative = sortie)
    - Le motif et la référence (ex: N° de facture)
    """
    __tablename__ = "stock_movements"
    
    medicine_id = Column(Integer, ForeignKey("medicines.id"), nullable=False, index=True)
    batch_id = Column(Integer, ForeignKey("batches.id"), nullable=True)
    pricing_id = Column(Integer, ForeignKey("medicine_pricing.id"), nullable=True)
    
    type = Column(String(30), nullable=False, index=True)
    # Types: 'entree', 'sortie_vente', 'ajustement', 'perte'
    
    quantite = Column(Integer, nullable=False)  # En unités de base (comprimés)
    # Positif = entrée, Négatif = sortie
    
    motif = Column(String(200), nullable=True)
    # Ex: "Enregistrement lot LOT-001", "Vente POS", "Écart constaté"
    
    reference = Column(String(100), nullable=True, index=True)
    # Ex: "PRICING-42", "POS-2026-0001"
    
    date_mouvement = Column(DateTime, default=datetime.utcnow, nullable=False, index=True)
    
    # Relationships
    medicine = relationship("Medicine", back_populates="stock_movements")
    batch = relationship("Batch")
    
    def __repr__(self):
        return (
            f"<StockMovement(id={self.id}, type='{self.type}', "
            f"medicine_id={self.medicine_id}, qty={self.quantite}, "
            f"ref='{self.reference}')>"
        )

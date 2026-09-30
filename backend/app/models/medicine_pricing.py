"""
Medicine Pricing model — Isolated module for medication pricing management.
Stores complete reception and pricing data for medications.
"""

from sqlalchemy import Column, String, Integer, Float, Date, Boolean, ForeignKey
from sqlalchemy.orm import relationship
from app.database import Base
from app.models.base import BaseModelMixin


class MedicinePricing(Base, BaseModelMixin):
    """
    Medicine pricing entry model.
    
    Supports 3 pricing modes:
    - pct_marge: Automatic calculation by margin percentage
    - manuel: Manual price entry at each level
    - carton_fixe: Fixed carton price with automatic subdivision
    """
    __tablename__ = "medicine_pricing"

    # --- Lien vers Medicine (auto-rempli à la création) ---
    medicine_id = Column(Integer, ForeignKey("medicines.id"), nullable=True, index=True)

    # --- Informations médicament ---
    nom = Column(String(200), nullable=False, index=True)
    dci = Column(String(200), nullable=True)
    forme = Column(String(100), nullable=True)
    dosage = Column(String(100), nullable=True)
    lot = Column(String(100), nullable=False, index=True)
    fournisseur = Column(String(200), nullable=True)
    bon_livraison = Column(String(100), nullable=True)
    date_reception = Column(Date, nullable=True)
    date_peremption = Column(Date, nullable=True)

    # --- Conditionnement ---
    nb_cartons = Column(Integer, nullable=False, default=1)
    boites_par_carton = Column(Integer, nullable=False, default=1)
    plaquettes_par_boite = Column(Integer, nullable=False, default=1)
    comprimes_par_plaquette = Column(Integer, nullable=False, default=1)
    total_boites = Column(Integer, nullable=False, default=0)
    total_plaquettes = Column(Integer, nullable=False, default=0)
    total_comprimes = Column(Integer, nullable=False, default=0)

    # --- Prix ---
    prix_mode = Column(String(20), nullable=False, default="manuel")
    achat_carton = Column(Float, nullable=False, default=0.0)
    achat_boite = Column(Float, nullable=False, default=0.0)
    achat_plaquette = Column(Float, nullable=False, default=0.0)
    achat_comprime = Column(Float, nullable=False, default=0.0)
    vente_carton = Column(Float, nullable=False, default=0.0)
    vente_boite = Column(Float, nullable=False, default=0.0)
    vente_plaquette = Column(Float, nullable=False, default=0.0)
    vente_comprime = Column(Float, nullable=False, default=0.0)
    marge_pct = Column(Float, nullable=True, default=0.0)
    benefice_estime = Column(Float, nullable=False, default=0.0)

    # --- Stock & Alertes ---
    seuil_alerte = Column(Integer, nullable=False, default=10)
    seuil_niveau = Column(String(20), nullable=False, default="comprimes")
    emplacement = Column(String(100), nullable=True)
    alerte_peremption = Column(Boolean, nullable=False, default=True)
    alerte_jours = Column(Integer, nullable=True, default=30)
    ordonnance = Column(String(20), nullable=False, default="non")

    # Relationship
    medicine = relationship("Medicine", back_populates="pricing_entries")

    def __repr__(self):
        return f"<MedicinePricing(id={self.id}, nom='{self.nom}', lot='{self.lot}')>"

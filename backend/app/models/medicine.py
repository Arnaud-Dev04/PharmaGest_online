"""
Medicine-related models: Medicine, MedicineFamily, MedicineType.
"""

from sqlalchemy import Column, String, Integer, Float, Date, ForeignKey, Boolean
from sqlalchemy.orm import relationship
from app.database import Base
from app.models.base import BaseModelMixin


class MedicineFamily(Base, BaseModelMixin):
    """
    Dynamic medicine family/category.
    Examples: Antibiotiques, Antipaludiques, Antidouleurs, etc.
    """
    __tablename__ = "medicine_families"
    
    name = Column(String(100), unique=True, nullable=False, index=True)
    
    # Relationship
    medicines = relationship("Medicine", back_populates="family")
    
    def __repr__(self):
        return f"<MedicineFamily(id={self.id}, name='{self.name}')>"


class MedicineType(Base, BaseModelMixin):
    """
    Dynamic medicine type/packaging.
    Examples: Plaquette, Flacon, Ampoule, Sachet, etc.
    """
    __tablename__ = "medicine_types"
    
    name = Column(String(50), unique=True, nullable=False, index=True)
    
    # Relationship
    medicines = relationship("Medicine", back_populates="type")
    
    def __repr__(self):
        return f"<MedicineType(id={self.id}, name='{self.name}')>"


class Medicine(Base, BaseModelMixin):
    """
    Main medicine/product model.
    
    Represents a unique medication identity (e.g. "Paracétamol 500mg").
    One Medicine can have multiple Batches (lots) and MedicinePricing entries.
    
    Stock is always tracked in BASE UNITS (comprimés/unités).
    
    Attributes:
        code: Unique product code/SKU (auto-generated MED-NNNN)
        name: Medicine name (commercial)
        code_barres: EAN/UPC barcode (scanner)
        dci: Dénomination Commune Internationale
        forme_galenique: Forme galénique (Comprimé, Sirop, Injectable...)
        quantity: Current stock in BASE UNITS
        prix_*: Multi-level pricing (last registered prices)
    """
    __tablename__ = "medicines"
    
    # --- Identification ---
    code = Column(String(50), unique=True, nullable=False, index=True)
    name = Column(String(200), nullable=False, index=True)
    code_barres = Column(String(50), nullable=True, index=True)  # EAN/UPC barcode
    dci = Column(String(200), nullable=True)  # Dénomination Commune Internationale
    
    # --- Classification ---
    family_id = Column(Integer, ForeignKey("medicine_families.id"), nullable=True)
    type_id = Column(Integer, ForeignKey("medicine_types.id"), nullable=True)
    forme_galenique = Column(String(100), nullable=True)  # Comprimé, Sirop, Injectable...
    dosage_form = Column(String(50), nullable=True)  # Legacy — kept for compatibility
    packaging = Column(String(50), nullable=True)    # e.g. Boîte
    
    # --- Stock ---
    quantity = Column(Float, default=0.0, nullable=False)  # Stock total en UNITÉS DE BASE
    min_stock_alert = Column(Integer, default=10, nullable=False)
    expiry_alert_threshold = Column(Integer, default=30, nullable=False)
    is_active = Column(Boolean, default=True, nullable=False)
    
    # --- Traçabilité (dernière entrée) ---
    lot_fabricant = Column(String(100), nullable=True)  # Dernier lot enregistré
    date_entree_stock = Column(Date, nullable=True)  # Date dernière entrée
    expiry_date = Column(Date, nullable=True)  # Date péremption la plus proche
    fournisseur = Column(String(200), nullable=True)  # Dernier fournisseur
    
    # --- Conditionnement hiérarchique ---
    # Carton → contient N Boîtes → contient N Plaquettes → contient N Unités
    boxes_per_carton = Column(Integer, default=1, nullable=True)
    blisters_per_box = Column(Integer, default=1, nullable=True)  # Plaquettes par boîte
    units_per_blister = Column(Integer, default=1, nullable=True)  # Unités par plaquette
    carton_type = Column(String(50), default="Carton", nullable=True)
    units_per_packaging = Column(Integer, default=1, nullable=True)  # Legacy compat
    
    # --- Prix multi-niveaux (derniers prix enregistrés) ---
    price_buy = Column(Float, default=0.0, nullable=False)  # Legacy — prix achat boîte
    price_sell = Column(Float, default=0.0, nullable=False)  # Legacy — prix vente boîte
    prix_achat_unite = Column(Float, default=0.0)
    prix_vente_unite = Column(Float, default=0.0)
    prix_achat_boite = Column(Float, default=0.0)
    prix_vente_boite = Column(Float, default=0.0)
    prix_achat_carton = Column(Float, default=0.0)
    prix_vente_carton = Column(Float, default=0.0)
    prix_achat_plaquette = Column(Float, default=0.0)
    prix_vente_plaquette = Column(Float, default=0.0)
    
    # Relationships
    family = relationship("MedicineFamily", back_populates="medicines")
    type = relationship("MedicineType", back_populates="medicines")
    sale_items = relationship("SaleItem", back_populates="medicine")
    restock_items = relationship("RestockItem", back_populates="medicine")
    batches = relationship("Batch", back_populates="medicine", lazy="dynamic")
    stock_movements = relationship("StockMovement", back_populates="medicine")
    pricing_entries = relationship("MedicinePricing", back_populates="medicine")
    
    def __repr__(self):
        return f"<Medicine(id={self.id}, code='{self.code}', name='{self.name}', qty={self.quantity})>"

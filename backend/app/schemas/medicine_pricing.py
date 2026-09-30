"""
Medicine Pricing schemas — Pydantic validation for the pricing module.
"""

from pydantic import BaseModel, Field, model_validator
from datetime import date, datetime
from typing import Optional, List
from enum import Enum


class PricingMode(str, Enum):
    PCT_MARGE = "pct_marge"
    MANUEL = "manuel"
    CARTON_FIXE = "carton_fixe"


class OrdonnanceType(str, Enum):
    NON = "non"
    OUI = "oui"
    LISTE1 = "liste1"
    LISTE2 = "liste2"
    STUP = "stup"


class MedicinePricingCreate(BaseModel):
    """Schema for creating a medicine pricing entry."""
    medicine_id: Optional[int] = Field(default=None, description="ID du médicament lié si existant")
    nom: str = Field(..., min_length=1, max_length=200, description="Nom du médicament")
    dci: Optional[str] = Field(None, max_length=200, description="DCI")
    forme: Optional[str] = Field(None, max_length=100, description="Forme galénique")
    dosage: Optional[str] = Field(None, max_length=100, description="Dosage")
    lot: str = Field(..., min_length=1, max_length=100, description="Numéro de lot")
    fournisseur: Optional[str] = Field(None, max_length=200)
    bon_livraison: Optional[str] = Field(None, max_length=100)
    date_reception: Optional[date] = None
    date_peremption: Optional[date] = None

    # Conditionnement
    nb_cartons: int = Field(..., gt=0, description="Nombre de cartons reçus")
    boites_par_carton: int = Field(..., gt=0, description="Boîtes par carton")
    plaquettes_par_boite: int = Field(..., gt=0, description="Plaquettes par boîte")
    comprimes_par_plaquette: int = Field(..., gt=0, description="Comprimés par plaquette")

    # Prix
    prix_mode: PricingMode = Field(default=PricingMode.MANUEL)
    achat_carton: float = Field(..., gt=0, description="Prix d'achat du carton (FBu)")
    achat_boite: float = Field(default=0.0, ge=0, description="Prix d'achat par boîte")
    achat_plaquette: float = Field(default=0.0, ge=0, description="Prix d'achat par plaquette")
    achat_comprime: float = Field(default=0.0, ge=0, description="Prix d'achat par unité")
    vente_carton: float = Field(default=0.0, ge=0)
    vente_boite: float = Field(default=0.0, ge=0)
    vente_plaquette: float = Field(default=0.0, ge=0)
    vente_comprime: float = Field(default=0.0, ge=0)
    marge_pct: Optional[float] = Field(default=None)

    # Stock & Alertes
    seuil_alerte: int = Field(default=10, ge=0)
    seuil_niveau: str = Field(default="comprimes", description="Niveau du seuil: comprimes, plaquettes, boites, cartons")
    emplacement: Optional[str] = Field(None, max_length=100)
    alerte_peremption: bool = Field(default=True)
    alerte_jours: Optional[int] = Field(default=30, ge=1, description="Nombre de jours avant expiration pour l'alerte")
    ordonnance: OrdonnanceType = Field(default=OrdonnanceType.NON)

    @model_validator(mode='after')
    def validate_dates(self):
        if self.date_reception and self.date_peremption:
            if self.date_peremption <= self.date_reception:
                raise ValueError("La date de péremption doit être postérieure à la date de réception")
        return self


    @model_validator(mode='after')
    def validate_pricing_mode(self):
        if self.prix_mode == PricingMode.PCT_MARGE:
            if self.marge_pct is None:
                raise ValueError("Le pourcentage de marge est requis pour le mode 'Pourcentage de marge'")
        elif self.prix_mode == PricingMode.MANUEL:
            if self.vente_carton <= 0:
                raise ValueError("Le prix de vente du carton est requis pour le mode 'Manuel'")
        elif self.prix_mode == PricingMode.CARTON_FIXE:
            if self.vente_carton <= 0:
                raise ValueError("Le prix de vente du carton est requis pour le mode 'Carton fixé'")
        return self

    model_config = {
        "json_schema_extra": {
            "examples": [
                {
                    "nom": "Amoxicilline 500mg",
                    "lot": "LOT-2026-001",
                    "nb_cartons": 10,
                    "boites_par_carton": 20,
                    "plaquettes_par_boite": 3,
                    "comprimes_par_plaquette": 8,
                    "prix_mode": "pct_marge",
                    "achat_carton": 120000,
                    "marge_pct": 25,
                }
            ]
        }
    }


class MedicinePricingUpdate(BaseModel):
    """Schema for updating a pricing entry (all fields optional)."""
    nom: Optional[str] = Field(None, min_length=1, max_length=200)
    dci: Optional[str] = None
    forme: Optional[str] = None
    dosage: Optional[str] = None
    lot: Optional[str] = Field(None, min_length=1, max_length=100)
    fournisseur: Optional[str] = None
    bon_livraison: Optional[str] = None
    date_reception: Optional[date] = None
    date_peremption: Optional[date] = None
    nb_cartons: Optional[int] = Field(None, gt=0)
    boites_par_carton: Optional[int] = Field(None, gt=0)
    plaquettes_par_boite: Optional[int] = Field(None, gt=0)
    comprimes_par_plaquette: Optional[int] = Field(None, gt=0)
    prix_mode: Optional[PricingMode] = None
    achat_carton: Optional[float] = Field(None, gt=0)
    achat_boite: Optional[float] = Field(None, ge=0)
    achat_plaquette: Optional[float] = Field(None, ge=0)
    achat_comprime: Optional[float] = Field(None, ge=0)
    vente_carton: Optional[float] = Field(None, ge=0)
    vente_boite: Optional[float] = Field(None, ge=0)
    vente_plaquette: Optional[float] = Field(None, ge=0)
    vente_comprime: Optional[float] = Field(None, ge=0)
    marge_pct: Optional[float] = None
    seuil_alerte: Optional[int] = Field(None, ge=0)
    seuil_niveau: Optional[str] = None
    emplacement: Optional[str] = None
    alerte_peremption: Optional[bool] = None
    alerte_jours: Optional[int] = Field(None, ge=1)
    ordonnance: Optional[OrdonnanceType] = None


class MedicinePricingResponse(BaseModel):
    """Schema for pricing entry in responses."""
    id: int
    medicine_id: Optional[int] = None
    nom: str
    dci: Optional[str]
    forme: Optional[str]
    dosage: Optional[str]
    lot: str
    fournisseur: Optional[str]
    bon_livraison: Optional[str]
    date_reception: Optional[date]
    date_peremption: Optional[date]

    nb_cartons: int
    boites_par_carton: int
    plaquettes_par_boite: int
    comprimes_par_plaquette: int
    total_boites: int
    total_plaquettes: int
    total_comprimes: int

    prix_mode: str
    achat_carton: float
    achat_boite: float = 0.0
    achat_plaquette: float = 0.0
    achat_comprime: float = 0.0
    vente_carton: float
    vente_boite: float
    vente_plaquette: float
    vente_comprime: float
    marge_pct: Optional[float]
    benefice_estime: float

    seuil_alerte: int
    seuil_niveau: str = "comprimes"
    emplacement: Optional[str]
    alerte_peremption: bool
    alerte_jours: Optional[int] = 30
    ordonnance: str

    created_at: datetime
    updated_at: datetime

    # Calculated alert fields
    expire_bientot: bool = False
    stock_faible: bool = False
    en_rupture: bool = False
    stock_actuel: float = 0.0

    model_config = {"from_attributes": True}

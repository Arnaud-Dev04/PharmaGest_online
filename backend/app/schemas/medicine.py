"""
Medicine-related schemas: Medicine, MedicineFamily, MedicineType.
"""

from pydantic import BaseModel, Field
from datetime import date, datetime
from typing import Optional, List


# ============================================================================
# MEDICINE FAMILY SCHEMAS
# ============================================================================

class MedicineFamilyCreate(BaseModel):
    """Schema for creating a medicine family."""
    name: str = Field(..., min_length=1, max_length=100, description="Family name (unique)")
    
    model_config = {
        "json_schema_extra": {
            "examples": [
                {"name": "Antibiotiques"},
                {"name": "Antipaludiques"},
                {"name": "Antidouleurs"}
            ]
        }
    }


class MedicineFamilyUpdate(BaseModel):
    """Schema for updating a medicine family."""
    name: str = Field(..., min_length=1, max_length=100, description="New family name")


class MedicineFamilyResponse(BaseModel):
    """Schema for medicine family in responses."""
    id: int
    name: str
    created_at: datetime
    updated_at: datetime
    
    model_config = {"from_attributes": True}


# ============================================================================
# MEDICINE TYPE SCHEMAS
# ============================================================================

class MedicineTypeCreate(BaseModel):
    """Schema for creating a medicine type."""
    name: str = Field(..., min_length=1, max_length=50, description="Type name (unique)")
    
    model_config = {
        "json_schema_extra": {
            "examples": [
                {"name": "Plaquette"},
                {"name": "Flacon"},
                {"name": "Ampoule"},
                {"name": "Sachet"}
            ]
        }
    }


class MedicineTypeUpdate(BaseModel):
    """Schema for updating a medicine type."""
    name: str = Field(..., min_length=1, max_length=50, description="New type name")


class MedicineTypeResponse(BaseModel):
    """Schema for medicine type in responses."""
    id: int
    name: str
    created_at: datetime
    updated_at: datetime
    
    model_config = {"from_attributes": True}


# ============================================================================
# MEDICINE SCHEMAS
# ============================================================================

class MedicineCreate(BaseModel):
    """Schema for creating a medicine."""
    code: Optional[str] = Field(None, min_length=1, max_length=50, description="Product code (auto-generated if empty)")
    name: str = Field(..., min_length=1, max_length=200, description="Medicine name")
    family_id: Optional[int] = Field(None, description="Medicine family ID")
    type_id: Optional[int] = Field(None, description="Medicine type ID")
    quantity: float = Field(default=0.0, ge=0, description="Current stock quantity")
    price_buy: float = Field(..., gt=0, description="Purchase price (FBu)")
    price_sell: float = Field(..., gt=0, description="Selling price (FBu)")
    expiry_date: Optional[date] = Field(None, description="Expiration date")
    min_stock_alert: int = Field(default=10, ge=0, description="Minimum stock threshold")
    expiry_alert_threshold: int = Field(default=30, ge=1, description="Days before expiry to alert")
    
    # New fields
    dosage_form: Optional[str] = Field(None, description="Dosage form (e.g. Comprimé)")
    packaging: Optional[str] = Field(None, description="Packaging type (e.g. Boîte)")
    carton_type: Optional[str] = Field("Carton", description="Carton type name")
    boxes_per_carton: int = Field(default=1, ge=1, description="Number of boxes per carton")
    blisters_per_box: int = Field(default=1, ge=1, description="Number of blisters/plaquettes per box")
    units_per_blister: int = Field(default=1, ge=1, description="Number of units per blister")
    units_per_packaging: Optional[int] = Field(default=1, ge=1, description="Total units per box (Auto-calculated if not provided)")
    
    model_config = {
        "json_schema_extra": {
            "examples": [
                {
                    "code": "MED-001",
                    "name": "Paracétamol 500mg",
                    "quantity": 100,
                    "price_buy": 500.0,
                    "price_sell": 800.0,
                    "dosage_form": "Comprimé",
                    "packaging": "Plaquette",
                    "units_per_packaging": 10
                }
            ]
        }
    }


class MedicineUpdate(BaseModel):
    """Schema for updating a medicine (all fields optional)."""
    code: Optional[str] = Field(None, min_length=1, max_length=50)
    name: Optional[str] = Field(None, min_length=1, max_length=200)
    family_id: Optional[int] = None
    type_id: Optional[int] = None
    quantity: Optional[float] = Field(None, ge=0)
    price_buy: Optional[float] = Field(None, gt=0)
    price_sell: Optional[float] = Field(None, gt=0)
    expiry_date: Optional[date] = None
    min_stock_alert: Optional[int] = Field(None, ge=0)
    expiry_alert_threshold: Optional[int] = Field(None, ge=1)
    dosage_form: Optional[str] = None
    packaging: Optional[str] = None
    blisters_per_box: Optional[int] = Field(None, ge=1)
    units_per_blister: Optional[int] = Field(None, ge=1)
    units_per_packaging: Optional[int] = Field(None, ge=1)
    carton_type: Optional[str] = None
    boxes_per_carton: Optional[int] = Field(None, ge=1)


class MedicineResponse(BaseModel):
    """Schema for medicine in responses."""
    id: int
    code: str
    name: str
    family_id: Optional[int]
    type_id: Optional[int]
    quantity: float
    price_buy: float
    price_sell: float
    expiry_date: Optional[date]
    min_stock_alert: int
    expiry_alert_threshold: int
    dosage_form: Optional[str]
    packaging: Optional[str]
    carton_type: Optional[str]
    boxes_per_carton: int
    blisters_per_box: int
    units_per_blister: int
    units_per_packaging: int
    
    # Nouveaux champs enrichis
    code_barres: Optional[str] = None
    dci: Optional[str] = None
    forme_galenique: Optional[str] = None
    fournisseur: Optional[str] = None
    
    # Prix multi-niveaux
    prix_achat_unite: float = 0.0
    prix_vente_unite: float = 0.0
    prix_achat_plaquette: float = 0.0
    prix_vente_plaquette: float = 0.0
    prix_achat_boite: float = 0.0
    prix_vente_boite: float = 0.0
    prix_achat_carton: float = 0.0
    prix_vente_carton: float = 0.0
    
    created_at: datetime
    updated_at: datetime
    
    # Related objects
    family: Optional[MedicineFamilyResponse] = None
    type: Optional[MedicineTypeResponse] = None
    
    # Calculated fields
    is_low_stock: bool = False
    is_expired: bool = False
    margin: float = 0.0
    
    model_config = {"from_attributes": True}


class MedicineFilter(BaseModel):
    """Schema for filtering medicines."""
    search: Optional[str] = Field(None, description="Search by name or code")
    family_id: Optional[int] = Field(None, description="Filter by family ID")
    type_id: Optional[int] = Field(None, description="Filter by type ID")
    is_low_stock: Optional[bool] = Field(None, description="Filter low stock items")
    is_expired: Optional[bool] = Field(None, description="Filter expired items")
    
    model_config = {
        "json_schema_extra": {
            "examples": [
                {
                    "search": "paracetamol",
                    "family_id": 1,
                    "is_low_stock": True
                }
            ]
        }
    }


class StockAlertsResponse(BaseModel):
    """Schema for stock alerts response."""
    low_stock: List[MedicineResponse] = Field(default_factory=list, description="Medicines with low stock")
    expired: List[MedicineResponse] = Field(default_factory=list, description="Expired medicines")
    total_alerts: int = Field(..., description="Total number of alerts")
    
    model_config = {
        "json_schema_extra": {
            "examples": [
                {
                    "low_stock": [],
                    "expired": [],
                    "total_alerts": 0
                }
            ]
        }
    }

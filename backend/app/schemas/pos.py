"""
POS schemas — Pydantic models for POS API endpoints.
Handles product search, FEFO allocation, and checkout.
"""

from pydantic import BaseModel, Field
from datetime import datetime, date
from typing import List, Optional


# ============================================================================
# BATCH SCHEMAS
# ============================================================================

class BatchInfo(BaseModel):
    """Batch information returned in product search results."""
    id: int
    batch_number: str
    expiration_date: date
    quantity: float
    
    model_config = {"from_attributes": True}


class BatchAllocation(BaseModel):
    """
    Represents a quantity allocation from a specific batch.
    Used in FEFO allocation responses and checkout requests.
    """
    batch_id: int
    batch_number: str = ""
    expiration_date: Optional[date] = None
    quantity: int = Field(..., gt=0, description="Quantity allocated from this batch")


# ============================================================================
# PRODUCT SEARCH
# ============================================================================

class ProductSearchResult(BaseModel):
    """Product search result enriched with batch/lot information and multi-level pricing."""
    id: int
    name: str
    code: str
    price_sell: float
    available_quantity: float = Field(description="Total available across all active batches")
    batches: List[BatchInfo] = Field(default_factory=list, description="Available batches sorted FEFO")
    # Conditioning
    units_per_packaging: int = 1
    units_per_blister: int = 1
    blisters_per_box: int = 1
    boxes_per_carton: int = 1
    # Multi-level pricing (from latest MedicinePricing)
    prix_vente_unite: float = 0.0
    prix_vente_plaquette: float = 0.0
    prix_vente_boite: float = 0.0
    prix_vente_carton: float = 0.0
    prix_achat_unite: float = 0.0
    prix_achat_plaquette: float = 0.0
    prix_achat_boite: float = 0.0
    prix_achat_carton: float = 0.0
    comprimes_par_plaquette: int = 1
    plaquettes_par_boite: int = 1
    # Medicine details (forme, DCI, dosage)
    dosage_form: Optional[str] = None
    dci: Optional[str] = None
    forme_galenique: Optional[str] = None
    
    model_config = {"from_attributes": True}


# ============================================================================
# CART (FEFO ALLOCATION)
# ============================================================================

class CartAddRequest(BaseModel):
    """Request to calculate FEFO allocation for a product quantity."""
    medicine_id: int = Field(..., gt=0, description="Medicine ID")
    quantity: int = Field(..., gt=0, description="Desired quantity at the chosen level")
    level: str = Field(default="unite", description="Level: unite, plaquette, boite, carton")
    
    model_config = {
        "json_schema_extra": {
            "examples": [
                {"medicine_id": 1, "quantity": 10, "level": "unite"}
            ]
        }
    }


class CartAddResponse(BaseModel):
    """Response with FEFO-allocated batches for the requested quantity."""
    medicine_id: int
    medicine_name: str
    medicine_code: str
    quantity: int
    level: str = "unite"
    base_units: int = 0
    unit_price: float
    total_price: float
    allocations: List[BatchAllocation] = Field(
        description="Batch allocations sorted by expiration (FEFO)"
    )


# ============================================================================
# CHECKOUT
# ============================================================================

class CheckoutItem(BaseModel):
    """A single item in the checkout request, with batch allocations."""
    medicine_id: int = Field(..., gt=0)
    allocations: List[BatchAllocation] = Field(
        ..., min_length=1, description="Batch allocations from FEFO"
    )
    quantity: int = Field(..., gt=0, description="Displayed quantity at the selected level")
    level: str = Field(default="unite", description="Level: unite, plaquette, boite, carton")
    base_units: Optional[int] = Field(
        default=None,
        gt=0,
        description="Total base units deducted from stock. If omitted, backend computes it from quantity + level."
    )
    unit_price: float = Field(..., gt=0, description="Unit price for the selected level at time of sale")
    discount_percent: float = Field(default=0.0, ge=0, le=100, description="Remise appliquée sur cet article (0-100%)")


class POSCheckoutRequest(BaseModel):
    """
    Final checkout request — creates a POS sale transaction.
    
    The frontend sends the complete cart with pre-allocated batches.
    The backend validates allocations, deducts stock, and creates the sale.
    """
    items: List[CheckoutItem] = Field(..., min_length=1, description="Cart items with allocations")
    payment_method: str = Field(default="cash", description="Payment: 'cash' or 'insurance'")
    customer_id: Optional[int] = Field(None, description="Optional customer ID")
    customer_name: Optional[str] = Field(None, description="Optional customer name for invoice")
    
    # Insurance fields
    insurance_provider: Optional[str] = None
    insurance_card_id: Optional[str] = None
    coverage_percent: Optional[float] = Field(default=0.0, ge=0, le=100)
    
    model_config = {
        "json_schema_extra": {
            "examples": [
                {
                    "items": [
                        {
                            "medicine_id": 1,
                            "allocations": [
                                {"batch_id": 1, "quantity": 5},
                                {"batch_id": 2, "quantity": 3}
                            ],
                            "quantity": 8,
                            "unit_price": 500.0
                        }
                    ],
                    "payment_method": "cash"
                }
            ]
        }
    }


# ============================================================================
# SALE RESPONSES
# ============================================================================

class POSSaleItemResponse(BaseModel):
    """POS sale item in response — includes batch details."""
    id: int
    medicine_id: int
    medicine_name: str = ""
    medicine_code: str = ""
    batch_id: int
    batch_number: str = ""
    expiration_date: Optional[date] = None
    quantity: int
    unit_price: float
    total_price: float
    discount_percent: float = 0.0  # % remise appliquée sur cet article
    
    model_config = {"from_attributes": True}


class POSSaleResponse(BaseModel):
    """Complete POS sale response."""
    id: int
    uuid: str
    code: str
    total_amount: float
    payment_method: str
    date: datetime
    user_id: int
    user_name: str = ""
    status: str = "completed"
    customer_id: Optional[int] = None
    customer_name: Optional[str] = None
    items: List[POSSaleItemResponse] = []
    
    # Insurance
    insurance_provider: Optional[str] = None
    insurance_card_id: Optional[str] = None
    coverage_percent: Optional[float] = 0.0

    # Bonus client
    bonus_earned: float = 0.0  # Points bonus gagnés lors de cette vente
    
    model_config = {"from_attributes": True}


# ============================================================================
# BATCH MANAGEMENT (Admin)
# ============================================================================

class BatchCreate(BaseModel):
    """Schema for creating a new batch/lot."""
    medicine_id: int = Field(..., gt=0)
    batch_number: str = Field(..., min_length=1, max_length=100)
    expiration_date: date
    quantity: float = Field(..., gt=0)
    purchase_price: Optional[float] = Field(None, gt=0)
    
    model_config = {
        "json_schema_extra": {
            "examples": [
                {
                    "medicine_id": 1,
                    "batch_number": "LOT-2026-001",
                    "expiration_date": "2027-06-15",
                    "quantity": 100,
                    "purchase_price": 300.0
                }
            ]
        }
    }


class BatchResponse(BaseModel):
    """Batch in responses."""
    id: int
    medicine_id: int
    medicine_name: str = ""
    batch_number: str
    expiration_date: date
    quantity: float
    purchase_price: Optional[float] = None
    is_active: bool = True
    created_at: datetime
    updated_at: datetime
    
    model_config = {"from_attributes": True}

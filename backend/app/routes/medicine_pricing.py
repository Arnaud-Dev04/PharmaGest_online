"""
Medicine Pricing routes — API endpoints for the pricing module.
"""

from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session
from typing import Optional
from datetime import date, timedelta

from app.database import get_local_db
from app.models.user import User
from app.auth.dependencies import get_current_active_user, get_admin_user, get_pharmacist_user
from app.schemas.medicine_pricing import (
    MedicinePricingCreate,
    MedicinePricingUpdate,
    MedicinePricingResponse,
)
from app.schemas.common import PaginatedResponse
from app.services import medicine_pricing_service

router = APIRouter()


def enrich_pricing_response(entry) -> MedicinePricingResponse:
    """Add calculated alert fields to pricing response."""
    response = MedicinePricingResponse.model_validate(entry)

    # Check expiry alert according to user-configured alert delay
    if entry.date_peremption and entry.alerte_peremption and entry.alerte_jours:
        alert_cutoff = date.today() + timedelta(days=entry.alerte_jours)
        response.expire_bientot = (
            entry.date_peremption <= alert_cutoff
            and entry.date_peremption > date.today()
        )

    # Calculate current stock and rupture state
    stock_qty = 0.0
    if entry.medicine:
        stock_qty = float(entry.medicine.quantity or 0.0)
    else:
        stock_qty = float(entry.total_comprimes or 0.0)

    response.stock_actuel = stock_qty
    response.en_rupture = (stock_qty <= 0)
    response.stock_faible = (stock_qty > 0 and stock_qty <= (entry.seuil_alerte or 10))

    return response


import time as _time_module

_pricing_entries_cache: dict = {}
_PRICING_CACHE_TTL = 15  # secondes

_pricing_alerts_cache: dict = {}
_PRICING_ALERTS_CACHE_TTL = 60  # secondes


def invalidate_pricing_cache():
    global _pricing_entries_cache, _pricing_alerts_cache
    _pricing_entries_cache.clear()
    _pricing_alerts_cache.clear()


@router.get(
    "/entries",
    response_model=PaginatedResponse[MedicinePricingResponse],
    summary="List pricing entries with pagination and search",
)
async def list_pricing_entries(
    page: int = Query(1, ge=1, description="Page number"),
    page_size: int = Query(50, ge=1, le=500, description="Items per page"),
    search: Optional[str] = Query(None, description="Search by name, lot, supplier, or DCI"),
    out_of_stock_only: Optional[bool] = Query(False, description="Filter only out-of-stock medicines"),
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_local_db),
):
    """
    Get paginated pricing entries.
    Mis en cache pendant 15s hors recherche pour rendre la navigation entre onglets instantanée.

    **Accessible to**: All authenticated users
    """
    cache_key = f"{page}_{page_size}_{out_of_stock_only}"
    now = _time_module.time()

    if not search and cache_key in _pricing_entries_cache and (now - _pricing_entries_cache[cache_key]["ts"]) < _PRICING_CACHE_TTL:
        return _pricing_entries_cache[cache_key]["data"]

    entries, total = medicine_pricing_service.get_pricings(
        db, page, page_size, search, out_of_stock_only=bool(out_of_stock_only)
    )
    enriched = [enrich_pricing_response(e) for e in entries]
    res = PaginatedResponse.create(
        items=enriched, total=total, page=page, page_size=page_size
    )
    if not search:
        _pricing_entries_cache[cache_key] = {"data": res, "ts": now}
    return res


@router.get(
    "/entries/{entry_id}",
    response_model=MedicinePricingResponse,
    summary="Get a specific pricing entry",
)
async def get_pricing_entry(
    entry_id: int,
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_local_db),
):
    """
    Get a single pricing entry by ID.

    **Accessible to**: All authenticated users
    """
    entry = medicine_pricing_service.get_pricing_by_id(db, entry_id)
    if not entry:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Entrée de prix avec ID {entry_id} introuvable",
        )
    return enrich_pricing_response(entry)


@router.post(
    "/entries",
    response_model=MedicinePricingResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create a new pricing entry (Admin & Pharmacist)",
)
async def create_pricing_entry(
    data: MedicinePricingCreate,
    current_user: User = Depends(get_pharmacist_user),
    db: Session = Depends(get_local_db),
):
    """
    Create a new medicine pricing entry.

    **Accessible to**: Admin and Pharmacist
    """
    entry = medicine_pricing_service.create_pricing(db, data)
    invalidate_pricing_cache()
    return enrich_pricing_response(entry)


@router.put(
    "/entries/{entry_id}",
    response_model=MedicinePricingResponse,
    summary="Update a pricing entry (Admin & Pharmacist)",
)
async def update_pricing_entry(
    entry_id: int,
    data: MedicinePricingUpdate,
    current_user: User = Depends(get_pharmacist_user),
    db: Session = Depends(get_local_db),
):
    """
    Update a pricing entry.

    **Accessible to**: Admin and Pharmacist
    """
    existing = medicine_pricing_service.get_pricing_by_id(db, entry_id)
    if not existing:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Entrée de prix avec ID {entry_id} introuvable",
        )

    # Capture old values
    old_nom = existing.nom
    old_lot = existing.lot
    old_stock = existing.total_comprimes
    old_vc = existing.vente_comprime
    old_vb = existing.vente_boite
    old_perp = str(existing.date_peremption) if existing.date_peremption else "N/A"
    linked_med_id = existing.medicine_id

    entry = medicine_pricing_service.update_pricing(db, entry_id, data)
    if not entry:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Entrée de prix avec ID {entry_id} introuvable",
        )

    # Compute diff
    changes = []
    if data.lot and data.lot != old_lot:
        changes.append(f"Lot: '{old_lot}' -> '{entry.lot}'")
    if entry.total_comprimes != old_stock:
        changes.append(f"Stock: {old_stock} -> {entry.total_comprimes} unités")
    if data.vente_comprime is not None and data.vente_comprime != old_vc:
        changes.append(f"Prix comprimé: {old_vc} -> {entry.vente_comprime} FBu")
    if data.vente_boite is not None and data.vente_boite != old_vb:
        changes.append(f"Prix boîte: {old_vb} -> {entry.vente_boite} FBu")
    new_perp = str(entry.date_peremption) if entry.date_peremption else "N/A"
    if data.date_peremption and new_perp != old_perp:
        changes.append(f"Péremption: {old_perp} -> {new_perp}")

    details_str = " | ".join(changes) if changes else "Mise à jour des prix/stock"

    from app.services import audit_service
    audit_service.log_deletion(
        db=db,
        action="UPDATE_PRICING",
        entity_type="medicine",
        entity_id=linked_med_id or entry_id,
        entity_name=f"{entry.nom} (Lot: {entry.lot})",
        user=current_user,
        details=details_str,
    )

    invalidate_pricing_cache()
    return enrich_pricing_response(entry)


@router.delete(
    "/entries/{entry_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Delete a pricing entry (Admin only)",
)
async def delete_pricing_entry(
    entry_id: int,
    current_user: User = Depends(get_pharmacist_user),
    db: Session = Depends(get_local_db),
):
    """
    Delete a pricing entry.

    **Accessible to**: Admin only
    """
    entry = medicine_pricing_service.get_pricing_by_id(db, entry_id)
    if not entry:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Entrée de prix avec ID {entry_id} introuvable",
        )

    entry_nom = entry.nom
    entry_lot = entry.lot
    entry_stock = entry.total_comprimes or 0

    success = medicine_pricing_service.delete_pricing(db, entry_id)
    if not success:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Entrée de prix avec ID {entry_id} introuvable",
        )

    from app.services import audit_service
    audit_service.log_deletion(
        db=db,
        action="DELETE_PRICING",
        entity_type="pricing",
        entity_id=entry_id,
        entity_name=f"{entry_nom} (Lot: {entry_lot})",
        user=current_user,
        details=f"Suppression lot {entry_lot}, stock: {entry_stock} unités",
    )

    invalidate_pricing_cache()


@router.get(
    "/alerts",
    summary="Get pricing alerts (expiring soon + low stock)",
)
async def get_pricing_alerts(
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_local_db),
):
    """
    Get pricing entries with alerts.
    Résultat mis en cache 60s pour éviter de bombarder Aiven à chaque rebuild du header.

    **Accessible to**: All authenticated users
    """
    global _pricing_alerts_cache
    now = _time_module.time()

    if _pricing_alerts_cache.get("ts") and (now - _pricing_alerts_cache["ts"]) < _PRICING_ALERTS_CACHE_TTL:
        return _pricing_alerts_cache["data"]

    alerts = medicine_pricing_service.get_pricing_alerts(db)
    result = {
        "expiring_soon": [enrich_pricing_response(e).model_dump() for e in alerts["expiring_soon"]],
        "low_stock":     [enrich_pricing_response(e).model_dump() for e in alerts["low_stock"]],
        "out_of_stock":  [enrich_pricing_response(e).model_dump() for e in alerts["out_of_stock"]],
        "total_alerts":  alerts["total_alerts"],
    }
    _pricing_alerts_cache = {"data": result, "ts": now}
    return result


@router.get(
    "/autocomplete",
    summary="Autocomplete medication names",
)
async def autocomplete_names(
    q: str = Query(..., min_length=1, description="Search query"),
    limit: int = Query(10, ge=1, le=50),
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_local_db),
):
    """
    Returns distinct medication names matching the query for form autocomplete.

    **Accessible to**: All authenticated users
    """
    names = medicine_pricing_service.get_autocomplete_names(db, q, limit)
    return {"results": names}


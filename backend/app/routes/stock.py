"""
Stock routes - Medicine CRUD and stock alerts.
"""

from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session
from typing import Optional, List
from pydantic import BaseModel
from datetime import date

from app.database import get_local_db
from app.models.user import User
from app.auth.dependencies import get_current_active_user, get_admin_user, get_pharmacist_user
from app.schemas.medicine import (
    MedicineCreate, MedicineUpdate, MedicineResponse,
    StockAlertsResponse
)
from app.schemas.common import PaginationParams, PaginatedResponse
from app.services import medicine_service

# Create router
router = APIRouter()


# Helper function to enrich medicine response
def enrich_medicine_response(medicine, batch_count: Optional[int] = None) -> dict:
    """Add calculated fields to medicine response."""
    response = MedicineResponse.model_validate(medicine)
    
    # Calculate fields
    response.is_low_stock = medicine.quantity <= medicine.min_stock_alert
    response.is_expired = (
        medicine.expiry_date is not None and 
        medicine.expiry_date <= date.today()
    )
    response.margin = medicine.price_sell - medicine.price_buy if medicine.price_sell and medicine.price_buy else 0.0
    
    # Convert to dict and add batch count
    result = response.model_dump() if hasattr(response, 'model_dump') else response.dict()
    
    if batch_count is not None:
        result['batch_count'] = batch_count
    else:
        result['batch_count'] = 0
        try:
            batches_val = getattr(medicine, 'batches', None)
            if batches_val is not None and isinstance(batches_val, list):
                result['batch_count'] = len([b for b in batches_val if b.is_active and b.quantity > 0])
        except Exception:
            pass
    
    return result


@router.get(
    "/medicines",
    response_model=PaginatedResponse[MedicineResponse],
    summary="List medicines with pagination and filters"
)
async def list_medicines(
    page: int = Query(1, ge=1, description="Page number"),
    page_size: int = Query(50, ge=1, le=100, description="Items per page"),
    search: Optional[str] = Query(None, description="Search by name or code"),
    family_id: Optional[int] = Query(None, description="Filter by family ID"),
    type_id: Optional[int] = Query(None, description="Filter by type ID"),
    is_low_stock: Optional[bool] = Query(None, description="Filter low stock"),
    is_expired: Optional[bool] = Query(None, description="Filter expired"),
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_local_db)
):
    """
    Get medicines list with pagination and filters.
    
    **Accessible to**: All authenticated users
    """
    medicines, total = medicine_service.get_medicines(
        db=db,
        page=page,
        page_size=page_size,
        search=search,
        family_id=family_id,
        type_id=type_id,
        is_low_stock=is_low_stock,
        is_expired=is_expired
    )
    
    # 1 seule requête pour compter les lots actifs de tous les médicaments de la page
    med_ids = [m.id for m in medicines]
    batch_counts = {}
    if med_ids:
        from app.models.batch import Batch
        from sqlalchemy import func
        batch_counts = dict(
            db.query(Batch.medicine_id, func.count(Batch.id))
            .filter(Batch.medicine_id.in_(med_ids), Batch.is_active == True, Batch.quantity > 0)
            .group_by(Batch.medicine_id)
            .all()
        )
    
    # Enrich responses
    enriched_items = [enrich_medicine_response(m, batch_count=batch_counts.get(m.id, 0)) for m in medicines]
    
    return PaginatedResponse.create(
        items=enriched_items,
        total=total,
        page=page,
        page_size=page_size
    )


@router.get(
    "/medicines/expiring-soon",
    response_model=list[MedicineResponse],
    summary="Get medicines expiring soon (next 6 months)"
)
async def get_expiring_soon_medicines_path(
    days: int = Query(180, description="Days threshold"),
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_local_db)
):
    """
    Get medicines expiring in the next N days (default 180 = 6 months).
    Defined before /medicines/{medicine_id} so the literal path wins.
    """
    medicines = medicine_service.get_expiring_soon_medicines(db, days)
    return [enrich_medicine_response(m) for m in medicines]


@router.get(
    "/medicines/{medicine_id}",
    response_model=MedicineResponse,
    summary="Get a specific medicine"
)
async def get_medicine(
    medicine_id: int,
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_local_db)
):
    """
    Get a single medicine by ID.
    
    **Accessible to**: All authenticated users
    """
    medicine = medicine_service.get_medicine_by_id(db, medicine_id)
    if not medicine:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Medicine with ID {medicine_id} not found"
        )
    
    return enrich_medicine_response(medicine)


@router.get(
    "/expiring-soon",
    response_model=list[MedicineResponse],
    summary="Get medicines expiring soon (next 6 months)"
)
async def get_expiring_soon_alias(
    days: int = Query(180, description="Days threshold"),
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_local_db)
):
    """
    Get medicines expiring in the next N days (default 180 = 6 months).
    This path avoids the /medicines/{medicine_id} dynamic route.
    """
    medicines = medicine_service.get_expiring_soon_medicines(db, days)
    return [enrich_medicine_response(m) for m in medicines]


@router.post(
    "/medicines",
    response_model=MedicineResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create a new medicine"
)
async def create_medicine(
    medicine_data: MedicineCreate,
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_local_db)
):
    """
    Create a new medicine.
    
    **Accessible to**: All authenticated users
    """
    # Check if code already exists
    existing = medicine_service.get_medicine_by_code(db, medicine_data.code) if medicine_data.code else None
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Medicine with code '{medicine_data.code}' already exists"
        )
    
    # Verify family and type exist if provided
    if medicine_data.family_id:
        family = medicine_service.get_family_by_id(db, medicine_data.family_id)
        if not family:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Medicine family with ID {medicine_data.family_id} not found"
            )
    
    if medicine_data.type_id:
        med_type = medicine_service.get_type_by_id(db, medicine_data.type_id)
        if not med_type:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Medicine type with ID {medicine_data.type_id} not found"
            )
    
    medicine = medicine_service.create_medicine(db, medicine_data)
    return enrich_medicine_response(medicine)


@router.put(
    "/medicines/{medicine_id}",
    response_model=MedicineResponse,
    summary="Update a medicine (Admin & Pharmacist)"
)
async def update_medicine(
    medicine_id: int,
    medicine_data: MedicineUpdate,
    current_user: User = Depends(get_pharmacist_user),
    db: Session = Depends(get_local_db)
):
    """
    Update a medicine.
    
    **Accessible to**: Admin and Pharmacist
    """
    # Check if code is being changed and if it already exists
    if medicine_data.code:
        existing = medicine_service.get_medicine_by_code(db, medicine_data.code)
        if existing and existing.id != medicine_id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Medicine with code '{medicine_data.code}' already exists"
            )
    
    existing_med = medicine_service.get_medicine_by_id(db, medicine_id)
    if not existing_med:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Medicine with ID {medicine_id} not found"
        )

    # Capture old values for audit diff
    old_name = existing_med.name
    old_qty = existing_med.quantity
    old_price = existing_med.selling_price
    old_purchase_price = existing_med.purchase_price
    old_forme = existing_med.forme
    old_dosage = existing_med.dosage

    medicine = medicine_service.update_medicine(db, medicine_id, medicine_data)
    if not medicine:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Medicine with ID {medicine_id} not found"
        )

    # Compute audit diff
    changes = []
    if medicine_data.name and medicine_data.name != old_name:
        changes.append(f"Nom: '{old_name}' -> '{medicine.name}'")
    if medicine_data.quantity is not None and medicine_data.quantity != old_qty:
        changes.append(f"Stock: {old_qty} -> {medicine.quantity}")
    if medicine_data.selling_price is not None and medicine_data.selling_price != old_price:
        changes.append(f"Prix vente: {old_price} -> {medicine.selling_price} FBu")
    if medicine_data.purchase_price is not None and medicine_data.purchase_price != old_purchase_price:
        changes.append(f"Prix achat: {old_purchase_price} -> {medicine.purchase_price} FBu")
    if medicine_data.forme and medicine_data.forme != old_forme:
        changes.append(f"Forme: '{old_forme}' -> '{medicine.forme}'")
    if medicine_data.dosage and medicine_data.dosage != old_dosage:
        changes.append(f"Dosage: '{old_dosage}' -> '{medicine.dosage}'")

    details_str = " | ".join(changes) if changes else "Modification des informations du médicament"

    from app.services import audit_service
    audit_service.log_deletion(
        db=db,
        action="UPDATE_MEDICINE",
        entity_type="medicine",
        entity_id=medicine_id,
        entity_name=f"{medicine.name} ({medicine.code or 'N/A'})",
        user=current_user,
        details=details_str,
    )

    return enrich_medicine_response(medicine)



@router.delete(
    "/medicines/{medicine_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Delete a medicine (Admin & Pharmacist)"
)
async def delete_medicine(
    medicine_id: int,
    current_user: User = Depends(get_pharmacist_user),
    db: Session = Depends(get_local_db)
):
    """
    Delete a medicine.
    
    **Accessible to**: Admin and Pharmacist
    """
    medicine = medicine_service.get_medicine_by_id(db, medicine_id)
    if not medicine:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Medicine with ID {medicine_id} not found"
        )
    
    med_name = medicine.name
    med_code = medicine.code or "N/A"
    med_qty = medicine.quantity or 0

    success = medicine_service.delete_medicine(db, medicine_id)
    if not success:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Medicine with ID {medicine_id} not found"
        )

    from app.services import audit_service
    audit_service.log_deletion(
        db=db,
        action="DELETE_MEDICINE",
        entity_type="medicine",
        entity_id=medicine_id,
        entity_name=f"{med_name} ({med_code})",
        user=current_user,
        details=f"Stock initial: {med_qty} unités",
    )


@router.get(
    "/alerts",
    response_model=StockAlertsResponse,
    summary="Get stock alerts (low stock + expired)"
)
async def get_stock_alerts(
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_local_db)
):
    """
    Get stock alerts: low stock and expired medicines.
    
    **Accessible to**: All authenticated users
    """
    low_stock, expired = medicine_service.get_stock_alerts(db)
    
    return StockAlertsResponse(
        low_stock=[enrich_medicine_response(m) for m in low_stock],
        expired=[enrich_medicine_response(m) for m in expired],
        total_alerts=len(low_stock) + len(expired)
    )


@router.get(
    "/batch-alerts",
    response_model=dict,
    summary="Get lot/batch expiration alerts"
)
async def get_batch_alerts(
    days: int = Query(180, ge=1, description="Days threshold"),
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_local_db)
):
    """Get expired and soon-expiring active batches."""
    return medicine_service.get_batch_alerts(db, days)


@router.get(
    "/integrity",
    response_model=dict,
    summary="Check stock total consistency between medicines and batches"
)
async def get_stock_integrity(
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_local_db)
):
    """Compare Medicine.quantity with active batch totals."""
    return medicine_service.get_stock_integrity(db)


@router.post(
    "/integrity/fix",
    response_model=dict,
    summary="Fix stock totals from active batches (Admin only)"
)
async def fix_stock_integrity(
    current_admin: User = Depends(get_admin_user),
    db: Session = Depends(get_local_db)
):
    """Synchronize Medicine.quantity from active batch totals."""
    return medicine_service.fix_stock_integrity(db)


@router.get(
    "/movements",
    summary="Get stock movements journal with filters"
)
async def get_stock_movements(
    page: int = Query(1, ge=1, description="Page number"),
    page_size: int = Query(50, ge=1, le=100, description="Items per page"),
    medicine_id: Optional[int] = Query(None, description="Filter by medicine ID"),
    movement_type: Optional[str] = Query(None, description="Filter by type: entree, sortie_vente, ajustement, perte"),
    start_date: Optional[str] = Query(None, description="Start date (YYYY-MM-DD)"),
    end_date: Optional[str] = Query(None, description="End date (YYYY-MM-DD)"),
    search: Optional[str] = Query(None, description="Search by medicine name or reference"),
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_local_db)
):
    """
    Get paginated stock movements journal.
    
    Returns all stock movements with associated medicine info,
    sorted by date descending (most recent first).
    
    **Accessible to**: All authenticated users
    """
    from datetime import datetime, timedelta
    from app.models.stock_movement import StockMovement
    from app.models.medicine import Medicine
    from sqlalchemy import desc
    
    query = db.query(StockMovement).join(
        Medicine, StockMovement.medicine_id == Medicine.id
    )
    
    # Apply filters
    if medicine_id:
        query = query.filter(StockMovement.medicine_id == medicine_id)
    
    if movement_type:
        query = query.filter(StockMovement.type == movement_type)
    
    if search:
        search_term = f"%{search}%"
        query = query.filter(
            (Medicine.name.ilike(search_term)) |
            (StockMovement.reference.ilike(search_term)) |
            (StockMovement.motif.ilike(search_term))
        )
    
    if start_date:
        try:
            start = datetime.strptime(start_date, "%Y-%m-%d")
            query = query.filter(StockMovement.date_mouvement >= start)
        except ValueError:
            pass
    
    if end_date:
        try:
            end = datetime.strptime(end_date, "%Y-%m-%d") + timedelta(days=1)
            query = query.filter(StockMovement.date_mouvement < end)
        except ValueError:
            pass
    
    # Count total
    total = query.count()
    
    # Order and paginate
    movements = (
        query.order_by(desc(StockMovement.date_mouvement))
        .offset((page - 1) * page_size)
        .limit(page_size)
        .all()
    )
    
    # Format response
    items = []
    for m in movements:
        med_name = "Produit supprimé"
        med_code = "N/A"
        try:
            if m.medicine:
                med_name = m.medicine.name
                med_code = m.medicine.code
        except Exception:
            pass
        
        items.append({
            "id": m.id,
            "medicine_id": m.medicine_id,
            "medicine_name": med_name,
            "medicine_code": med_code,
            "batch_id": m.batch_id,
            "type": m.type,
            "quantite": m.quantite,
            "motif": m.motif,
            "reference": m.reference,
            "date_mouvement": m.date_mouvement.isoformat() if m.date_mouvement else None,
        })
    
    return {
        "total": total,
        "page": page,
        "page_size": page_size,
        "total_pages": (total + page_size - 1) // page_size,
        "items": items,
    }


@router.get(
    "/medicines/{medicine_id}/audit-logs",
    summary="Get modification and deletion history for a specific medicine",
)
async def get_medicine_audit_history(
    medicine_id: int,
    current_user: User = Depends(get_pharmacist_user),
    db: Session = Depends(get_local_db),
):
    """
    Get audit trail for a specific medicine (modifications, price changes, stock adjustments).
    Accessible to Pharmacist and Admin.
    """
    from app.services import audit_service
    medicine = medicine_service.get_medicine_by_id(db, medicine_id)
    med_name = medicine.name if medicine else ""

    result = audit_service.get_deletion_logs(
        db=db,
        entity_id=medicine_id,
        limit=100,
    )
    if result.get("total", 0) == 0 and med_name:
        result = audit_service.get_deletion_logs(
            db=db,
            search=med_name,
            limit=100,
        )
    return result


@router.get(
    "/audit-logs",
    summary="Get global stock audit logs (modifications and deletions)",
)
async def get_stock_audit_logs(
    action: Optional[str] = None,
    search: Optional[str] = None,
    start_date: Optional[str] = None,
    end_date: Optional[str] = None,
    page: int = 1,
    page_size: int = 50,
    current_user: User = Depends(get_admin_user),
    db: Session = Depends(get_local_db),
):
    """
    Get paginated stock audit logs for all medicine modifications and deletions.
    Accessible to Admin only.
    """
    from app.services import audit_service
    offset = (page - 1) * page_size
    result = audit_service.get_deletion_logs(
        db=db,
        entity_type=None,
        action=action,
        start_date=start_date,
        end_date=end_date,
        search=search,
        limit=page_size,
        offset=offset,
    )
    return {
        "items": result["items"],
        "total": result["total"],
        "page": page,
        "page_size": page_size,
        "total_pages": (result["total"] + page_size - 1) // page_size if page_size > 0 else 1,
    }


class BulkDeleteLogsRequest(BaseModel):
    log_ids: List[int]


@router.delete(
    "/audit-logs/{log_id}",
    summary="Delete a single audit log entry (Admin only)",
)
async def delete_stock_audit_log(
    log_id: int,
    current_user: User = Depends(get_admin_user),
    db: Session = Depends(get_local_db),
):
    """
    Delete a specific audit log by ID.
    Accessible to Admin only.
    """
    from app.services import audit_service
    success = audit_service.delete_audit_log(db, log_id)
    if not success:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Log d'audit #{log_id} introuvable",
        )
    return {"success": True, "message": f"Log d'audit #{log_id} supprimé"}


@router.delete(
    "/audit-logs",
    summary="Bulk delete audit log entries (Admin only)",
)
async def bulk_delete_stock_audit_logs(
    body: BulkDeleteLogsRequest,
    current_user: User = Depends(get_admin_user),
    db: Session = Depends(get_local_db),
):
    """
    Delete multiple audit logs by their IDs.
    Accessible to Admin only.
    """
    from app.services import audit_service
    count = audit_service.delete_audit_logs(db, body.log_ids)
    return {"success": True, "deleted_count": count, "message": f"{count} log(s) d'audit supprimé(s)"}




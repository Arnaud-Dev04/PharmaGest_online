"""
Medicine service layer - Business logic for medicines, families, and types.
"""

from sqlalchemy.orm import Session
from sqlalchemy import or_, and_, func
from typing import List, Optional, Tuple
from datetime import date, timedelta, datetime
import logging

logger = logging.getLogger("medicine_service")

from app.models.medicine import Medicine, MedicineFamily, MedicineType
from app.models.batch import Batch
from app.models.stock_movement import StockMovement
from app.models.sales import SaleItem
from app.models.pos_sale import POSSaleItem
from app.models.restock import RestockItem
from app.models.medicine_pricing import MedicinePricing
from app.schemas.medicine import (
    MedicineCreate, MedicineUpdate,
    MedicineFamilyCreate, MedicineFamilyUpdate,
    MedicineTypeCreate, MedicineTypeUpdate
)


# ============================================================================
# MEDICINE FAMILY OPERATIONS
# ============================================================================

def get_families(db: Session) -> List[MedicineFamily]:
    """Get all medicine families."""
    return db.query(MedicineFamily).order_by(MedicineFamily.name).all()


def get_family_by_id(db: Session, family_id: int) -> Optional[MedicineFamily]:
    """Get a medicine family by ID."""
    return db.query(MedicineFamily).filter(MedicineFamily.id == family_id).first()


def create_family(db: Session, family_data: MedicineFamilyCreate) -> MedicineFamily:
    """Create a new medicine family."""
    family = MedicineFamily(name=family_data.name)
    db.add(family)
    db.commit()
    db.refresh(family)
    return family


def update_family(db: Session, family_id: int, family_data: MedicineFamilyUpdate) -> Optional[MedicineFamily]:
    """Update a medicine family."""
    family = get_family_by_id(db, family_id)
    if not family:
        return None
    
    family.name = family_data.name
    db.commit()
    db.refresh(family)
    return family


def delete_family(db: Session, family_id: int) -> bool:
    """Delete a medicine family if not used by any medicine."""
    family = get_family_by_id(db, family_id)
    if not family:
        return False
    
    # Check if family is used by medicines
    medicine_count = db.query(Medicine).filter(Medicine.family_id == family_id).count()
    if medicine_count > 0:
        return False
    
    db.delete(family)
    db.commit()
    return True


# ============================================================================
# MEDICINE TYPE OPERATIONS
# ============================================================================

def get_types(db: Session) -> List[MedicineType]:
    """Get all medicine types."""
    return db.query(MedicineType).order_by(MedicineType.name).all()


def get_type_by_id(db: Session, type_id: int) -> Optional[MedicineType]:
    """Get a medicine type by ID."""
    return db.query(MedicineType).filter(MedicineType.id == type_id).first()


def create_type(db: Session, type_data: MedicineTypeCreate) -> MedicineType:
    """Create a new medicine type."""
    med_type = MedicineType(name=type_data.name)
    db.add(med_type)
    db.commit()
    db.refresh(med_type)
    return med_type


def update_type(db: Session, type_id: int, type_data: MedicineTypeUpdate) -> Optional[MedicineType]:
    """Update a medicine type."""
    med_type = get_type_by_id(db, type_id)
    if not med_type:
        return None
    
    med_type.name = type_data.name
    db.commit()
    db.refresh(med_type)
    return med_type


def delete_type(db: Session, type_id: int) -> bool:
    """Delete a medicine type if not used by any medicine."""
    med_type = get_type_by_id(db, type_id)
    if not med_type:
        return False
    
    # Check if type is used by medicines
    medicine_count = db.query(Medicine).filter(Medicine.type_id == type_id).count()
    if medicine_count > 0:
        return False
    
    db.delete(med_type)
    db.commit()
    return True


# ============================================================================
# MEDICINE OPERATIONS
# ============================================================================

def _default_expiry() -> date:
    return date.today() + timedelta(days=730)


def _stock_movement(
    db: Session,
    medicine_id: int,
    quantity: int,
    movement_type: str,
    motif: str,
    batch_id: Optional[int] = None,
    reference: Optional[str] = None,
) -> StockMovement:
    movement = StockMovement(
        medicine_id=medicine_id,
        batch_id=batch_id,
        type=movement_type,
        quantite=quantity,
        motif=motif,
        reference=reference,
    )
    db.add(movement)
    return movement


def sync_medicine_stock(db: Session, medicine_id: int, commit: bool = False) -> float:
    """
    Keep Medicine.quantity synchronized with active batch quantities.

    Batch is the POS source of truth; Medicine.quantity is the cached total used
    by stock lists, dashboards, and legacy sale flows.
    """
    total = db.query(func.sum(Batch.quantity)).filter(
        Batch.medicine_id == medicine_id,
        Batch.is_active == True,
    ).scalar() or 0.0

    medicine = get_medicine_by_id(db, medicine_id)
    if medicine:
        medicine.quantity = total
        active_batches = db.query(Batch).filter(
            Batch.medicine_id == medicine_id,
            Batch.is_active == True,
            Batch.quantity > 0,
        ).order_by(Batch.expiration_date.asc()).all()
        medicine.expiry_date = active_batches[0].expiration_date if active_batches else None
        medicine.updated_at = datetime.utcnow()

    if commit:
        db.commit()
    return float(total)


def _ensure_legacy_batch(db: Session, medicine: Medicine) -> Optional[Batch]:
    """
    Convert legacy global stock into an initial batch when a medicine has stock
    but no active batch. This prevents manual stock edits from losing POS stock.
    """
    if (medicine.quantity or 0) <= 0:
        return None

    existing = db.query(Batch).filter(
        Batch.medicine_id == medicine.id,
        Batch.is_active == True,
        Batch.quantity > 0,
    ).first()
    if existing:
        return existing

    batch = Batch(
        medicine_id=medicine.id,
        batch_number=f"INIT-{medicine.code}",
        expiration_date=medicine.expiry_date or _default_expiry(),
        quantity=medicine.quantity,
        purchase_price=medicine.price_buy,
        is_active=True,
    )
    db.add(batch)
    db.flush()
    _stock_movement(
        db,
        medicine.id,
        int(medicine.quantity),
        "entree",
        "Migration stock global vers lot initial",
        batch.id,
        f"INIT-{medicine.code}",
    )
    return batch


def _create_batch(
    db: Session,
    medicine: Medicine,
    quantity: float,
    batch_number: str,
    expiry_date: Optional[date],
    purchase_price: Optional[float],
    reference: str,
    motif: str,
) -> Batch:
    batch = Batch(
        medicine_id=medicine.id,
        batch_number=batch_number,
        expiration_date=expiry_date or medicine.expiry_date or _default_expiry(),
        quantity=quantity,
        purchase_price=purchase_price if purchase_price is not None else medicine.price_buy,
        is_active=True,
    )
    db.add(batch)
    db.flush()
    _stock_movement(
        db,
        medicine.id,
        int(quantity),
        "entree",
        motif,
        batch.id,
        reference,
    )
    return batch


def adjust_stock_to_quantity(
    db: Session,
    medicine: Medicine,
    target_quantity: float,
    motif: str = "Ajustement manuel stock",
    reference: Optional[str] = None,
    expiry_date: Optional[date] = None,
) -> None:
    """
    Adjust active batches until their sum equals target_quantity.
    Positive deltas create an adjustment batch; negative deltas consume FEFO.
    """
    _ensure_legacy_batch(db, medicine)
    current_total = db.query(func.sum(Batch.quantity)).filter(
        Batch.medicine_id == medicine.id,
        Batch.is_active == True,
    ).scalar()

    if current_total is None:
        current_total = medicine.quantity or 0.0

    delta = float(target_quantity) - float(current_total)
    if abs(delta) < 0.0001:
        sync_medicine_stock(db, medicine.id)
        return

    ref = reference or f"ADJ-{medicine.id}-{datetime.utcnow().strftime('%Y%m%d%H%M%S')}"

    if delta > 0:
        # Avant de créer un nouveau lot, réactiver les lots existants désactivés qui ont encore du stock
        # (cela corrige le cas où un lot a été désactivé après une vente à 0, puis ré-approvisionné)
        inactive_with_stock = db.query(Batch).filter(
            Batch.medicine_id == medicine.id,
            Batch.is_active == False,
            Batch.quantity > 0,
        ).all()
        for ib in inactive_with_stock:
            ib.is_active = True
            db.flush()
            logger.info(f"Lot #{ib.id} réactivé pour {medicine.name} (qty={ib.quantity})")
        _create_batch(
            db,
            medicine,
            delta,
            ref,
            expiry_date or medicine.expiry_date,
            medicine.price_buy,
            ref,
            motif,
        )
    else:
        remaining = abs(delta)
        batches = db.query(Batch).filter(
            Batch.medicine_id == medicine.id,
            Batch.is_active == True,
            Batch.quantity > 0,
        ).order_by(Batch.expiration_date.asc()).all()

        for batch in batches:
            if remaining <= 0:
                break
            take = min(float(batch.quantity), remaining)
            batch.quantity -= take
            if batch.quantity <= 0:
                batch.quantity = 0
                batch.is_active = False
            _stock_movement(
                db,
                medicine.id,
                -int(take),
                "ajustement",
                motif,
                batch.id,
                ref,
            )
            remaining -= take

        if remaining > 0.0001:
            raise ValueError(
                f"Impossible d'ajuster {medicine.name}: lots insuffisants "
                f"pour retirer {abs(delta):.0f} unités"
            )

    sync_medicine_stock(db, medicine.id)

def get_medicines(
    db: Session,
    page: int = 1,
    page_size: int = 50,
    search: Optional[str] = None,
    family_id: Optional[int] = None,
    type_id: Optional[int] = None,
    is_low_stock: Optional[bool] = None,
    is_expired: Optional[bool] = None
) -> Tuple[List[Medicine], int]:
    """
    Get medicines with pagination and filters.
    
    Returns:
        Tuple of (medicines list, total count)
    """
    query = db.query(Medicine).filter(Medicine.is_active == True)
    
    # Apply filters
    if search:
        search_filter = or_(
            Medicine.name.ilike(f"%{search}%"),
            Medicine.code.ilike(f"%{search}%"),
            Medicine.code_barres.ilike(f"%{search}%"),
            Medicine.dci.ilike(f"%{search}%"),
            Medicine.fournisseur.ilike(f"%{search}%"),
        )
        query = query.filter(search_filter)
    
    if family_id:
        query = query.filter(Medicine.family_id == family_id)
    
    if type_id:
        query = query.filter(Medicine.type_id == type_id)
    
    if is_low_stock:
        query = query.filter(Medicine.quantity <= Medicine.min_stock_alert)
    
    if is_expired:
        today = date.today()
        query = query.filter(
            and_(
                Medicine.expiry_date.isnot(None),
                Medicine.expiry_date <= today
            )
        )
    
    # Get total count
    total = query.count()
    
    # Apply pagination with eager loading of family and type
    from sqlalchemy.orm import joinedload
    offset = (page - 1) * page_size
    medicines = (
        query
        .options(joinedload(Medicine.family), joinedload(Medicine.type))
        .order_by(Medicine.name)
        .offset(offset)
        .limit(page_size)
        .all()
    )
    
    return medicines, total


def get_medicine_by_id(db: Session, medicine_id: int) -> Optional[Medicine]:
    """Get a medicine by ID."""
    return db.query(Medicine).filter(Medicine.id == medicine_id).first()


def get_medicine_by_code(db: Session, code: str) -> Optional[Medicine]:
    """Get a medicine by code."""
    return db.query(Medicine).filter(Medicine.code == code).first()


def create_medicine(db: Session, medicine_data: MedicineCreate) -> Medicine:
    """Create a new medicine."""
    # Auto-generate code if not provided
    if not medicine_data.code:
        import time
        # Generate a unique code based on timestamp
        medicine_data.code = f"MED-{int(time.time()*1000)}"
        
    # Calculate Total Units per Packaging (Box)
    total_units = medicine_data.blisters_per_box * medicine_data.units_per_blister
    
    # Store this as units_per_packaging (compatibility)
    medicine_data.units_per_packaging = total_units
    
    # CONVERT QUANTITY: Input is now expected to be in Total Units from frontend
    # medicine_data.quantity = medicine_data.quantity * total_units
    
    # Alert threshold is also expected in Total Units
    # medicine_data.min_stock_alert = medicine_data.min_stock_alert * total_units
        
    initial_quantity = float(medicine_data.quantity or 0)
    data = medicine_data.model_dump()
    data["quantity"] = 0.0
    medicine = Medicine(**data)
    db.add(medicine)
    db.flush()

    if initial_quantity > 0:
        _create_batch(
            db,
            medicine,
            initial_quantity,
            f"INIT-{medicine.code}",
            medicine.expiry_date,
            medicine.price_buy,
            f"INIT-{medicine.code}",
            "Stock initial",
        )
        sync_medicine_stock(db, medicine.id)

    db.commit()
    db.refresh(medicine)
    return medicine


def update_medicine(db: Session, medicine_id: int, medicine_data: MedicineUpdate) -> Optional[Medicine]:
    """Update a medicine."""
    medicine = get_medicine_by_id(db, medicine_id)
    if not medicine:
        return None
    
    # Update only provided fields
    update_data = medicine_data.model_dump(exclude_unset=True)
    target_quantity = update_data.pop("quantity", None)
    
    # Handle unit hierarchy update
    current_blisters = update_data.get('blisters_per_box', medicine.blisters_per_box) or 1
    current_units_per_blister = update_data.get('units_per_blister', medicine.units_per_blister) or 1
    
    new_total_units = current_blisters * current_units_per_blister
    
    # Update total units default
    update_data['units_per_packaging'] = new_total_units
    
    # If quantity is being updated, assume input is ALREADY In UNITS from frontend
    # if 'quantity' in update_data and update_data['quantity'] is not None:
    #     update_data['quantity'] = update_data['quantity'] * new_total_units
        
    # Same for alert threshold
    # if 'min_stock_alert' in update_data and update_data['min_stock_alert'] is not None:
    #     update_data['min_stock_alert'] = update_data['min_stock_alert'] * new_total_units

    try:
        for field, value in update_data.items():
            setattr(medicine, field, value)

        if target_quantity is not None:
            adjust_stock_to_quantity(
                db,
                medicine,
                float(target_quantity),
                motif="Ajustement depuis fiche stock",
                expiry_date=update_data.get("expiry_date") or medicine.expiry_date,
            )
        else:
            sync_medicine_stock(db, medicine.id)

        medicine.updated_at = datetime.utcnow()

        # Synchronize latest MedicinePricing if exists so POS gets identical data
        pricing_entry = db.query(MedicinePricing).filter(
            MedicinePricing.medicine_id == medicine.id
        ).order_by(MedicinePricing.created_at.desc()).first()
        if pricing_entry:
            if medicine.name:
                pricing_entry.nom = medicine.name
            new_qty = int(medicine.quantity or 0)
            pricing_entry.total_comprimes = new_qty
            cpp = pricing_entry.comprimes_par_plaquette or 1
            ppb = pricing_entry.plaquettes_par_boite or 1
            bpc = pricing_entry.boites_par_carton or 1
            cpb = cpp * ppb
            cpc = cpb * bpc
            pricing_entry.total_plaquettes = new_qty // cpp if cpp > 0 else 0
            pricing_entry.total_boites = new_qty // cpb if cpb > 0 else 0
            pricing_entry.nb_cartons = max(1, new_qty // cpc if cpc > 0 else 1)
            if medicine.prix_vente_unite:
                pricing_entry.vente_comprime = medicine.prix_vente_unite
            if medicine.prix_vente_boite:
                pricing_entry.vente_boite = medicine.prix_vente_boite
            if medicine.prix_vente_carton:
                pricing_entry.vente_carton = medicine.prix_vente_carton
            if medicine.prix_achat_unite:
                pricing_entry.achat_comprime = medicine.prix_achat_unite
            if medicine.prix_achat_boite:
                pricing_entry.achat_boite = medicine.prix_achat_boite
            if medicine.prix_achat_carton:
                pricing_entry.achat_carton = medicine.prix_achat_carton
            pricing_entry.updated_at = datetime.utcnow()

        db.commit()
        db.refresh(medicine)
        return medicine
    except Exception:
        db.rollback()
        raise

def delete_medicine(db: Session, medicine_id: int) -> bool:
    """Delete a medicine."""
    medicine = get_medicine_by_id(db, medicine_id)
    if not medicine:
        return False
    
    # Check for existing references using this medicine
    has_references = any([
        db.query(SaleItem).filter(SaleItem.medicine_id == medicine_id).first(),
        db.query(POSSaleItem).filter(POSSaleItem.medicine_id == medicine_id).first(),
        db.query(RestockItem).filter(RestockItem.medicine_id == medicine_id).first(),
        db.query(MedicinePricing).filter(MedicinePricing.medicine_id == medicine_id).first(),
        db.query(StockMovement).filter(StockMovement.medicine_id == medicine_id).first(),
        db.query(Batch).filter(Batch.medicine_id == medicine_id).first(),
    ])
    
    if has_references:
        # Soft delete because sales history exists
        medicine.is_active = False
        db.commit()
    else:
        # Hard delete if no history (cleaner)
        db.delete(medicine)
        db.commit()
        
    return True


# ============================================================================
# STOCK ALERTS
# ============================================================================

def get_low_stock_medicines(db: Session) -> List[Medicine]:
    """Get medicines with low stock (quantity <= min_stock_alert)."""
    return db.query(Medicine).filter(
        Medicine.quantity <= Medicine.min_stock_alert,
        Medicine.is_active == True,
    ).order_by(Medicine.quantity).all()


def get_expired_medicines(db: Session) -> List[Medicine]:
    """Get expired medicines (expiry_date <= today)."""
    today = date.today()
    return db.query(Medicine).filter(
        and_(
            Medicine.expiry_date.isnot(None),
            Medicine.expiry_date <= today,
            Medicine.is_active == True,
        )
    ).order_by(Medicine.expiry_date).all()


def get_expiring_soon_medicines(db: Session, days: int = 180) -> List[Medicine]:
    """Get medicines expiring soon (today < expiry_date <= today + days)."""
    today = date.today()
    cutoff = today + timedelta(days=days)

    
    return db.query(Medicine).filter(
        and_(
            Medicine.expiry_date > today,
            Medicine.expiry_date <= cutoff,
            Medicine.is_active == True,
        )
    ).order_by(Medicine.expiry_date).all()


def get_stock_alerts(db: Session) -> Tuple[List[Medicine], List[Medicine]]:
    """
    Get all stock alerts.
    
    Returns:
        Tuple of (low_stock medicines, expired medicines)
    """
    low_stock = get_low_stock_medicines(db)
    expired = get_expired_medicines(db)
    return low_stock, expired


def get_batch_alerts(db: Session, days: int = 180) -> dict:
    """Return active expired and expiring batches for lot-level stock alerts."""
    today = date.today()
    cutoff = today + timedelta(days=days)

    expired = db.query(Batch).join(Medicine).filter(
        Batch.is_active == True,
        Batch.quantity > 0,
        Batch.expiration_date <= today,
        Medicine.is_active == True,
    ).order_by(Batch.expiration_date.asc()).all()

    expiring_soon = db.query(Batch).join(Medicine).filter(
        Batch.is_active == True,
        Batch.quantity > 0,
        Batch.expiration_date > today,
        Batch.expiration_date <= cutoff,
        Medicine.is_active == True,
    ).order_by(Batch.expiration_date.asc()).all()

    def serialize(batch: Batch) -> dict:
        return {
            "batch_id": batch.id,
            "medicine_id": batch.medicine_id,
            "medicine_name": batch.medicine.name if batch.medicine else "",
            "medicine_code": batch.medicine.code if batch.medicine else "",
            "batch_number": batch.batch_number,
            "expiration_date": batch.expiration_date.isoformat(),
            "quantity": batch.quantity,
            "purchase_price": batch.purchase_price,
        }

    return {
        "expired": [serialize(batch) for batch in expired],
        "expiring_soon": [serialize(batch) for batch in expiring_soon],
        "total_alerts": len(expired) + len(expiring_soon),
    }


def get_stock_integrity(db: Session) -> dict:
    """Compare Medicine.quantity with the sum of active Batch.quantity."""
    medicines = db.query(Medicine).filter(Medicine.is_active == True).all()
    mismatches = []

    for medicine in medicines:
        batch_total = db.query(func.sum(Batch.quantity)).filter(
            Batch.medicine_id == medicine.id,
            Batch.is_active == True,
        ).scalar() or 0.0
        diff = float(medicine.quantity or 0) - float(batch_total)
        if abs(diff) > 0.0001:
            mismatches.append({
                "medicine_id": medicine.id,
                "code": medicine.code,
                "name": medicine.name,
                "medicine_quantity": float(medicine.quantity or 0),
                "batch_quantity": float(batch_total),
                "difference": diff,
            })

    return {
        "ok": len(mismatches) == 0,
        "mismatch_count": len(mismatches),
        "mismatches": mismatches,
    }


def fix_stock_integrity(db: Session) -> dict:
    """Synchronize every active medicine total from active batches."""
    integrity = get_stock_integrity(db)
    fixed = 0
    for mismatch in integrity["mismatches"]:
        sync_medicine_stock(db, mismatch["medicine_id"])
        fixed += 1
    db.commit()
    return {"fixed": fixed, "before": integrity}

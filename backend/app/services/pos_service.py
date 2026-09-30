"""
POS Service — Business logic for Point of Sale operations.

Core features:
- Product search (name/code) with batch info
- FEFO (First Expired First Out) batch allocation
- Atomic checkout with per-batch stock deduction
- Invoice code generation
- Sale logging
"""

from sqlalchemy.orm import Session
from sqlalchemy import func, or_, and_, case
from typing import List, Optional, Tuple
from datetime import datetime, date
from collections import defaultdict
import uuid as uuid_lib
import logging

from app.models.medicine import Medicine
from app.models.batch import Batch
from app.models.pos_sale import POSSale, POSSaleItem
from app.models.medicine_pricing import MedicinePricing
from app.models.stock_movement import StockMovement
from app.schemas.pos import (
    CartAddRequest, CartAddResponse,
    BatchAllocation, BatchInfo,
    ProductSearchResult,
    POSCheckoutRequest, CheckoutItem,
    POSSaleItemResponse, POSSaleResponse,
    BatchCreate, BatchResponse,
)

logger = logging.getLogger("pos_service")


# ============================================================================
# HELPER: Convert level quantity to base units
# ============================================================================

def _convert_to_base_units(quantity: int, level: str, medicine: Medicine) -> int:
    """Convert a quantity at a given level to base units (comprimés)."""
    if level == "carton":
        return quantity * (medicine.boxes_per_carton or 1) * (medicine.blisters_per_box or 1) * (medicine.units_per_blister or 1)
    elif level == "boite":
        return quantity * (medicine.blisters_per_box or 1) * (medicine.units_per_blister or 1)
    elif level == "plaquette":
        return quantity * (medicine.units_per_blister or 1)
    else:  # unite
        return quantity


def _get_price_at_level(medicine: Medicine, level: str) -> float:
    """Get the selling price at a given level from Medicine multi-level fields."""
    if level == "carton":
        return medicine.prix_vente_carton or medicine.price_sell
    elif level == "boite":
        return medicine.prix_vente_boite or medicine.price_sell
    elif level == "plaquette":
        return medicine.prix_vente_plaquette or medicine.price_sell
    else:  # unite
        return medicine.prix_vente_unite or medicine.price_sell


def _recalculate_pricing_quantities(pricing_entry: MedicinePricing):
    """Recalculate packaging totals and estimated benefit for a MedicinePricing entry."""
    cpp = pricing_entry.comprimes_par_plaquette or 1
    ppb = pricing_entry.plaquettes_par_boite or 1
    bpc = pricing_entry.boites_par_carton or 1

    cpb = cpp * ppb
    cpc = cpb * bpc

    pricing_entry.total_plaquettes = pricing_entry.total_comprimes // cpp if cpp > 0 else 0
    pricing_entry.total_boites = pricing_entry.total_comprimes // cpb if cpb > 0 else 0
    pricing_entry.nb_cartons = pricing_entry.total_comprimes // cpc if cpc > 0 else 0

    valeur_achat_restante = pricing_entry.total_comprimes * (pricing_entry.achat_comprime or 0.0)
    valeur_vente_restante = pricing_entry.total_comprimes * (pricing_entry.vente_comprime or 0.0)
    pricing_entry.benefice_estime = round(valeur_vente_restante - valeur_achat_restante, 2)


def reconcile_pricing_stock(db: Session) -> int:
    """
    Reconcile MedicinePricing stock with Batch quantities.
    Updates any MedicinePricing entry whose total_comprimes doesn't match its batch.
    """
    updated = 0
    try:
        pricing_entries = db.query(MedicinePricing).all()
        for entry in pricing_entries:
            batch = db.query(Batch).filter(
                Batch.medicine_id == entry.medicine_id,
                Batch.batch_number == entry.lot
            ).first()
            if batch:
                batch_qty = max(0, int(batch.quantity))
                if entry.total_comprimes != batch_qty:
                    entry.total_comprimes = batch_qty
                    _recalculate_pricing_quantities(entry)
                    updated += 1
        if updated > 0:
            db.commit()
            logger.info(f"reconcile_pricing_stock: {updated} entrées de prix synchronisées avec les lots")
    except Exception as e:
        logger.error(f"reconcile_pricing_stock failed: {e}")
        db.rollback()
    return updated


# ============================================================================
# LEGACY STOCK SYNC (auto-create batches for medicines without any)
# ============================================================================

def sync_legacy_stock(db: Session) -> int:
    """
    Auto-create default batches for medicines that have stock (quantity > 0)
    but no active batches. This handles the transition from the old system
    (no batch tracking) to the new FEFO POS system.
    
    Returns:
        Number of batches created
    """
    from datetime import timedelta
    
    today = date.today()
    default_expiry = today + timedelta(days=730)  # 2 ans par défaut
    
    # Find medicines with stock but no active batches
    medicines_with_stock = db.query(Medicine).filter(
        Medicine.is_active == True,
        Medicine.quantity > 0
    ).all()
    
    created = 0
    
    for med in medicines_with_stock:
        # Check if this medicine has any active batch with quantity > 0
        existing_batch = db.query(Batch).filter(
            Batch.medicine_id == med.id,
            Batch.is_active == True,
            Batch.quantity > 0
        ).first()
        
        if existing_batch is None:
            # No active batch — create a default one
            batch = Batch(
                medicine_id=med.id,
                batch_number=f"LOT-AUTO-{med.id:04d}",
                expiration_date=default_expiry,
                quantity=med.quantity,
                purchase_price=med.price_buy if hasattr(med, 'price_buy') else 0.0,
                is_active=True
            )
            db.add(batch)
            created += 1
            logger.info(
                f"Auto-created batch for {med.name}: "
                f"qty={med.quantity}, exp={default_expiry}"
            )
    
    if created > 0:
        db.commit()
        logger.info(f"sync_legacy_stock: {created} batches auto-créés")

    # Toujours réconcilier MedicinePricing avec les quantités des lots
    reconcile_pricing_stock(db)

    return created


# ============================================================================
# PRODUCT SEARCH
# ============================================================================

def search_products(
    db: Session, 
    query: str = "", 
    limit: int = 1000
) -> List[ProductSearchResult]:
    """Search products with multi-level pricing from latest MedicinePricing.
    
    If query is empty: returns all active medicines with available stock first,
    ordered by most recently restocked/updated (updated_at.desc(), id.desc()).
    If query is provided: searches by name, code, barcode, or dci,
    prioritizing in-stock items and exact prefix matches.
    
    Uses bulk queries for batches and pricings for high performance (0.1s for 800+ items).
    """
    today = date.today()
    
    if query and len(query.strip()) >= 1:
        search_term = f"%{query.strip()}%"
        exact_prefix = f"{query.strip()}%"
        medicines = db.query(Medicine).filter(
            Medicine.is_active == True,
            or_(
                Medicine.name.ilike(search_term),
                Medicine.code.ilike(search_term),
                Medicine.code_barres.ilike(search_term),
                Medicine.dci.ilike(search_term)
            )
        ).order_by(
            case((Medicine.quantity > 0, 0), else_=1),
            case((Medicine.name.ilike(exact_prefix), 0), else_=1),
            Medicine.name.asc()
        ).limit(limit).all()
    else:
        medicines = db.query(Medicine).filter(
            Medicine.is_active == True,
        ).order_by(
            case((Medicine.quantity > 0, 0), else_=1),
            Medicine.updated_at.desc(),
            Medicine.id.desc()
        ).limit(limit).all()
    
    if not medicines:
        return []
    
    med_ids = [m.id for m in medicines]
    
    # Bulk fetch active batches with stock for all returned medicines in 1 query
    batches = db.query(Batch).filter(
        Batch.medicine_id.in_(med_ids),
        Batch.is_active == True,
        Batch.quantity > 0,
        or_(Batch.expiration_date == None, Batch.expiration_date >= today)
    ).order_by(Batch.expiration_date.asc()).all()
    
    batches_by_med = defaultdict(list)
    for b in batches:
        batches_by_med[b.medicine_id].append(b)
        
    # Bulk fetch latest pricing for all returned medicines in 1 query
    pricings = db.query(MedicinePricing).filter(
        MedicinePricing.medicine_id.in_(med_ids)
    ).order_by(MedicinePricing.created_at.desc()).all()
    
    pricing_by_med = {}
    for p in pricings:
        if p.medicine_id and p.medicine_id not in pricing_by_med:
            pricing_by_med[p.medicine_id] = p
            
    results = []
    for med in medicines:
        med_batches = batches_by_med.get(med.id, [])
        available_qty = sum(b.quantity for b in med_batches)
        
        batch_infos = [
            BatchInfo(
                id=b.id,
                batch_number=b.batch_number,
                expiration_date=b.expiration_date,
                quantity=b.quantity
            )
            for b in med_batches
        ]
        
        latest_pricing = pricing_by_med.get(med.id)

        results.append(ProductSearchResult(
            id=med.id,
            name=med.name,
            code=med.code,
            price_sell=med.price_sell,
            available_quantity=available_qty,
            batches=batch_infos,
            units_per_packaging=med.units_per_packaging or 1,
            units_per_blister=med.units_per_blister or 1,
            blisters_per_box=med.blisters_per_box or 1,
            boxes_per_carton=med.boxes_per_carton or 1,
            # Multi-level pricing
            prix_vente_unite=latest_pricing.vente_comprime if latest_pricing else (med.prix_vente_unite or 0),
            prix_vente_plaquette=latest_pricing.vente_plaquette if latest_pricing else (med.prix_vente_plaquette or 0),
            prix_vente_boite=latest_pricing.vente_boite if latest_pricing else (med.prix_vente_boite or 0),
            prix_vente_carton=latest_pricing.vente_carton if latest_pricing else (med.prix_vente_carton or 0),
            prix_achat_unite=latest_pricing.achat_comprime if latest_pricing else (med.prix_achat_unite or 0),
            prix_achat_plaquette=latest_pricing.achat_plaquette if latest_pricing else (med.prix_achat_plaquette or 0),
            prix_achat_boite=latest_pricing.achat_boite if latest_pricing else (med.prix_achat_boite or 0),
            prix_achat_carton=latest_pricing.achat_carton if latest_pricing else (med.prix_achat_carton or 0),
            comprimes_par_plaquette=med.units_per_blister or 1,
            plaquettes_par_boite=med.blisters_per_box or 1,
            # Medicine details
            dosage_form=med.dosage_form,
            dci=med.dci,
            forme_galenique=med.forme_galenique,
        ))
    
    return results



def get_top_products(
    db: Session, 
    limit: int = 10
) -> List[ProductSearchResult]:
    """
    Get top/frequent products — based on POS sales volume.
    Falls back to products with highest stock if no sales exist.
    """
    today = date.today()
    
    try:
        # Try to get most sold products from POS history
        top_medicine_ids = db.query(
            POSSaleItem.medicine_id,
            func.sum(POSSaleItem.quantity).label('total_sold')
        ).group_by(
            POSSaleItem.medicine_id
        ).order_by(
            func.sum(POSSaleItem.quantity).desc()
        ).limit(limit).all()
    except Exception as e:
        logger.warning(f"get_top_products POS history query failed, falling back to stock: {e}")
        top_medicine_ids = []
    
    if top_medicine_ids:
        med_ids = [row[0] for row in top_medicine_ids]
        medicines = db.query(Medicine).filter(
            Medicine.id.in_(med_ids),
            Medicine.is_active == True
        ).all()
        # Sort by sales volume
        med_map = {m.id: m for m in medicines}
        medicines = [med_map[mid] for mid in med_ids if mid in med_map]
    else:
        # Fallback: products with highest stock
        medicines = db.query(Medicine).filter(
            Medicine.is_active == True,
            Medicine.quantity > 0
        ).order_by(Medicine.quantity.desc()).limit(limit).all()
    
    if not medicines:
        return []

    med_ids = [m.id for m in medicines]
    batches = db.query(Batch).filter(
        Batch.medicine_id.in_(med_ids),
        Batch.is_active == True,
        Batch.quantity > 0,
        or_(Batch.expiration_date == None, Batch.expiration_date >= today)
    ).order_by(Batch.expiration_date.asc()).all()

    batches_by_med = defaultdict(list)
    for b in batches:
        batches_by_med[b.medicine_id].append(b)

    pricings = db.query(MedicinePricing).filter(
        MedicinePricing.medicine_id.in_(med_ids)
    ).order_by(MedicinePricing.created_at.desc()).all()

    pricing_by_med = {}
    for p in pricings:
        if p.medicine_id and p.medicine_id not in pricing_by_med:
            pricing_by_med[p.medicine_id] = p

    results = []
    for med in medicines:
        med_batches = batches_by_med.get(med.id, [])
        available_qty = sum(b.quantity for b in med_batches)
        batch_infos = [
            BatchInfo(
                id=b.id,
                batch_number=b.batch_number,
                expiration_date=b.expiration_date,
                quantity=b.quantity
            )
            for b in med_batches
        ]

        latest_pricing = pricing_by_med.get(med.id)

        results.append(ProductSearchResult(
            id=med.id,
            name=med.name,
            code=med.code,
            price_sell=med.price_sell,
            available_quantity=available_qty,
            batches=batch_infos,
            units_per_packaging=med.units_per_packaging or 1,
            units_per_blister=med.units_per_blister or 1,
            blisters_per_box=med.blisters_per_box or 1,
            boxes_per_carton=med.boxes_per_carton or 1,
            prix_vente_unite=latest_pricing.vente_comprime if latest_pricing else (med.prix_vente_unite or 0),
            prix_vente_plaquette=latest_pricing.vente_plaquette if latest_pricing else (med.prix_vente_plaquette or 0),
            prix_vente_boite=latest_pricing.vente_boite if latest_pricing else (med.prix_vente_boite or 0),
            prix_vente_carton=latest_pricing.vente_carton if latest_pricing else (med.prix_vente_carton or 0),
            prix_achat_unite=latest_pricing.achat_comprime if latest_pricing else (med.prix_achat_unite or 0),
            prix_achat_plaquette=latest_pricing.achat_plaquette if latest_pricing else (med.prix_achat_plaquette or 0),
            prix_achat_boite=latest_pricing.achat_boite if latest_pricing else (med.prix_achat_boite or 0),
            prix_achat_carton=latest_pricing.achat_carton if latest_pricing else (med.prix_achat_carton or 0),
            comprimes_par_plaquette=med.units_per_blister or 1,
            plaquettes_par_boite=med.blisters_per_box or 1,
            # Medicine details
            dosage_form=med.dosage_form,
            dci=med.dci,
            forme_galenique=med.forme_galenique,
        ))
    
    return results


# ============================================================================
# FEFO ALLOCATION
# ============================================================================

def allocate_fefo(
    db: Session, 
    medicine_id: int, 
    quantity: int
) -> Tuple[Medicine, List[BatchAllocation]]:
    """
    Allocate stock using FEFO (First Expired First Out) strategy.
    
    Selects batches ordered by expiration_date ASC and allocates
    the requested quantity across one or more batches.
    
    Args:
        db: Database session
        medicine_id: Medicine to allocate from
        quantity: Total quantity needed
    
    Returns:
        Tuple of (Medicine object, list of BatchAllocation)
    
    Raises:
        ValueError: If medicine not found or insufficient stock
    """
    # Get medicine
    medicine = db.query(Medicine).filter(Medicine.id == medicine_id).first()
    if not medicine:
        raise ValueError(f"Médicament avec ID {medicine_id} introuvable")
    
    today = date.today()
    
    # Get available batches sorted FEFO (earliest expiry first)
    batches = db.query(Batch).filter(
        Batch.medicine_id == medicine_id,
        Batch.is_active == True,
        Batch.quantity > 0,
        Batch.expiration_date >= today  # Vendable jusqu'à la date d'expiration incluse
    ).order_by(Batch.expiration_date.asc()).all()
    
    if not batches:
        raise ValueError(
            f"Aucun lot disponible pour {medicine.name}. "
            f"Vérifiez le stock et les dates d'expiration."
        )
    
    remaining = quantity
    allocations = []
    
    for batch in batches:
        if remaining <= 0:
            break
        
        take = min(int(batch.quantity), remaining)
        allocations.append(BatchAllocation(
            batch_id=batch.id,
            batch_number=batch.batch_number,
            expiration_date=batch.expiration_date,
            quantity=take
        ))
        remaining -= take
    
    if remaining > 0:
        total_available = sum(int(b.quantity) for b in batches)
        raise ValueError(
            f"Stock insuffisant pour {medicine.name}. "
            f"Demandé: {quantity}, Disponible: {total_available}"
        )
    
    return medicine, allocations


def cart_add(db: Session, request: CartAddRequest) -> CartAddResponse:
    """
    Calculate FEFO allocation for adding a product to the cart.
    Converts level-based quantity to base units for stock allocation.
    """
    medicine = db.query(Medicine).filter(Medicine.id == request.medicine_id).first()
    if not medicine:
        raise ValueError(f"Médicament avec ID {request.medicine_id} introuvable")
    
    # Convert quantity at chosen level to base units
    base_units = _convert_to_base_units(request.quantity, request.level, medicine)
    
    # FEFO allocation in base units
    _, allocations = allocate_fefo(db, request.medicine_id, base_units)
    
    # Price at the chosen level
    unit_price = _get_price_at_level(medicine, request.level)
    total_price = unit_price * request.quantity
    
    return CartAddResponse(
        medicine_id=medicine.id,
        medicine_name=medicine.name,
        medicine_code=medicine.code,
        quantity=request.quantity,
        level=request.level,
        base_units=base_units,
        unit_price=unit_price,
        total_price=total_price,
        allocations=allocations
    )


# ============================================================================
# INVOICE CODE GENERATION
# ============================================================================

def generate_pos_invoice_code(db: Session) -> str:
    """
    Generate unique POS invoice code in format: POS-YYYY-NNNN.
    Compatible SQLite (local) et MySQL (remote).
    """
    from sqlalchemy import extract
    current_year = datetime.now().year

    # extract('year', ...) est compatible SQLite >= 3.38 et MySQL
    last_sale = db.query(POSSale).filter(
        extract('year', POSSale.date) == current_year
    ).order_by(POSSale.id.desc()).first()

    if last_sale and last_sale.code:
        try:
            last_number = int(last_sale.code.split('-')[-1])
            next_number = last_number + 1
        except (ValueError, IndexError):
            next_number = 1
    else:
        next_number = 1

    return f"POS-{current_year}-{next_number:04d}"


# ============================================================================
# CHECKOUT (SALE CREATION)
# ============================================================================

def checkout(
    db: Session, 
    user_id: int, 
    checkout_data: POSCheckoutRequest
) -> POSSale:
    """
    Process POS checkout — create sale and deduct stock per batch.
    
    This is the critical transactional operation that:
    1. Validates all batch allocations have sufficient stock
    2. Creates POSSale header with UUID
    3. Creates POSSaleItem for each batch allocation
    4. Deducts Batch.quantity for each allocation
    5. Updates Medicine.quantity (total stock sync)
    6. Commits atomically (all or nothing)
    
    Args:
        db: Database session
        user_id: Current user's ID
        checkout_data: Complete checkout request with items and allocations
    
    Returns:
        Created POSSale with all relationships loaded
    
    Raises:
        ValueError: If validation fails (stock, invalid batch, etc.)
    """
    try:
        # Phase 1: Validate all allocations
        validated_items = []
        total_amount = 0.0
        
        for item in checkout_data.items:
            medicine = db.query(Medicine).filter(
                Medicine.id == item.medicine_id
            ).first()
            
            if not medicine:
                raise ValueError(f"Médicament avec ID {item.medicine_id} introuvable")
            
            # Validate each batch allocation. Allocations are always in base units.
            expected_base_units = item.base_units or _convert_to_base_units(
                item.quantity,
                item.level,
                medicine,
            )
            item_total_qty = 0
            for alloc in item.allocations:
                batch = db.query(Batch).filter(
                    Batch.id == alloc.batch_id,
                    Batch.medicine_id == item.medicine_id
                ).first()
                
                if not batch:
                    raise ValueError(
                        f"Lot #{alloc.batch_id} introuvable pour {medicine.name}"
                    )
                
                if not batch.is_active:
                    raise ValueError(
                        f"Lot {batch.batch_number} pour {medicine.name} est désactivé"
                    )
                
                if batch.quantity < alloc.quantity:
                    raise ValueError(
                        f"Stock insuffisant dans le lot {batch.batch_number} "
                        f"pour {medicine.name}. "
                        f"Demandé: {alloc.quantity}, Disponible: {int(batch.quantity)}"
                    )
                
                if batch.expiration_date < date.today():
                    raise ValueError(
                        f"Le lot {batch.batch_number} pour {medicine.name} "
                        f"est expiré ({batch.expiration_date}). Vente interdite."
                    )
                
                item_total_qty += alloc.quantity
            
            # Verify total base units match the FEFO allocation.
            if item_total_qty != expected_base_units:
                raise ValueError(
                    f"Incohérence de quantité pour {medicine.name}: "
                    f"allocations={item_total_qty}, demandé={expected_base_units}"
                )
            
            line_total = item.unit_price * item.quantity
            total_amount += line_total
            validated_items.append({
                "medicine": medicine,
                "item": item,
                "line_total": line_total,
                "base_units": expected_base_units,
            })
        
        # Phase 2: Create POSSale
        invoice_code = generate_pos_invoice_code(db)
        
        sale = POSSale(
            sale_uuid=str(uuid_lib.uuid4()),
            code=invoice_code,
            total_amount=total_amount,
            payment_method=checkout_data.payment_method,
            date=datetime.now(),
            user_id=user_id,
            customer_id=checkout_data.customer_id,
            customer_name=checkout_data.customer_name,
            insurance_provider=checkout_data.insurance_provider,
            insurance_card_id=checkout_data.insurance_card_id,
            coverage_percent=checkout_data.coverage_percent or 0.0
        )
        db.add(sale)
        db.flush()  # Get sale.id
        
        # Phase 3: Create sale items + deduct stock
        for validated in validated_items:
            medicine = validated["medicine"]
            item = validated["item"]
            line_total = validated["line_total"]
            base_units = validated["base_units"]
            price_per_base_unit = line_total / base_units if base_units else 0.0
            
            for alloc in item.allocations:
                # Create sale item per batch allocation
                sale_item = POSSaleItem(
                    sale_id=sale.id,
                    medicine_id=medicine.id,
                    batch_id=alloc.batch_id,
                    quantity=alloc.quantity,
                    unit_price=price_per_base_unit,
                    total_price=price_per_base_unit * alloc.quantity,
                    discount_percent=item.discount_percent or 0.0,
                )
                db.add(sale_item)
                
                # Deduct batch stock
                batch = db.query(Batch).filter(Batch.id == alloc.batch_id).first()
                batch.quantity -= alloc.quantity
                
                # Deactivate batch if empty
                if batch.quantity <= 0:
                    batch.quantity = 0
                    batch.is_active = False

                # Deduct MedicinePricing stock
                pricing_entry = db.query(MedicinePricing).filter(
                    MedicinePricing.medicine_id == medicine.id,
                    MedicinePricing.lot == batch.batch_number
                ).first()
                if not pricing_entry:
                    pricing_entry = db.query(MedicinePricing).filter(
                        MedicinePricing.medicine_id == medicine.id,
                        MedicinePricing.total_comprimes > 0
                    ).order_by(MedicinePricing.date_peremption.asc()).first()

                if pricing_entry:
                    pricing_entry.total_comprimes = max(0, pricing_entry.total_comprimes - alloc.quantity)
                    _recalculate_pricing_quantities(pricing_entry)
                
                # Create stock movement for audit trail
                movement = StockMovement(
                    medicine_id=medicine.id,
                    batch_id=alloc.batch_id,
                    type='sortie_vente',
                    quantite=-alloc.quantity,
                    motif=f"Vente POS",
                    reference=sale.code
                )
                db.add(movement)
            
            # Update medicine total stock
            medicine.quantity -= base_units
            if medicine.quantity < 0:
                medicine.quantity = 0  # Safety net
        
        # Phase 4: Commit
        db.commit()
        db.refresh(sale)
        
        logger.info(
            f"POS Sale {sale.code} (UUID: {sale.sale_uuid}) created. "
            f"Total: {sale.total_amount} FBu, Items: {len(sale.items)}"
        )
        
        return sale
        
    except ValueError:
        db.rollback()
        raise
    except Exception as e:
        db.rollback()
        logger.error(f"Checkout failed: {str(e)}")
        raise ValueError(f"Erreur lors de la validation: {str(e)}")


# ============================================================================
# SALE RETRIEVAL
# ============================================================================

def get_pos_sale_by_id(db: Session, sale_id: int) -> Optional[POSSale]:
    """Get a POS sale by ID."""
    return db.query(POSSale).filter(POSSale.id == sale_id).first()


def get_pos_sale_by_uuid(db: Session, uuid: str) -> Optional[POSSale]:
    """Get a POS sale by UUID."""
    return db.query(POSSale).filter(POSSale.sale_uuid == uuid).first()


def cancel_pos_sale(db: Session, sale_id: int, user_id: int) -> POSSale:
    """
    Cancel a POS sale and restore stock to the exact batches used.

    POSSaleItem.quantity is stored in base units, so restoring it keeps
    Medicine.quantity and Batch.quantity aligned with FEFO stock tracking.
    """
    sale = get_pos_sale_by_id(db, sale_id)
    if not sale:
        raise ValueError(f"Vente POS avec ID {sale_id} introuvable")

    if sale.status == "cancelled":
        raise ValueError(f"La vente POS {sale.code} est déjà annulée")

    try:
        for item in sale.items:
            medicine = item.medicine or db.query(Medicine).filter(
                Medicine.id == item.medicine_id
            ).first()
            batch = item.batch or db.query(Batch).filter(
                Batch.id == item.batch_id
            ).first()

            if medicine:
                medicine.quantity += item.quantity

            if batch:
                batch.quantity += item.quantity
                if batch.quantity > 0:
                    batch.is_active = True

                # Restore MedicinePricing stock
                pricing_entry = db.query(MedicinePricing).filter(
                    MedicinePricing.medicine_id == item.medicine_id,
                    MedicinePricing.lot == batch.batch_number
                ).first()
                if not pricing_entry:
                    pricing_entry = db.query(MedicinePricing).filter(
                        MedicinePricing.medicine_id == item.medicine_id
                    ).order_by(MedicinePricing.created_at.desc()).first()

                if pricing_entry:
                    pricing_entry.total_comprimes += item.quantity
                    _recalculate_pricing_quantities(pricing_entry)

            movement = StockMovement(
                medicine_id=item.medicine_id,
                batch_id=item.batch_id,
                type="annulation_vente",
                quantite=item.quantity,
                motif=f"Annulation vente POS",
                reference=sale.code,
            )
            db.add(movement)

        sale.status = "cancelled"
        sale.cancelled_at = datetime.now()
        sale.cancelled_by = user_id

        db.commit()
        db.refresh(sale)
        logger.info(f"POS Sale {sale.code} cancelled by user #{user_id}")
        return sale
    except Exception as e:
        db.rollback()
        logger.error(f"POS cancellation failed: {str(e)}")
        raise ValueError(f"Erreur lors de l'annulation POS: {str(e)}")


def enrich_pos_sale_response(sale: POSSale) -> dict:
    """
    Build a rich response dict for a POS sale, including item details.
    """
    items = []
    for item in sale.items:
        try:
            items.append(POSSaleItemResponse(
                id=item.id,
                medicine_id=item.medicine_id,
                medicine_name=item.medicine.name if item.medicine else "",
                medicine_code=item.medicine.code if item.medicine else "",
                batch_id=item.batch_id,
                batch_number=item.batch.batch_number if item.batch else "",
                expiration_date=item.batch.expiration_date if item.batch else None,
                quantity=item.quantity,
                unit_price=item.unit_price,
                total_price=item.total_price,
                discount_percent=item.discount_percent or 0.0,
            ))
        except Exception as e:
            logger.warning(f"POSSaleItemResponse failed for item #{getattr(item, 'id', '?')}: {e}")
    
    # Get user name - User model only has 'username', no first_name/last_name
    user_name = "Unknown"
    if sale.user:
        try:
            if hasattr(sale.user, 'first_name') and sale.user.first_name:
                user_name = f"{sale.user.first_name} {getattr(sale.user, 'last_name', '')}".strip()
            else:
                user_name = sale.user.username
        except Exception:
            user_name = "Unknown"

    # Calcul du bonus_earned : 1 point par 1000 FBu de la vente (si client fidélité)
    bonus_earned = 0.0
    if sale.customer_id:
        try:
            # 1 point de fidélité par tranche de 1000 FBu achetés
            bonus_earned = float(int(sale.total_amount / 1000))
        except Exception:
            bonus_earned = 0.0
    
    return {
        "id": sale.id,
        "uuid": sale.sale_uuid,
        "code": sale.code,
        "total_amount": sale.total_amount,
        "payment_method": sale.payment_method,
        "date": sale.date.isoformat() if sale.date else datetime.utcnow().isoformat(),
        "user_id": sale.user_id,
        "user_name": user_name,
        "status": sale.status,
        "cancelled_at": sale.cancelled_at.isoformat() if sale.cancelled_at else None,
        "cancelled_by": sale.cancelled_by_user.username if sale.cancelled_by_user else None,
        "customer_id": sale.customer_id,
        "customer_name": getattr(sale, 'customer_name', None),
        "items": [item.model_dump() for item in items],
        "bonus_earned": bonus_earned,
        "insurance_provider": sale.insurance_provider,
        "insurance_card_id": sale.insurance_card_id,
        "coverage_percent": sale.coverage_percent,
    }


def get_pos_sales_history(
    db: Session,
    page: int = 1,
    page_size: int = 50,
    start_date: Optional[str] = None,
    end_date: Optional[str] = None,
) -> Tuple[List[POSSale], int]:
    """
    Get POS sales history with pagination.
    """
    query = db.query(POSSale)
    
    if start_date:
        try:
            start_dt = datetime.strptime(start_date, "%Y-%m-%d")
            query = query.filter(POSSale.date >= start_dt)
        except ValueError:
            pass
    
    if end_date:
        try:
            end_dt = datetime.strptime(end_date, "%Y-%m-%d")
            end_dt = end_dt.replace(hour=23, minute=59, second=59)
            query = query.filter(POSSale.date <= end_dt)
        except ValueError:
            pass
    
    total = query.count()
    offset = (page - 1) * page_size

    from sqlalchemy.orm import joinedload, selectinload
    sales = (
        query
        .options(
            selectinload(POSSale.items).joinedload(POSSaleItem.medicine),
            selectinload(POSSale.items).joinedload(POSSaleItem.batch),
            joinedload(POSSale.user),
            joinedload(POSSale.cancelled_by_user),
        )
        .order_by(POSSale.date.desc())
        .offset(offset)
        .limit(page_size)
        .all()
    )
    
    return sales, total


# ============================================================================
# BATCH MANAGEMENT
# ============================================================================

def create_batch(db: Session, batch_data: BatchCreate) -> Batch:
    """
    Create a new batch for a medicine and update total stock.
    
    Args:
        db: Database session
        batch_data: Batch creation data
    
    Returns:
        Created Batch object
    
    Raises:
        ValueError: If medicine not found
    """
    medicine = db.query(Medicine).filter(Medicine.id == batch_data.medicine_id).first()
    if not medicine:
        raise ValueError(f"Médicament avec ID {batch_data.medicine_id} introuvable")
    
    batch = Batch(
        medicine_id=batch_data.medicine_id,
        batch_number=batch_data.batch_number,
        expiration_date=batch_data.expiration_date,
        quantity=batch_data.quantity,
        purchase_price=batch_data.purchase_price,
        is_active=True
    )
    db.add(batch)
    
    # Update medicine total stock
    medicine.quantity += batch_data.quantity
    
    db.commit()
    db.refresh(batch)
    
    logger.info(
        f"Batch {batch.batch_number} created for {medicine.name}. "
        f"Qty: {batch.quantity}, Exp: {batch.expiration_date}"
    )
    
    return batch


def get_batches_for_medicine(
    db: Session, 
    medicine_id: int,
    include_empty: bool = False
) -> List[Batch]:
    """
    Get all batches for a medicine, sorted FEFO.
    
    Args:
        db: Database session
        medicine_id: Medicine ID
        include_empty: If True, include batches with quantity=0
    
    Returns:
        List of Batch objects sorted by expiration_date ASC
    """
    query = db.query(Batch).filter(
        Batch.medicine_id == medicine_id,
        Batch.is_active == True
    )
    
    if not include_empty:
        query = query.filter(Batch.quantity > 0)
    
    return query.order_by(Batch.expiration_date.asc()).all()


def sync_medicine_stock(db: Session, medicine_id: int) -> float:
    """
    Sync Medicine.quantity with the sum of active batch quantities.
    
    Returns the updated total quantity.
    """
    total = db.query(func.sum(Batch.quantity)).filter(
        Batch.medicine_id == medicine_id,
        Batch.is_active == True
    ).scalar() or 0.0
    
    medicine = db.query(Medicine).filter(Medicine.id == medicine_id).first()
    if medicine:
        medicine.quantity = total
        db.commit()
    
    return total

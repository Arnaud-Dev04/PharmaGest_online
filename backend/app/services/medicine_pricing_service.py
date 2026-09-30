"""
Medicine Pricing service — Business logic for pricing CRUD and calculations.

CONNECTED SYSTEM: Creating a pricing entry auto-creates/updates:
  - Medicine (unique identity)
  - Batch (lot with expiry + stock)
  - StockMovement (journal entry)
"""

from sqlalchemy.orm import Session
from sqlalchemy import or_, and_, func
from datetime import date, timedelta, datetime
from typing import Optional, Tuple, List
import logging

from app.models.medicine_pricing import MedicinePricing
from app.models.medicine import Medicine
from app.models.batch import Batch
from app.models.stock_movement import StockMovement
from app.schemas.medicine_pricing import MedicinePricingCreate, MedicinePricingUpdate

logger = logging.getLogger("medicine_pricing_service")


# ============================================================================
# PRICE CALCULATION
# ============================================================================

def calculate_prices(data: MedicinePricingCreate) -> dict:
    """Calculate all prices and totals based on the pricing mode."""
    mode = data.prix_mode.value if hasattr(data.prix_mode, 'value') else data.prix_mode
    achat = data.achat_carton

    # Totals
    total_boites = data.nb_cartons * data.boites_par_carton
    total_plaquettes = total_boites * data.plaquettes_par_boite
    total_comprimes = total_plaquettes * data.comprimes_par_plaquette

    vente_carton = data.vente_carton
    vente_boite = data.vente_boite
    vente_plaquette = data.vente_plaquette
    vente_comprime = data.vente_comprime
    marge_pct = data.marge_pct

    if mode == "pct_marge":
        vente_carton = achat * (1 + (marge_pct or 0) / 100)
        vente_boite = vente_carton / data.boites_par_carton if data.boites_par_carton > 0 else 0
        vente_plaquette = vente_boite / data.plaquettes_par_boite if data.plaquettes_par_boite > 0 else 0
        vente_comprime = vente_plaquette / data.comprimes_par_plaquette if data.comprimes_par_plaquette > 0 else 0

    elif mode == "carton_fixe":
        vente_boite = vente_carton / data.boites_par_carton if data.boites_par_carton > 0 else 0
        vente_plaquette = vente_boite / data.plaquettes_par_boite if data.plaquettes_par_boite > 0 else 0
        vente_comprime = vente_plaquette / data.comprimes_par_plaquette if data.comprimes_par_plaquette > 0 else 0
        if achat > 0:
            marge_pct = ((vente_carton - achat) / achat) * 100

    # mode == "manuel": all prices already set by user

    # Benefit calculation
    valeur_achat_totale = data.nb_cartons * achat
    valeur_vente_totale = total_comprimes * vente_comprime
    benefice_estime = valeur_vente_totale - valeur_achat_totale

    # Calculate per-unit purchase prices
    # In manual mode, prefer user-entered PA values; otherwise auto-calculate
    if mode == "manuel":
        achat_boite = data.achat_boite if data.achat_boite > 0 else (
            achat / data.boites_par_carton if data.boites_par_carton > 0 else 0
        )
        achat_plaquette = data.achat_plaquette if data.achat_plaquette > 0 else (
            achat_boite / data.plaquettes_par_boite if data.plaquettes_par_boite > 0 else 0
        )
        achat_comprime = data.achat_comprime if data.achat_comprime > 0 else (
            achat_plaquette / data.comprimes_par_plaquette if data.comprimes_par_plaquette > 0 else 0
        )
    else:
        achat_boite = achat / data.boites_par_carton if data.boites_par_carton > 0 else 0
        achat_plaquette = achat_boite / data.plaquettes_par_boite if data.plaquettes_par_boite > 0 else 0
        achat_comprime = achat_plaquette / data.comprimes_par_plaquette if data.comprimes_par_plaquette > 0 else 0

    return {
        "vente_carton": round(vente_carton, 2),
        "vente_boite": round(vente_boite, 2),
        "vente_plaquette": round(vente_plaquette, 2),
        "vente_comprime": round(vente_comprime, 2),
        "marge_pct": round(marge_pct, 2) if marge_pct is not None else None,
        "benefice_estime": round(benefice_estime, 2),
        "total_boites": total_boites,
        "total_plaquettes": total_plaquettes,
        "total_comprimes": total_comprimes,
        # Multi-level purchase prices
        "achat_comprime": round(achat_comprime, 2),
        "achat_boite": round(achat_boite, 2),
        "achat_plaquette": round(achat_plaquette, 2),
    }


# ============================================================================
# AUTO CODE GENERATION
# ============================================================================

def _generate_medicine_code(db: Session) -> str:
    """Generate unique medicine code: MED-NNNN."""
    last = db.query(Medicine).order_by(Medicine.id.desc()).first()
    next_num = (last.id + 1) if last else 1
    return f"MED-{next_num:04d}"


# ============================================================================
# DUPLICATE DETECTION (R3/R4)
# ============================================================================

def _find_duplicate(db: Session, nom: str, lot: str) -> Optional[MedicinePricing]:
    """
    R3/R4: Check for existing pricing with same name + lot.
    Returns the existing entry if found.
    """
    return db.query(MedicinePricing).filter(
        func.lower(MedicinePricing.nom) == nom.strip().lower(),
        func.lower(MedicinePricing.lot) == lot.strip().lower(),
    ).first()


def _find_medicine_by_name(db: Session, nom: str) -> Optional[Medicine]:
    """Find an existing Medicine by normalized name."""
    return db.query(Medicine).filter(
        func.lower(Medicine.name) == nom.strip().lower(),
        Medicine.is_active == True,
    ).first()


# ============================================================================
# CREATE PRICING (CONNECTED SYSTEM)
# ============================================================================

def create_pricing(db: Session, data: MedicinePricingCreate) -> MedicinePricing:
    """
    Create a new pricing entry WITH automatic system connection.
    
    Flow:
    1. Calculate prices
    2. Check for duplicates (R3/R4)
       - Same name + same lot + same price → merge quantities
       - Same name + same lot + different price → update prices
       - New entry → create
    3. Find or create Medicine
    4. Create Batch
    5. Create StockMovement (type='entree')
    6. Create MedicinePricing with medicine_id
    """
    calculated = calculate_prices(data)
    
    # --- Step 1: Duplicate detection (R3/R4) ---
    existing = _find_duplicate(db, data.nom, data.lot)
    
    if existing:
        # R3: Same name + same lot → merge quantities
        logger.info(f"Doublon détecté: {data.nom} lot {data.lot} — fusion des quantités")
        
        existing.nb_cartons += data.nb_cartons
        existing.total_boites += calculated["total_boites"]
        existing.total_plaquettes += calculated["total_plaquettes"]
        existing.total_comprimes += calculated["total_comprimes"]
        
        # Update prices to latest values
        existing.achat_carton = data.achat_carton
        existing.vente_carton = calculated["vente_carton"]
        existing.vente_boite = calculated["vente_boite"]
        existing.vente_plaquette = calculated["vente_plaquette"]
        existing.vente_comprime = calculated["vente_comprime"]
        existing.marge_pct = calculated["marge_pct"]
        
        # Recalculate benefit
        valeur_achat = existing.nb_cartons * existing.achat_carton
        valeur_vente = existing.total_comprimes * existing.vente_comprime
        existing.benefice_estime = round(valeur_vente - valeur_achat, 2)
        
        # Update the linked Medicine stock
        if existing.medicine_id:
            medicine = db.query(Medicine).filter(Medicine.id == existing.medicine_id).first()
            if medicine:
                medicine.quantity += calculated["total_comprimes"]
                _update_medicine_prices(medicine, calculated, data)
        
        # Update existing Batch quantity (and always reactivate if it was deactivated after a sale)
        if existing.medicine_id:
            batch = db.query(Batch).filter(
                Batch.medicine_id == existing.medicine_id,
                func.lower(Batch.batch_number) == data.lot.strip().lower(),
            ).first()
            if batch:
                batch.quantity += calculated["total_comprimes"]
                batch.is_active = True  # Réactiver le lot s'il avait été désactivé lors d'une vente à 0
            else:
                batch = _create_batch(db, existing.medicine_id, data, calculated)
        
        # Create stock movement for the additional quantity
        if existing.medicine_id:
            _create_stock_movement(
                db, existing.medicine_id,
                batch.id if batch else None,
                existing.id,
                calculated["total_comprimes"],
                f"Fusion lot {data.lot} (+{calculated['total_comprimes']} unités)"
            )
        
        db.commit()
        db.refresh(existing)
        return existing
    
    # --- Step 2: Find or create Medicine ---
    medicine = None
    if getattr(data, 'medicine_id', None):
        medicine = db.query(Medicine).filter(Medicine.id == data.medicine_id).first()
    if not medicine:
        medicine = _find_medicine_by_name(db, data.nom)

    if medicine:
        # Existing medicine — update stock and prices
        medicine.quantity += calculated["total_comprimes"]
        _update_medicine_prices(medicine, calculated, data)
        logger.info(f"Medicine existant mis à jour: {medicine.name} (ID:{medicine.id})")
    else:
        # New medicine — create
        code = _generate_medicine_code(db)
        medicine = Medicine(
            code=code,
            name=data.nom.strip(),
            code_barres=None,
            dci=data.dci,
            forme_galenique=data.forme,
            dosage_form=data.forme,
            quantity=calculated["total_comprimes"],
            min_stock_alert=data.seuil_alerte,
            expiry_alert_threshold=data.alerte_jours or 30,
            is_active=True,
            # Conditionnement
            boxes_per_carton=data.boites_par_carton,
            blisters_per_box=data.plaquettes_par_boite,
            units_per_blister=data.comprimes_par_plaquette,
            units_per_packaging=data.plaquettes_par_boite * data.comprimes_par_plaquette,
            # Traçabilité
            lot_fabricant=data.lot,
            date_entree_stock=data.date_reception or date.today(),
            expiry_date=data.date_peremption,
            fournisseur=data.fournisseur,
            # Prix
            price_buy=calculated["achat_boite"],
            price_sell=calculated["vente_boite"],
            prix_achat_unite=calculated["achat_comprime"],
            prix_vente_unite=calculated["vente_comprime"],
            prix_achat_boite=calculated["achat_boite"],
            prix_vente_boite=calculated["vente_boite"],
            prix_achat_plaquette=calculated["achat_plaquette"],
            prix_vente_plaquette=calculated["vente_plaquette"],
            prix_achat_carton=data.achat_carton,
            prix_vente_carton=calculated["vente_carton"],
        )
        db.add(medicine)
        db.flush()  # Get medicine.id
        logger.info(f"Nouveau Medicine créé: {medicine.name} (code:{code}, ID:{medicine.id})")

    # --- Step 3: Create MedicinePricing entry ---
    entry = MedicinePricing(
        medicine_id=medicine.id,
        nom=data.nom.strip(),
        dci=data.dci,
        forme=data.forme,
        dosage=data.dosage,
        lot=data.lot.strip(),
        fournisseur=data.fournisseur,
        bon_livraison=data.bon_livraison,
        date_reception=data.date_reception,
        date_peremption=data.date_peremption,
        nb_cartons=data.nb_cartons,
        boites_par_carton=data.boites_par_carton,
        plaquettes_par_boite=data.plaquettes_par_boite,
        comprimes_par_plaquette=data.comprimes_par_plaquette,
        total_boites=calculated["total_boites"],
        total_plaquettes=calculated["total_plaquettes"],
        total_comprimes=calculated["total_comprimes"],
        prix_mode=data.prix_mode.value,
        achat_carton=data.achat_carton,
        achat_boite=calculated["achat_boite"],
        achat_plaquette=calculated["achat_plaquette"],
        achat_comprime=calculated["achat_comprime"],
        vente_carton=calculated["vente_carton"],
        vente_boite=calculated["vente_boite"],
        vente_plaquette=calculated["vente_plaquette"],
        vente_comprime=calculated["vente_comprime"],
        marge_pct=calculated["marge_pct"],
        benefice_estime=calculated["benefice_estime"],
        seuil_alerte=data.seuil_alerte,
        seuil_niveau=data.seuil_niveau,
        emplacement=data.emplacement,
        alerte_peremption=data.alerte_peremption,
        alerte_jours=data.alerte_jours if data.alerte_peremption else None,
        ordonnance=data.ordonnance.value,
    )
    db.add(entry)
    db.flush()

    # --- Step 4: Create Batch ---
    batch = _create_batch(db, medicine.id, data, calculated)

    # --- Step 5: Create StockMovement ---
    _create_stock_movement(
        db, medicine.id, batch.id, entry.id,
        calculated["total_comprimes"],
        f"Enregistrement lot {data.lot}"
    )

    db.commit()
    db.refresh(entry)
    
    logger.info(
        f"Pricing #{entry.id} créé pour {data.nom} — "
        f"Medicine #{medicine.id}, Batch #{batch.id}, "
        f"{calculated['total_comprimes']} unités"
    )
    
    return entry


def _update_medicine_prices(medicine: Medicine, calculated: dict, data: MedicinePricingCreate):
    """Update a Medicine's multi-level prices and traceability from a new pricing entry."""
    medicine.prix_achat_unite = calculated["achat_comprime"]
    medicine.prix_vente_unite = calculated["vente_comprime"]
    medicine.prix_achat_boite = calculated["achat_boite"]
    medicine.prix_vente_boite = calculated["vente_boite"]
    medicine.prix_achat_plaquette = calculated["achat_plaquette"]
    medicine.prix_vente_plaquette = calculated["vente_plaquette"]
    medicine.prix_achat_carton = data.achat_carton
    medicine.prix_vente_carton = calculated["vente_carton"]
    # Legacy compat
    medicine.price_buy = calculated["achat_boite"]
    medicine.price_sell = calculated["vente_boite"]
    # Traceability
    medicine.lot_fabricant = data.lot
    medicine.date_entree_stock = data.date_reception or date.today()
    medicine.fournisseur = data.fournisseur
    # Update conditionnement
    medicine.boxes_per_carton = data.boites_par_carton
    medicine.blisters_per_box = data.plaquettes_par_boite
    medicine.units_per_blister = data.comprimes_par_plaquette
    medicine.units_per_packaging = data.plaquettes_par_boite * data.comprimes_par_plaquette
    medicine.forme_galenique = data.forme
    medicine.dosage_form = data.forme
    if data.dci:
        medicine.dci = data.dci
    # Update expiry to nearest
    if data.date_peremption:
        if medicine.expiry_date is None or data.date_peremption < medicine.expiry_date:
            medicine.expiry_date = data.date_peremption
    medicine.is_active = True
    medicine.updated_at = datetime.utcnow()


def _create_batch(db: Session, medicine_id: int, data: MedicinePricingCreate, calculated: dict) -> Batch:
    """Create or update a Batch linked to a Medicine from pricing data (prevents duplicates)."""
    from datetime import timedelta
    
    # Check if a batch with the same lot number already exists for this medicine
    existing_batch = db.query(Batch).filter(
        Batch.medicine_id == medicine_id,
        func.lower(Batch.batch_number) == data.lot.strip().lower(),
    ).first()
    
    if existing_batch:
        existing_batch.quantity += calculated["total_comprimes"]
        existing_batch.is_active = True
        if data.date_peremption:
            existing_batch.expiration_date = data.date_peremption
        if calculated.get("achat_comprime"):
            existing_batch.purchase_price = calculated["achat_comprime"]
        db.flush()
        return existing_batch

    expiry = data.date_peremption or (date.today() + timedelta(days=730))
    
    batch = Batch(
        medicine_id=medicine_id,
        batch_number=data.lot.strip(),
        expiration_date=expiry,
        quantity=calculated["total_comprimes"],
        purchase_price=calculated["achat_comprime"],
        is_active=True,
    )
    db.add(batch)
    db.flush()
    return batch


def _create_stock_movement(
    db: Session,
    medicine_id: int,
    batch_id: Optional[int],
    pricing_id: Optional[int],
    quantite: int,
    motif: str,
):
    """Create a stock movement journal entry."""
    movement = StockMovement(
        medicine_id=medicine_id,
        batch_id=batch_id,
        pricing_id=pricing_id,
        type="entree",
        quantite=quantite,
        motif=motif,
        reference=f"PRICING-{pricing_id}" if pricing_id else None,
    )
    db.add(movement)


# ============================================================================
# READ
# ============================================================================

def get_pricings(
    db: Session,
    page: int = 1,
    page_size: int = 50,
    search: Optional[str] = None,
    out_of_stock_only: bool = False,
) -> Tuple[List[MedicinePricing], int]:
    """
    Get paginated pricing entries with optional search and out_of_stock filter.

    Optimisé pour les bases distantes (Aiven) :
    - joinedload(medicine) : charge la relation en 1 JOIN au lieu de N lazy queries
    - Sous-requête pour le count : évite un aller-retour Aiven supplémentaire
    """
    from sqlalchemy.orm import joinedload

    base_query = db.query(MedicinePricing)

    if out_of_stock_only:
        base_query = base_query.join(Medicine, MedicinePricing.medicine_id == Medicine.id, isouter=True)
        base_query = base_query.filter(
            or_(
                Medicine.quantity <= 0,
                and_(Medicine.id == None, MedicinePricing.total_comprimes <= 0)
            )
        )

    if search:
        search_term = f"%{search}%"
        base_query = base_query.filter(
            or_(
                MedicinePricing.nom.ilike(search_term),
                MedicinePricing.lot.ilike(search_term),
                MedicinePricing.fournisseur.ilike(search_term),
                MedicinePricing.dci.ilike(search_term),
            )
        )

    # COUNT séparé (inévitable pour la pagination)
    total = base_query.count()

    # Charge medicine en JOIN pour éviter le N+1 lazy loading
    order_clause = (
        (MedicinePricing.nom.asc(), MedicinePricing.created_at.desc())
        if out_of_stock_only
        else (MedicinePricing.created_at.desc(), MedicinePricing.id.desc())
    )
    entries = (
        base_query
        .options(joinedload(MedicinePricing.medicine))
        .order_by(*order_clause)
        .offset((page - 1) * page_size)
        .limit(page_size)
        .all()
    )

    return entries, total


def get_pricing_by_id(db: Session, pricing_id: int) -> Optional[MedicinePricing]:
    """Get a single pricing entry by ID."""
    return db.query(MedicinePricing).filter(MedicinePricing.id == pricing_id).first()


# ============================================================================
# UPDATE
# ============================================================================

def update_pricing(db: Session, pricing_id: int, data: MedicinePricingUpdate) -> Optional[MedicinePricing]:
    """
    Update a pricing entry and synchronize changes to Medicine, Batch, and POS.
    
    Ensures that when a user modifies a medicine:
    1. MedicinePricing fields & totals are recalculated
    2. Linked Medicine receives updated name, prices, conditioning, active status and timestamp
    3. Linked Batch receives updated batch number, expiry date, purchase price, and quantity
    4. POS immediately reflects the updated prices, stock, and status
    """
    entry = get_pricing_by_id(db, pricing_id)
    if not entry:
        return None

    old_lot = entry.lot
    old_total_comprimes = entry.total_comprimes or 0

    update_data = data.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        if hasattr(value, 'value'):  # Handle enums
            setattr(entry, field, value.value)
        else:
            setattr(entry, field, value)

    # Recalculate totals
    entry.total_boites = entry.nb_cartons * entry.boites_par_carton
    entry.total_plaquettes = entry.total_boites * entry.plaquettes_par_boite
    entry.total_comprimes = entry.total_plaquettes * entry.comprimes_par_plaquette

    # Recalculate prices based on mode
    achat = entry.achat_carton
    bpc = entry.boites_par_carton or 1
    ppb = entry.plaquettes_par_boite or 1
    cpp = entry.comprimes_par_plaquette or 1

    if entry.prix_mode == "pct_marge" and entry.marge_pct is not None:
        entry.vente_carton = round(achat * (1 + entry.marge_pct / 100), 2)
        entry.vente_boite = round(entry.vente_carton / bpc, 2)
        entry.vente_plaquette = round(entry.vente_boite / ppb, 2)
        entry.vente_comprime = round(entry.vente_plaquette / cpp, 2)
    elif entry.prix_mode == "carton_fixe":
        entry.vente_boite = round(entry.vente_carton / bpc, 2)
        entry.vente_plaquette = round(entry.vente_boite / ppb, 2)
        entry.vente_comprime = round(entry.vente_plaquette / cpp, 2)
        if achat > 0:
            entry.marge_pct = round(((entry.vente_carton - achat) / achat) * 100, 2)
    elif entry.prix_mode == "manuel":
        if not entry.vente_boite and entry.vente_carton:
            entry.vente_boite = round(entry.vente_carton / bpc, 2)
        if not entry.vente_plaquette and entry.vente_boite:
            entry.vente_plaquette = round(entry.vente_boite / ppb, 2)
        if not entry.vente_comprime and entry.vente_plaquette:
            entry.vente_comprime = round(entry.vente_plaquette / cpp, 2)

    # Calculate purchase prices per unit level
    entry.achat_boite = round(achat / bpc, 2)
    entry.achat_plaquette = round(entry.achat_boite / ppb, 2)
    entry.achat_comprime = round(entry.achat_plaquette / cpp, 2)

    # Recalculate benefit
    valeur_achat = entry.nb_cartons * entry.achat_carton
    valeur_vente = entry.total_comprimes * entry.vente_comprime
    entry.benefice_estime = round(valeur_vente - valeur_achat, 2)
    entry.updated_at = datetime.utcnow()

    # --- SYNCHRONIZATION WITH MEDICINE & BATCH (CRITICAL FOR POS) ---
    med_id = entry.medicine_id
    medicine = db.query(Medicine).filter(Medicine.id == med_id).first() if med_id else None
    if not medicine:
        medicine = _find_medicine_by_name(db, entry.nom)
        if medicine:
            entry.medicine_id = medicine.id

    if medicine:
        # 1. Update basic info & traceability
        medicine.name = entry.nom.strip()
        if entry.dci:
            medicine.dci = entry.dci.strip()
        if entry.forme:
            medicine.forme_galenique = entry.forme.strip()
            medicine.dosage_form = entry.forme.strip()
        if entry.fournisseur:
            medicine.fournisseur = entry.fournisseur.strip()

        # 2. Update packaging conditioning
        medicine.boxes_per_carton = entry.boites_par_carton
        medicine.blisters_per_box = entry.plaquettes_par_boite
        medicine.units_per_blister = entry.comprimes_par_plaquette
        medicine.units_per_packaging = entry.plaquettes_par_boite * entry.comprimes_par_plaquette

        # 3. Update all price levels (consumed by POS search_products and level checkout)
        medicine.prix_vente_unite = entry.vente_comprime
        medicine.prix_vente_plaquette = entry.vente_plaquette
        medicine.prix_vente_boite = entry.vente_boite
        medicine.prix_vente_carton = entry.vente_carton
        medicine.prix_achat_unite = entry.achat_comprime
        medicine.prix_achat_plaquette = entry.achat_plaquette
        medicine.prix_achat_boite = entry.achat_boite
        medicine.prix_achat_carton = entry.achat_carton
        medicine.price_sell = entry.vente_boite
        medicine.price_buy = entry.achat_boite

        # 4. Update traceability & alerts
        medicine.lot_fabricant = entry.lot.strip()
        if entry.date_reception:
            medicine.date_entree_stock = entry.date_reception
        if entry.date_peremption:
            medicine.expiry_date = entry.date_peremption
        medicine.min_stock_alert = entry.seuil_alerte or medicine.min_stock_alert
        medicine.is_active = True
        medicine.updated_at = datetime.utcnow()

        # 5. Update or create corresponding Batch
        batch = db.query(Batch).filter(
            Batch.medicine_id == medicine.id,
            or_(
                func.lower(Batch.batch_number) == entry.lot.strip().lower(),
                func.lower(Batch.batch_number) == old_lot.strip().lower()
            )
        ).first()

        qty_delta = entry.total_comprimes - old_total_comprimes

        if batch:
            batch.batch_number = entry.lot.strip()
            if entry.date_peremption:
                batch.expiration_date = entry.date_peremption
            batch.purchase_price = entry.achat_comprime
            batch.quantity = max(0.0, float(entry.total_comprimes))
            batch.is_active = True if batch.quantity > 0 else False
        else:
            batch = Batch(
                medicine_id=medicine.id,
                batch_number=entry.lot.strip(),
                expiration_date=entry.date_peremption or (date.today() + timedelta(days=730)),
                quantity=float(entry.total_comprimes),
                purchase_price=entry.achat_comprime,
                is_active=True if entry.total_comprimes > 0 else False,
            )
            db.add(batch)
            db.flush()

        # 6. Recalculate Medicine.quantity from all active batches
        total_batch_qty = db.query(func.sum(Batch.quantity)).filter(
            Batch.medicine_id == medicine.id,
            Batch.is_active == True
        ).scalar() or 0.0
        medicine.quantity = float(total_batch_qty)

        # 7. Log stock movement if quantity changed
        if qty_delta != 0:
            _create_stock_movement(
                db, medicine.id, batch.id if batch else None, entry.id,
                qty_delta,
                f"Modification pricing lot {entry.lot} ({'+' if qty_delta > 0 else ''}{qty_delta} unités)"
            )

    db.commit()
    db.refresh(entry)
    if medicine:
        db.refresh(medicine)
    logger.info(f"Pricing #{entry.id} mis à jour et synchronisé avec Medicine #{medicine.id if medicine else 'aucun'}")
    return entry



# ============================================================================
# DELETE
# ============================================================================

def delete_pricing(db: Session, pricing_id: int) -> bool:
    """
    Delete a pricing entry and synchronize stock:
    1. Delete corresponding Batch
    2. Deduct stock from Medicine.quantity
    3. Deactivate Medicine if no remaining pricing entries
    4. Record StockMovement
    """
    entry = get_pricing_by_id(db, pricing_id)
    if not entry:
        return False

    med_id = entry.medicine_id
    lot_number = entry.lot
    deleted_qty = entry.total_comprimes or 0

    # Delete matching batches
    if med_id:
        batches = db.query(Batch).filter(
            Batch.medicine_id == med_id,
            Batch.batch_number == lot_number
        ).all()
        for b in batches:
            db.delete(b)

        medicine = db.query(Medicine).filter(Medicine.id == med_id).first()
        if medicine:
            medicine.quantity = max(0, medicine.quantity - deleted_qty)

            # Check if any other pricing entries exist for this medicine
            remaining_pricing = db.query(MedicinePricing).filter(
                MedicinePricing.medicine_id == med_id,
                MedicinePricing.id != pricing_id
            ).first()

            if not remaining_pricing:
                # No more stock or pricing entries: deactivate medicine so it disappears from POS
                medicine.is_active = False
                medicine.quantity = 0

            # Record stock movement
            movement = StockMovement(
                medicine_id=med_id,
                type='suppression_stock',
                quantite=-deleted_qty,
                motif=f"Suppression lot {lot_number}",
                reference=f"DEL-PRICING-{pricing_id}"
            )
            db.add(movement)

    db.delete(entry)
    db.commit()
    logger.info(f"Pricing #{pricing_id} supprimé avec synchronisation Batch et Medicine")
    return True


# ============================================================================
# ALERTS
# ============================================================================

def get_pricing_alerts(db: Session) -> dict:
    """
    Get pricing entries with alerts (expiring soon, low stock, out of stock).
    Utilise joinedload(medicine) pour éviter le lazy loading N+1 dans enrich_pricing_response.
    """
    from sqlalchemy.orm import joinedload

    today = date.today()

    # Expiring soon : uniquement les entrées avec alerte activée
    pricing_entries = (
        db.query(MedicinePricing)
        .options(joinedload(MedicinePricing.medicine))
        .filter(
            MedicinePricing.date_peremption != None,
            MedicinePricing.alerte_peremption == True,
            MedicinePricing.alerte_jours != None,
        )
        .all()
    )

    expiring = []
    for entry in pricing_entries:
        if entry.date_peremption is None or entry.alerte_jours is None:
            continue
        cutoff = today + timedelta(days=entry.alerte_jours)
        if entry.date_peremption <= cutoff:
            expiring.append(entry)

    # Low stock
    low_stock = (
        db.query(MedicinePricing)
        .options(joinedload(MedicinePricing.medicine))
        .filter(
            MedicinePricing.total_comprimes > 0,
            MedicinePricing.total_comprimes <= MedicinePricing.seuil_alerte,
        )
        .all()
    )

    # Out of stock (rupture)
    out_of_stock = (
        db.query(MedicinePricing)
        .options(joinedload(MedicinePricing.medicine))
        .filter(MedicinePricing.total_comprimes <= 0)
        .all()
    )

    return {
        "expiring_soon": expiring,
        "low_stock": low_stock,
        "out_of_stock": out_of_stock,
        "total_alerts": len(expiring) + len(low_stock) + len(out_of_stock),
    }


# ============================================================================
# AUTOCOMPLETE
# ============================================================================

def get_autocomplete_names(db: Session, query: str, limit: int = 10) -> List[str]:
    """Get distinct medication names for autocomplete suggestions."""
    search_term = f"%{query}%"
    results = db.query(MedicinePricing.nom).filter(
        MedicinePricing.nom.ilike(search_term)
    ).distinct().limit(limit).all()
    return [r[0] for r in results]

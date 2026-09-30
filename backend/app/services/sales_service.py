"""
Sales service layer - Business logic for POS sales transactions.
"""

from sqlalchemy.orm import Session
from sqlalchemy import func, extract
from typing import List, Tuple, Optional
from datetime import datetime, date

from app.models.sales import Sale, SaleItem, PaymentMethod, SaleType
from app.models.medicine import Medicine
from app.models.user import User
from app.schemas.sales import SaleCreate, SaleItemCreate
from app.services import customer_service


# Constants
DEFAULT_BONUS_RATE = 0.05  # 5% bonus points


# ============================================================================
# STOCK VALIDATION
# ============================================================================

def calculate_sale_total(validated_items: List[dict]) -> float:
    """Calculate total sale amount from validated items."""
    total = 0.0
    for item in validated_items:
        medicine = item["medicine"]
        qty = item["quantity"]
        s_type = item["sale_type"]
        discount = item["discount_percent"]
        
        # Base price (Packaging/Box Price)
        box_price = medicine.price_sell
        total_units = medicine.units_per_packaging or 1
        
        unit_price = box_price / total_units
        
        final_unit_price = 0.0
        
        if s_type == "packaging": # Box
            final_unit_price = box_price
        elif s_type == "blister": # Plaquette
            final_unit_price = unit_price * (medicine.units_per_blister or 1)
        elif s_type == "unit": # Détail / Comprimé
            final_unit_price = unit_price
        elif s_type == "carton": # Carton
            final_unit_price = box_price * (medicine.boxes_per_carton or 1)
        else:
            # Fallback to box price if unknown type (compatibility)
            final_unit_price = box_price
            
        discounted_price = final_unit_price * (1 - discount / 100)
        total += discounted_price * qty
        
    return total


def validate_stock(db: Session, items: List[SaleItemCreate]) -> List[dict]:
    """
    Validate stock availability for all items.
    Returns list of items with fetched medicine objects.
    Raises ValueError if stock insufficient.
    """
    validated = []
    
    for item in items:
        medicine = db.query(Medicine).filter(Medicine.id == item.medicine_id).first()
        if not medicine:
            raise ValueError(f"Medicine with ID {item.medicine_id} not found")
            
        # Calculate required stock quantity in Base Units (Tablets)
        required_base_units = 0.0
        total_units = medicine.units_per_packaging or 1
        
        if item.sale_type == "packaging":
            required_base_units = float(item.quantity) * total_units
        elif item.sale_type == "blister":
            required_base_units = float(item.quantity) * (medicine.units_per_blister or 1)
        elif item.sale_type == "unit":
            required_base_units = float(item.quantity)
        elif item.sale_type == "carton":
            # Carton = Boxes * Units per Box
            boxes_in_carton = medicine.boxes_per_carton or 1
            required_base_units = float(item.quantity) * boxes_in_carton * total_units
        else:
            required_base_units = float(item.quantity) * total_units

        if medicine.quantity < required_base_units:
            # Format error message nicely
            available_boxes = medicine.quantity / total_units
            raise ValueError(
                f"Stock insuffisant pour {medicine.name}. "
                f"Requis: {required_base_units:.0f} unités, "
                f"Dispo: {medicine.quantity:.0f} unités ({available_boxes:.1f} boîtes)"
            )
            
        validated.append({
            "medicine": medicine,
            "quantity": item.quantity,
            "sale_type": item.sale_type,
            "discount_percent": item.discount_percent
        })
        
    return validated


# ============================================================================
# INVOICE CODE GENERATION
# ============================================================================

def generate_invoice_code(db: Session) -> str:
    """
    Generate unique invoice code in format: INV-YYYY-NNNN
    
    Args:
        db: Database session
        
    Returns:
        Invoice code (e.g., INV-2025-0001)
    """
    current_year = datetime.now().year
    
    from sqlalchemy import extract
    # Get the last invoice of the current year (compatible SQLite et MySQL)
    last_sale = db.query(Sale).filter(
        extract('year', Sale.date) == current_year
    ).order_by(Sale.id.desc()).first()
    
    if last_sale and last_sale.code:
        # Extract number from last code (INV-2025-0001 -> 0001)
        try:
            last_number = int(last_sale.code.split('-')[-1])
            next_number = last_number + 1
        except (ValueError, IndexError):
            next_number = 1
    else:
        next_number = 1
    
    # Format: INV-YYYY-NNNN
    return f"INV-{current_year}-{next_number:04d}"


# ============================================================================
# CALCULATIONS
# ============================================================================




def calculate_bonus_points(total_amount: float, bonus_rate: float = DEFAULT_BONUS_RATE) -> int:
    """
    Calculate bonus points from sale amount.
    
    Args:
        total_amount: Total sale amount
        bonus_rate: Bonus percentage (default 5%)
        
    Returns:
        Bonus points as integer
    """
    return int(total_amount * bonus_rate)


# ============================================================================
# STOCK UPDATES
# ============================================================================

def decrement_stock(db: Session, validated_items: List[Tuple[Medicine, SaleItemCreate]]):
    """
    Decrement medicine stock quantities.
    
    Args:
        db: Database session
        validated_items: List of (Medicine, SaleItemCreate) tuples
    """
    for medicine, item in validated_items:
        medicine.quantity -= item.quantity
    
    db.commit()


# ============================================================================
# SALE CREATION
# ============================================================================

def create_sale(db: Session, user_id: int, sale_data: SaleCreate) -> Sale:
    """
    Create a complete sale transaction.
    
    This function handles:
    1. Stock validation
    2. Customer creation/retrieval
    3. Total calculation
    4. Invoice code generation
    5. Sale and SaleItems creation
    6. Stock decrement
    7. Bonus points addition
    
    Args:
        db: Database session
        user_id: ID of the user making the sale
        sale_data: Sale creation data
        
    Returns:
        Created sale with all relationships loaded
        
    Raises:
        ValueError: If validation fails or insufficient stock
    """
    # 1. Validate stock availability
    validated_items = validate_stock(db, sale_data.items)
    
    # 2. Handle customer
    customer = None
    bonus_points = 0
    
    if sale_data.customer_id:
        # Get existing customer
        customer = customer_service.get_customer_by_id(db, sale_data.customer_id)
        if not customer:
             raise ValueError(f"Customer with ID {sale_data.customer_id} not found")
             
    elif sale_data.customer_phone:
        # Create or get by phone
        try:
            customer = customer_service.create_or_get_customer(
                db=db,
                phone=sale_data.customer_phone,
                first_name=sale_data.customer_first_name,
                last_name=sale_data.customer_last_name
            )
        except ValueError as e:
            raise ValueError(f"Customer error: {str(e)}")
    
    # 3. Calculate total
    total_amount = calculate_sale_total(validated_items)
    
    # Apply discount if provided
    discount_amount = 0.0
    if sale_data.discount_percent and sale_data.discount_percent > 0:
        discount_amount = total_amount * (sale_data.discount_percent / 100)
        total_amount -= discount_amount
    
    # 4. Calculate bonus points (if customer) - on discounted total
    if customer:
        bonus_points = calculate_bonus_points(total_amount)
    
    # 5. Generate invoice code
    invoice_code = generate_invoice_code(db)
    
    # 6. Create Sale
    sale = Sale(
        code=invoice_code,
        total_amount=total_amount,
        payment_method=sale_data.payment_method,
        date=datetime.utcnow(),
        user_id=user_id,
        customer_id=customer.id if customer else None,
        # Insurance details
        insurance_provider=sale_data.insurance_provider,
        insurance_card_id=sale_data.insurance_card_id,
        coverage_percent=sale_data.coverage_percent
    )
    db.add(sale)
    db.flush()  # Get sale.id without committing
    
    # Create Sale Items
    total_amount = 0.0
    db_items = []
    
    for item_data in validated_items:
        medicine = item_data["medicine"]
        qty_sold = item_data["quantity"]
        s_type = item_data["sale_type"]
        discount = item_data["discount_percent"]
        
        # Calculate Unit Price based on Sale Type
        box_price = medicine.price_sell
        total_units = medicine.units_per_packaging or 1
        unit_price_base = box_price / total_units
        
        final_unit_price = 0.0
        decrement_base_units = 0.0
        
        if s_type == "packaging":
            final_unit_price = box_price
            decrement_base_units = float(qty_sold) * total_units
        elif s_type == "blister":
            final_unit_price = unit_price_base * (medicine.units_per_blister or 1)
            decrement_base_units = float(qty_sold) * (medicine.units_per_blister or 1)
        elif s_type == "unit":
            final_unit_price = unit_price_base
            decrement_base_units = float(qty_sold)
        elif s_type == "carton":
            final_unit_price = box_price * (medicine.boxes_per_carton or 1)
            decrement_base_units = float(qty_sold) * (medicine.boxes_per_carton or 1) * total_units
        else:
            final_unit_price = box_price
            decrement_base_units = float(qty_sold) * total_units
        
        # Apply Discount
        final_unit_price = final_unit_price * (1 - discount / 100)
        
        # Calculate Line Total
        line_total = final_unit_price * qty_sold
        
        # Create Sale Item
        sale_item = SaleItem(
            sale_id=sale.id,
            medicine_id=medicine.id,
            quantity=qty_sold,
            unit_price=final_unit_price,
            total_price=line_total,
            sale_type=s_type,
            discount_percent=discount
        )
        db.add(sale_item)
        db_items.append(sale_item)
        total_amount += line_total
        
        # Decrement Stock (Base Units)
        medicine.quantity -= decrement_base_units
        
        # Basic check for negative stock (optional, but good for safety)
        if medicine.quantity < 0:
             # In a strict system, we might block. Here we allow but maybe warn?
             # For now, let's allow it as inventory correction might happen later.
             pass
             
    # Update Sale Total
    sale.total_amount = total_amount
    db.commit()
    db.refresh(sale)
    
    # Calculate bonus points for customer (based on total amount)
    if sale.customer:
        points = calculate_bonus_points(sale.total_amount)
        if points > 0:
            # customer_service is already imported globally
            customer_service.add_bonus_points(
                db, 
                sale.customer_id, 
                points
            )
            
    return sale


# ============================================================================
# SALE RETRIEVAL
# ============================================================================

def get_sale_by_id(db: Session, sale_id: int) -> Optional[Sale]:
    """
    Get a sale by ID with all relationships loaded.
    
    Args:
        db: Database session
        sale_id: Sale ID
        
    Returns:
        Sale with items and customer, or None
    """
    return db.query(Sale).filter(Sale.id == sale_id).first()


def get_invoice_data(db: Session, sale_id: int) -> Optional[dict]:
    """
    Get invoice data formatted for PDF generation.
    
    Args:
        db: Database session
        sale_id: Sale ID
        
    Returns:
        Invoice data dictionary or None
    """
    sale = get_sale_by_id(db, sale_id)
    if not sale:
        return None
    
    # Format items
    items = []
    for item in sale.items:
        items.append({
            "medicine_name": item.medicine.name,
            "medicine_code": item.medicine.code,
            "quantity": item.quantity,
            "unit_price": item.unit_price,
            "total_price": item.total_price
        })
    
    # Format customer
    customer_data = None
    if sale.customer:
        customer_data = {
            "name": f"{sale.customer.first_name} {sale.customer.last_name}",
            "phone": sale.customer.phone,
            "points_earned": calculate_bonus_points(sale.total_amount)
        }
    
    return {
        "invoice_code": sale.code,
        "date": sale.date,
        "total_amount": sale.total_amount,
        "payment_method": sale.payment_method.value if hasattr(sale.payment_method, 'value') else sale.payment_method,
        "items": items,
        "customer": customer_data,
        "seller": sale.user.username if sale.user else "Unknown"
    }


def get_sales_history(
    db: Session,
    page: int = 1,
    page_size: int = 50,
    filters: Optional[dict] = None
) -> Tuple[List[Sale], int]:
    """
    Get sales history with pagination and filters.
    
    Args:
        db: Database session
        page: Page number
        page_size: Items per page
        filters: Dictionary with filter values (start_date, end_date, user_id, min/max amount)
    
    Returns:
        Tuple of (sales list, total count)
    """
    query = db.query(Sale)
    
    if filters:
        if filters.get("start_date"):
            # Convert date to start of day datetime
            start_dt = datetime.combine(filters["start_date"], datetime.min.time())
            query = query.filter(Sale.date >= start_dt)
        
        if filters.get("end_date"):
            # Convert date to end of day datetime
            end_dt = datetime.combine(filters["end_date"], datetime.max.time())
            query = query.filter(Sale.date <= end_dt)
        
        if filters.get("user_id"):
            query = query.filter(Sale.user_id == filters["user_id"])
            
        if filters.get("min_amount") is not None:
            query = query.filter(Sale.total_amount >= filters["min_amount"])
            
        if filters.get("max_amount") is not None:
            query = query.filter(Sale.total_amount <= filters["max_amount"])
            
        if filters.get("status"):
            query = query.filter(Sale.status == filters["status"])
    
    # Get total count
    total = query.count()
    
    # Apply pagination and sorting (newest first) with eager loading
    from sqlalchemy.orm import joinedload, selectinload
    offset = (page - 1) * page_size
    sales = (
        query
        .options(
            selectinload(Sale.items).joinedload(SaleItem.medicine),
            joinedload(Sale.customer),
            joinedload(Sale.user),
            joinedload(Sale.cancelled_by_user),
        )
        .order_by(Sale.date.desc())
        .offset(offset)
        .limit(page_size)
        .all()
    )
    
    return sales, total


def get_user_stats(
    db: Session, 
    user_id: int, 
    start_date: Optional[str] = None, 
    end_date: Optional[str] = None
) -> dict:
    """
    Get detailed sales statistics for a specific user.
    """
    from app.models.pos_sale import POSSale, POSSaleItem

    # Base query for user's completed sales in POS
    query = db.query(POSSale).filter(
        POSSale.user_id == user_id,
        POSSale.status != "cancelled"
    )

    # Apply date filters
    if start_date:
        try:
            start_dt = datetime.strptime(start_date, "%Y-%m-%d")
            query = query.filter(POSSale.date >= start_dt)
        except ValueError:
            pass
            
    if end_date:
        try:
            end_dt = datetime.strptime(end_date, "%Y-%m-%d")
            # End of day
            end_dt = end_dt.replace(hour=23, minute=59, second=59)
            query = query.filter(POSSale.date <= end_dt)
        except ValueError:
            pass

    sales = query.all()

    # Calculate aggregate stats
    total_sales = len(sales)
    total_revenue = sum(s.total_amount for s in sales)
    average_sale = total_revenue / total_sales if total_sales > 0 else 0
    
    # Unique customers served
    customers_served = len(set(s.customer_id for s in sales if s.customer_id))

    # Top products calculation
    # We join POSSaleItem -> Medicine
    top_products_query = db.query(
        Medicine.id,
        Medicine.name,
        Medicine.code,
        func.sum(POSSaleItem.quantity).label('total_qty'),
        func.sum(POSSaleItem.total_price).label('total_rev')
    ).join(POSSaleItem, POSSaleItem.medicine_id == Medicine.id).join(POSSale, POSSale.id == POSSaleItem.sale_id).filter(
        POSSale.user_id == user_id,
        POSSale.status != "cancelled"
    )

    if start_date:
        try:
            start_dt = datetime.strptime(start_date, "%Y-%m-%d")
            top_products_query = top_products_query.filter(POSSale.date >= start_dt)
        except ValueError: pass
    
    if end_date:
        try:
            end_dt = datetime.strptime(end_date, "%Y-%m-%d").replace(hour=23, minute=59, second=59)
            top_products_query = top_products_query.filter(POSSale.date <= end_dt)
        except ValueError: pass

    top_products_results = top_products_query.group_by(
        Medicine.id, Medicine.name, Medicine.code
    ).order_by(func.sum(POSSaleItem.quantity).desc()).limit(5).all()

    top_products = [
        {
            "medicine_id": r.id,
            "medicine_name": r.name,
            "medicine_code": r.code,
            "quantity_sold": int(r.total_qty or 0),
            "revenue_generated": float(r.total_rev or 0)
        }
        for r in top_products_results
    ]

    # Sales by date (for chart)
    # Group by date
    sales_by_date = {}
    for s in sales:
        d = s.date.strftime("%Y-%m-%d")
        if d not in sales_by_date:
            sales_by_date[d] = 0.0
        sales_by_date[d] += s.total_amount
    
    chart_data = [
        {"date": k, "revenue": v} 
        for k, v in sorted(sales_by_date.items())
    ]

    # Get user details
    user = db.query(User).filter(User.id == user_id).first()

    return {
        "user_id": user_id,
        "username": user.username if user else "Unknown",
        "total_sales": total_sales,
        "total_revenue": total_revenue,
        "average_sale_amount": average_sale,
        "customers_served": customers_served,
        "top_products": top_products,
        "sales_by_date": chart_data
    }

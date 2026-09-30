"""
POS Routes — API endpoints for Point of Sale operations.

Endpoints:
    GET  /pos/products/search   — Search products with batch info
    POST /pos/cart/add          — Calculate FEFO allocation for cart
    POST /pos/checkout          — Finalize sale, deduct stock per batch
    GET  /pos/sale/{sale_id}    — Get POS sale details
    GET  /pos/history           — POS sales history
    POST /pos/batches           — Create a new batch (admin)
    GET  /pos/batches/{med_id}  — Get batches for a medicine
"""

from fastapi import APIRouter, Depends, HTTPException, status, Query, Request
from fastapi.exceptions import RequestValidationError
from sqlalchemy.orm import Session
from typing import Optional
import logging

from app.database import get_local_db
from app.models.user import User
from app.auth.dependencies import get_current_active_user, get_admin_user
from app.services import pos_service
from app.schemas.pos import (
    CartAddRequest, CartAddResponse,
    POSCheckoutRequest, POSSaleResponse,
    ProductSearchResult,
    BatchCreate, BatchResponse,
)

# Create router
router = APIRouter()
logger = logging.getLogger("pos_routes")


# ============================================================================
# LEGACY STOCK SYNC
# ============================================================================

@router.post(
    "/sync-stock",
    summary="Sync legacy stock — auto-create batches for medicines without any"
)
async def sync_stock(
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_local_db)
):
    """Force sync: create default batches for medicines with stock but no batches."""
    try:
        created = pos_service.sync_legacy_stock(db)
        return {"message": f"{created} lot(s) auto-créé(s)", "created": created}
    except Exception as e:
        logger.error(f"sync_stock failed: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Erreur sync: {str(e)}")


# ============================================================================
# PRODUCT SEARCH
# ============================================================================

import time as _pos_time

_pos_search_cache = {}
_pos_top_cache = {}
_POS_CACHE_TTL = 30  # secondes


def invalidate_pos_cache():
    global _pos_search_cache, _pos_top_cache
    _pos_search_cache.clear()
    _pos_top_cache.clear()


@router.get(
    "/products/search",
    response_model=list[ProductSearchResult],
    summary="Search products for POS (with batch info)"
)
async def search_products(
    q: str = Query("", description="Search query (name or code). Empty = all products"),
    limit: int = Query(1000, ge=1, le=2000, description="Max results"),
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_local_db)
):
    """
    Search products by name or code for POS use.
    Mis en cache 30s quand la recherche est vide pour éviter de recharger 1000 produits sur Aiven.
    """
    now = _pos_time.time()
    cache_key = f"{limit}"
    if not q.strip() and cache_key in _pos_search_cache and (now - _pos_search_cache[cache_key]["ts"]) < _POS_CACHE_TTL:
        return _pos_search_cache[cache_key]["data"]

    results = pos_service.search_products(db, q, limit)
    if not q.strip():
        _pos_search_cache[cache_key] = {"data": results, "ts": now}
    return results


@router.get(
    "/products/top",
    response_model=list[ProductSearchResult],
    summary="Get top/frequent products"
)
async def get_top_products(
    limit: int = Query(10, ge=1, le=20, description="Max results"),
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_local_db)
):
    """
    Get most frequently sold products for quick access.
    Mis en cache 30s.
    """
    try:
        now = _pos_time.time()
        cache_key = f"{limit}"
        if cache_key in _pos_top_cache and (now - _pos_top_cache[cache_key]["ts"]) < _POS_CACHE_TTL:
            return _pos_top_cache[cache_key]["data"]

        results = pos_service.get_top_products(db, limit)
        _pos_top_cache[cache_key] = {"data": results, "ts": now}
        return results
    except Exception as e:
        logger.error(f"get_top_products failed: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Erreur chargement produits fréquents: {str(e)}"
        )


# ============================================================================
# CART OPERATIONS
# ============================================================================

@router.post(
    "/cart/add",
    response_model=CartAddResponse,
    summary="Calculate FEFO allocation for cart item"
)
async def cart_add(
    request: CartAddRequest,
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_local_db)
):
    """
    Calculate which batches will be used for a given product quantity.
    
    Uses FEFO (First Expired First Out): allocates from the batch with
    the earliest expiration date first. If one batch doesn't have enough,
    it moves to the next batch.
    
    This is a **read-only** operation — no stock is deducted.
    The frontend stores the allocations and sends them at checkout.
    
    **Accessible to**: All authenticated users
    
    **Errors**:
    - 400: Insufficient stock or no available batches
    - 404: Medicine not found
    """
    try:
        result = pos_service.cart_add(db, request)
        return result
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )


@router.post(
    "/cart/remove",
    summary="Remove item from cart (frontend-managed)"
)
async def cart_remove(
    medicine_id: int,
    current_user: User = Depends(get_current_active_user),
):
    """
    Cart removal is handled entirely on the frontend.
    
    This endpoint exists for API completeness but simply returns success.
    The frontend manages the cart state and removes items locally.
    """
    return {"status": "ok", "message": "Cart is managed on frontend"}


# ============================================================================
# CHECKOUT
# ============================================================================

@router.post(
    "/checkout",
    response_model=dict,
    status_code=status.HTTP_201_CREATED,
    summary="Finalize POS sale — deduct stock per batch"
)
async def checkout(
    checkout_data: POSCheckoutRequest,
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_local_db)
):
    """
    Finalize a POS sale transaction.
    
    This endpoint:
    1. Validates all batch allocations have sufficient stock
    2. Creates a POS sale with UUID for future sync
    3. Creates sale items linked to specific batches
    4. Deducts stock per batch (not global)
    5. Updates medicine total quantity
    6. All within a single atomic transaction
    
    **Accessible to**: All authenticated users
    
    **Errors**:
    - 400: Insufficient stock, expired batch, or validation error
    - 404: Medicine or batch not found
    """
    try:
        sale = pos_service.checkout(
            db=db,
            user_id=current_user.id,
            checkout_data=checkout_data
        )
        invalidate_pos_cache()
        return pos_service.enrich_pos_sale_response(sale)
        
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )
    except RequestValidationError as e:
        # Erreurs de validation Pydantic (ex: allocations vides, champs manquants)
        error_msgs = [f"{err['loc']}: {err['msg']}" for err in e.errors()]
        logger.warning(f"Checkout validation error: {error_msgs}")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Données invalides: {'; '.join(error_msgs)}"
        )
    except Exception as e:
        import traceback
        logger.error(f"Checkout unexpected error: {type(e).__name__}: {str(e)}")
        logger.error(traceback.format_exc())
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Erreur checkout: {type(e).__name__}: {str(e)}"
        )


# ============================================================================
# SALE RETRIEVAL
# ============================================================================

@router.get(
    "/sale/{sale_id}",
    response_model=dict,
    summary="Get POS sale details"
)
async def get_pos_sale(
    sale_id: int,
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_local_db)
):
    """
    Get details of a specific POS sale, including batch allocations.
    
    **Accessible to**: All authenticated users
    """
    sale = pos_service.get_pos_sale_by_id(db, sale_id)
    if not sale:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Vente POS avec ID {sale_id} introuvable"
        )
    
    return pos_service.enrich_pos_sale_response(sale)


@router.post(
    "/sale/{sale_id}/cancel",
    response_model=dict,
    summary="Cancel POS sale and restore batch stock"
)
async def cancel_pos_sale(
    sale_id: int,
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_local_db)
):
    """
    Cancel a POS sale, restore sold quantities to their original batches,
    and keep an audit trail in stock movements.
    """
    try:
        sale = pos_service.cancel_pos_sale(
            db=db,
            sale_id=sale_id,
            user_id=current_user.id,
        )
        from app.services import audit_service
        audit_service.log_deletion(
            db=db,
            action="CANCEL_SALE",
            entity_type="sale",
            entity_id=sale.id,
            entity_name=f"Facture {sale.code}",
            user=current_user,
            details=f"Annulation vente POS de {sale.total_amount:.0f} FBu",
        )
        return pos_service.enrich_pos_sale_response(sale)
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )


@router.get(
    "/history",
    summary="Get POS sales history"
)
async def get_pos_history(
    page: int = Query(1, ge=1),
    page_size: int = Query(50, ge=1, le=100),
    start_date: Optional[str] = Query(None, description="Start date (YYYY-MM-DD)"),
    end_date: Optional[str] = Query(None, description="End date (YYYY-MM-DD)"),
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_local_db)
):
    """
    Get POS sales history with pagination and date filters.
    
    **Accessible to**: All authenticated users
    """
    sales, total = pos_service.get_pos_sales_history(
        db=db,
        page=page,
        page_size=page_size,
        start_date=start_date,
        end_date=end_date
    )
    
    enriched = [pos_service.enrich_pos_sale_response(s) for s in sales]
    
    return {
        "total": total,
        "page": page,
        "page_size": page_size,
        "total_pages": (total + page_size - 1) // page_size,
        "items": enriched
    }


# ============================================================================
# BATCH MANAGEMENT
# ============================================================================

@router.post(
    "/batches",
    response_model=BatchResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create a new batch/lot for a medicine"
)
async def create_batch(
    batch_data: BatchCreate,
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_local_db)
):
    """
    Create a new batch (lot) for a medicine.
    
    This also updates the medicine's total stock quantity.
    
    **Accessible to**: All authenticated users (Admin recommended)
    """
    try:
        batch = pos_service.create_batch(db, batch_data)
        
        return BatchResponse(
            id=batch.id,
            medicine_id=batch.medicine_id,
            medicine_name=batch.medicine.name if batch.medicine else "",
            batch_number=batch.batch_number,
            expiration_date=batch.expiration_date,
            quantity=batch.quantity,
            purchase_price=batch.purchase_price,
            is_active=batch.is_active,
            created_at=batch.created_at,
            updated_at=batch.updated_at
        )
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )


@router.get(
    "/batches/{medicine_id}",
    response_model=list[BatchResponse],
    summary="Get batches for a medicine"
)
async def get_batches(
    medicine_id: int,
    include_empty: bool = Query(False, description="Include empty batches"),
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_local_db)
):
    """
    Get all active batches for a medicine, sorted FEFO.
    
    **Accessible to**: All authenticated users
    """
    batches = pos_service.get_batches_for_medicine(db, medicine_id, include_empty)
    
    return [
        BatchResponse(
            id=b.id,
            medicine_id=b.medicine_id,
            medicine_name=b.medicine.name if b.medicine else "",
            batch_number=b.batch_number,
            expiration_date=b.expiration_date,
            quantity=b.quantity,
            purchase_price=b.purchase_price,
            is_active=b.is_active,
            created_at=b.created_at,
            updated_at=b.updated_at
        )
        for b in batches
    ]


# ============================================================================
# SALES STATISTICS & PERFORMANCE BY USER & PERIOD
# ============================================================================

@router.get(
    "/user-sales-summary",
    summary="Get user sales performance by period (self or all accounts for admin)"
)
async def get_user_sales_summary(
    start_date: Optional[str] = Query(None, description="Start date (YYYY-MM-DD)"),
    end_date: Optional[str] = Query(None, description="End date (YYYY-MM-DD)"),
    user_id: Optional[int] = Query(None, description="Filter specific user (Admin only for other users)"),
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_local_db)
):
    """
    Get sales revenue statistics by period.
    - Cashiers/Pharmacists: see their own sales total and list for the period.
    - Admins: see all accounts breakdown or a specific user's detailed performance.
    """
    from datetime import datetime, timedelta
    from app.models.pos_sale import POSSale
    from app.models.user import User as UserModel
    from sqlalchemy import func, desc

    is_admin = current_user.role in ["admin", "super_admin"]

    # Security check: non-admin can only see themselves
    if not is_admin:
        if user_id is not None and user_id != current_user.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Vous n'avez pas l'autorisation de consulter les ventes d'autres utilisateurs."
            )
        target_user_id = current_user.id
    else:
        target_user_id = user_id

    # Parse date filters
    s_dt = None
    e_dt = None
    if start_date:
        try:
            s_dt = datetime.strptime(start_date, "%Y-%m-%d")
        except ValueError:
            pass
    if end_date:
        try:
            e_dt = datetime.strptime(end_date, "%Y-%m-%d") + timedelta(days=1)
        except ValueError:
            pass

    # If target_user_id is None and user is Admin -> return all users breakdown
    if target_user_id is None and is_admin:
        # Base query for all completed sales in period
        sale_query = db.query(POSSale).filter(POSSale.status != "cancelled")
        if s_dt:
            sale_query = sale_query.filter(POSSale.date >= s_dt)
        if e_dt:
            sale_query = sale_query.filter(POSSale.date < e_dt)

        all_completed_sales = sale_query.all()
        grand_revenue = float(sum(s.total_amount for s in all_completed_sales))
        grand_count = len(all_completed_sales)

        # Get all users (or users who made sales)
        all_users = db.query(UserModel).filter(UserModel.is_active == True).all()

        users_summary = []
        for u in all_users:
            u_sales = [s for s in all_completed_sales if s.user_id == u.id]
            u_rev = float(sum(s.total_amount for s in u_sales))
            u_count = len(u_sales)
            avg_basket = round(u_rev / u_count, 2) if u_count > 0 else 0.0
            pct_total = round((u_rev / grand_revenue) * 100, 1) if grand_revenue > 0 else 0.0
            last_sale = max([s.date for s in u_sales]) if u_sales else None

            users_summary.append({
                "user_id": u.id,
                "username": u.username,
                "full_name": getattr(u, 'full_name', '') or u.username,
                "role": u.role,
                "total_sales_count": u_count,
                "total_revenue": u_rev,
                "average_basket": avg_basket,
                "percentage_of_total": pct_total,
                "last_sale_date": last_sale.isoformat() if last_sale else None,
            })

        # Sort users by revenue descending
        users_summary.sort(key=lambda x: x["total_revenue"], reverse=True)

        return {
            "is_admin_view": True,
            "period": {"start_date": start_date, "end_date": end_date},
            "grand_total": {
                "total_revenue": grand_revenue,
                "total_sales_count": grand_count,
                "average_basket": round(grand_revenue / grand_count, 2) if grand_count > 0 else 0.0,
            },
            "users_summary": users_summary,
        }

    # Otherwise -> single user detailed summary
    user_obj = db.query(UserModel).filter(UserModel.id == target_user_id).first()
    if not user_obj:
        raise HTTPException(status_code=404, detail="Utilisateur introuvable")

    query = db.query(POSSale).filter(
        POSSale.user_id == target_user_id,
        POSSale.status != "cancelled"
    )
    if s_dt:
        query = query.filter(POSSale.date >= s_dt)
    if e_dt:
        query = query.filter(POSSale.date < e_dt)

    sales = query.order_by(desc(POSSale.date)).all()

    total_revenue = float(sum(s.total_amount for s in sales))
    sales_count = len(sales)
    avg_basket = round(total_revenue / sales_count, 2) if sales_count > 0 else 0.0

    # Group daily totals
    daily_map = {}
    for s in sales:
        d_str = s.date.strftime("%Y-%m-%d")
        if d_str not in daily_map:
            daily_map[d_str] = {"date": d_str, "revenue": 0.0, "count": 0}
        daily_map[d_str]["revenue"] += s.total_amount
        daily_map[d_str]["count"] += 1

    daily_list = sorted(daily_map.values(), key=lambda x: x["date"], reverse=True)

    # Recent sales preview
    recent_sales = [
        {
            "id": s.id,
            "code": s.code,
            "total_amount": s.total_amount,
            "date": s.date.isoformat() if s.date else None,
            "payment_method": s.payment_method,
            "items_count": len(s.items) if s.items else 0,
        }
        for s in sales[:50]
    ]

    return {
        "is_admin_view": is_admin,
        "user": {
            "id": user_obj.id,
            "username": user_obj.username,
            "full_name": getattr(user_obj, 'full_name', '') or user_obj.username,
            "role": user_obj.role,
        },
        "period": {"start_date": start_date, "end_date": end_date},
        "summary": {
            "total_revenue": total_revenue,
            "total_sales_count": sales_count,
            "average_basket": avg_basket,
        },
        "sales_by_day": daily_list,
        "recent_sales": recent_sales,
    }


# ============================================================================
# TOP MEDICINES REPORT (VOLUME & PROFITABILITY / GAIN D'ARGENT)
# ============================================================================

@router.get(
    "/reports/top-medicines",
    summary="Get top selling medicines by volume and profitability across all accounts"
)
async def get_top_medicines_report(
    start_date: Optional[str] = Query(None, description="Start date (YYYY-MM-DD)"),
    end_date: Optional[str] = Query(None, description="End date (YYYY-MM-DD)"),
    sort_by: str = Query("quantity", pattern="^(quantity|profit|revenue)$", description="Sort by: quantity, profit, or revenue"),
    limit: int = Query(50, ge=1, le=500, description="Max results"),
    current_user: User = Depends(get_admin_user),
    db: Session = Depends(get_local_db)
):
    """
    Get top selling medicines across all accounts:
    - By volume (quantité vendue)
    - By net profit (gain d'argent = chiffre d'affaires - coût d'achat)
    - By total revenue (chiffre d'affaires)
    """
    from datetime import datetime, timedelta
    from app.models.pos_sale import POSSale, POSSaleItem
    from app.models.medicine import Medicine
    from app.models.batch import Batch
    from sqlalchemy import func, desc

    s_dt = None
    e_dt = None
    if start_date:
        try:
            s_dt = datetime.strptime(start_date, "%Y-%m-%d")
        except ValueError:
            pass
    if end_date:
        try:
            e_dt = datetime.strptime(end_date, "%Y-%m-%d") + timedelta(days=1)
        except ValueError:
            pass

    # Query items joining POSSale, Medicine, and Batch
    cost_expr = POSSaleItem.quantity * func.coalesce(Batch.purchase_price, Medicine.prix_achat_unite, 0.0)
    profit_expr = POSSaleItem.total_price - cost_expr

    query = db.query(
        Medicine.id.label("medicine_id"),
        Medicine.name.label("name"),
        Medicine.code.label("code"),
        Medicine.forme_galenique.label("forme"),
        Medicine.dosage_form.label("dosage"),
        func.sum(POSSaleItem.quantity).label("total_quantity"),
        func.sum(POSSaleItem.total_price).label("total_revenue"),
        func.sum(cost_expr).label("total_cost"),
        func.sum(profit_expr).label("total_profit"),
        func.count(func.distinct(POSSale.id)).label("sales_count"),
    ).join(
        POSSale, POSSale.id == POSSaleItem.sale_id
    ).join(
        Medicine, Medicine.id == POSSaleItem.medicine_id
    ).outerjoin(
        Batch, Batch.id == POSSaleItem.batch_id
    ).filter(
        POSSale.status != "cancelled"
    )

    if s_dt:
        query = query.filter(POSSale.date >= s_dt)
    if e_dt:
        query = query.filter(POSSale.date < e_dt)

    query = query.group_by(
        Medicine.id, Medicine.name, Medicine.code, Medicine.forme_galenique, Medicine.dosage_form
    )

    if sort_by == "profit":
        query = query.order_by(desc("total_profit"))
    elif sort_by == "revenue":
        query = query.order_by(desc("total_revenue"))
    else:
        query = query.order_by(desc("total_quantity"))

    rows = query.limit(limit).all()

    # Calculate overall stats
    grand_qty = sum(int(r.total_quantity or 0) for r in rows)
    grand_rev = sum(float(r.total_revenue or 0.0) for r in rows)
    grand_profit = sum(float(r.total_profit or 0.0) for r in rows)

    top_qty_name = rows[0].name if rows else "N/A"
    top_profit_name = sorted(rows, key=lambda x: float(x.total_profit or 0.0), reverse=True)[0].name if rows else "N/A"

    items = []
    for rank, r in enumerate(rows, 1):
        rev = float(r.total_revenue or 0.0)
        cost = float(r.total_cost or 0.0)
        profit = float(r.total_profit or 0.0)
        qty = int(r.total_quantity or 0)
        margin = round((profit / rev) * 100, 1) if rev > 0 else 0.0

        items.append({
            "rank": rank,
            "medicine_id": r.medicine_id,
            "name": r.name,
            "code": r.code or "N/A",
            "forme": r.forme or "",
            "dosage": r.dosage or "",
            "total_quantity": qty,
            "total_revenue": rev,
            "total_cost": cost,
            "total_profit": profit,
            "margin_percent": margin,
            "sales_count": int(r.sales_count or 0),
        })

    return {
        "period": {"start_date": start_date, "end_date": end_date},
        "sort_by": sort_by,
        "summary": {
            "total_quantity_sold": grand_qty,
            "total_revenue": grand_rev,
            "total_profit": grand_profit,
            "top_quantity_name": top_qty_name,
            "top_profit_name": top_profit_name,
        },
        "items": items,
    }


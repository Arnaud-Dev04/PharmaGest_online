"""Analytics and business intelligence routes for pharmacy owners."""

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session
from sqlalchemy import func, desc, case
from typing import List, Optional
from datetime import datetime, timedelta, date

from app.database import get_local_db
from app.models.user import User
from app.models.pos_sale import POSSale, POSSaleItem
from app.models.medicine import Medicine
from app.auth.dependencies import get_admin_user

router = APIRouter(prefix="/analyse", tags=["Analyse"])


@router.get("/finance")
def get_finance_analysis(
    current_user: User = Depends(get_admin_user),
    db: Session = Depends(get_local_db),
):
    """Monthly revenue and margins analysis for the last 12 months."""
    pharmacy_id = current_user.pharmacy_id
    if not pharmacy_id:
        raise HTTPException(status_code=400, detail="Utilisateur non rattaché à une pharmacie")

    # Fetch last 12 months of POS sales
    twelve_months_ago = datetime.utcnow() - timedelta(days=365)
    sales = (
        db.query(
            func.date_format(POSSale.created_at, "%Y-%m").label("month"),
            func.coalesce(func.sum(POSSale.total_amount), 0.0).label("revenue"),
            func.count(POSSale.id).label("sale_count"),
        )
        .filter(
            POSSale.pharmacy_id == pharmacy_id,
            POSSale.created_at >= twelve_months_ago,
            POSSale.status != "cancelled",
        )
        .group_by("month")
        .order_by("month")
        .all()
    )

    monthly_stats = [
        {
            "month": row.month,
            "revenue": float(row.revenue or 0.0),
            "sale_count": int(row.sale_count or 0),
        }
        for row in sales
    ]

    total_rev = sum(m["revenue"] for m in monthly_stats)
    total_sales = sum(m["sale_count"] for m in monthly_stats)

    return {
        "monthly_revenue": monthly_stats,
        "total_revenue_12m": total_rev,
        "total_sales_12m": total_sales,
        "average_monthly_revenue": total_rev / max(1, len(monthly_stats)),
    }


@router.get("/stock")
def get_stock_analysis(
    current_user: User = Depends(get_admin_user),
    db: Session = Depends(get_local_db),
):
    """Stock health, rotation rates, and slow-moving items."""
    pharmacy_id = current_user.pharmacy_id
    if not pharmacy_id:
        raise HTTPException(status_code=400, detail="Utilisateur non rattaché à une pharmacie")

    # Query all medicines for this pharmacy
    meds = db.query(Medicine).filter(Medicine.pharmacy_id == pharmacy_id).all()

    total_stock_value_purchase = sum((m.quantity or 0) * (m.price_buy or 0.0) for m in meds)
    total_stock_value_sale = sum((m.quantity or 0) * (m.price_sell or 0.0) for m in meds)
    low_stock_count = sum(1 for m in meds if (m.quantity or 0) <= (m.min_stock_alert or 5))

    # Identify slow-moving items: products in stock with no recent sales in last 60 days
    sixty_days_ago = datetime.utcnow() - timedelta(days=60)
    recent_sold_ids = {
        item.medicine_id
        for item in db.query(POSSaleItem.medicine_id)
        .join(POSSale, POSSaleItem.sale_id == POSSale.id)
        .filter(POSSale.pharmacy_id == pharmacy_id, POSSale.created_at >= sixty_days_ago)
        .distinct()
        .all()
    }

    slow_movers = [
        {
            "id": m.id,
            "name": m.name,
            "current_stock": m.quantity,
            "purchase_price": float(m.price_buy or 0.0),
            "sell_price": float(m.price_sell or 0.0),
            "stock_value": float((m.quantity or 0) * (m.price_buy or 0.0)),
        }
        for m in meds
        if m.id not in recent_sold_ids and (m.quantity or 0) > 0
    ][:20]

    return {
        "total_medicines": len(meds),
        "total_stock_value_purchase": total_stock_value_purchase,
        "total_stock_value_sale": total_stock_value_sale,
        "potential_margin": total_stock_value_sale - total_stock_value_purchase,
        "low_stock_count": low_stock_count,
        "slow_movers_count": len(slow_movers),
        "slow_movers": slow_movers,
    }


@router.get("/vendors")
def get_vendors_performance(
    current_user: User = Depends(get_admin_user),
    db: Session = Depends(get_local_db),
):
    """Vendor / cashier performance stats."""
    pharmacy_id = current_user.pharmacy_id
    if not pharmacy_id:
        raise HTTPException(status_code=400, detail="Utilisateur non rattaché à une pharmacie")

    stats = (
        db.query(
            POSSale.user_id,
            User.username,
            User.first_name,
            User.last_name,
            func.count(POSSale.id).label("sale_count"),
            func.coalesce(func.sum(POSSale.total_amount), 0.0).label("total_revenue"),
        )
        .join(User, POSSale.user_id == User.id)
        .filter(
            POSSale.pharmacy_id == pharmacy_id,
            POSSale.status != "cancelled",
        )
        .group_by(POSSale.user_id, User.username, User.first_name, User.last_name)
        .order_by(desc("total_revenue"))
        .all()
    )

    return [
        {
            "cashier_id": row.user_id, "user_id": row.user_id,
            "cashier_name": f"{row.first_name or ''} {row.last_name or ''}".strip() or row.username,
            "username": row.username,
            "sale_count": int(row.sale_count or 0),
            "total_revenue": float(row.total_revenue or 0.0),
            "average_basket": float((row.total_revenue or 0.0) / max(1, row.sale_count or 1)),
        }
        for row in stats
    ]


@router.get("/products")
def get_products_analysis(
    current_user: User = Depends(get_admin_user),
    db: Session = Depends(get_local_db),
):
    """Top selling and most profitable products."""
    pharmacy_id = current_user.pharmacy_id
    if not pharmacy_id:
        raise HTTPException(status_code=400, detail="Utilisateur non rattaché à une pharmacie")

    top_by_volume = (
        db.query(
            Medicine.id,
            Medicine.name,
            func.coalesce(func.sum(POSSaleItem.quantity), 0).label("total_quantity"),
            func.coalesce(func.sum(POSSaleItem.total_price), 0.0).label("total_revenue"),
        )
        .join(POSSale, POSSaleItem.sale_id == POSSale.id)
        .join(Medicine, POSSaleItem.medicine_id == Medicine.id)
        .filter(POSSale.pharmacy_id == pharmacy_id, POSSale.status != "cancelled")
        .group_by(Medicine.id, Medicine.name)
        .order_by(desc("total_quantity"))
        .limit(10)
        .all()
    )

    top_by_revenue = (
        db.query(
            Medicine.id,
            Medicine.name,
            func.coalesce(func.sum(POSSaleItem.quantity), 0).label("total_quantity"),
            func.coalesce(func.sum(POSSaleItem.total_price), 0.0).label("total_revenue"),
        )
        .join(POSSale, POSSaleItem.sale_id == POSSale.id)
        .join(Medicine, POSSaleItem.medicine_id == Medicine.id)
        .filter(POSSale.pharmacy_id == pharmacy_id, POSSale.status != "cancelled")
        .group_by(Medicine.id, Medicine.name)
        .order_by(desc("total_revenue"))
        .limit(10)
        .all()
    )

    return {
        "top_by_volume": [
            {
                "id": r.id,
                "name": r.name,
                "quantity": int(r.total_quantity or 0),
                "revenue": float(r.total_revenue or 0.0),
            }
            for r in top_by_volume
        ],
        "top_by_revenue": [
            {
                "id": r.id,
                "name": r.name,
                "quantity": int(r.total_quantity or 0),
                "revenue": float(r.total_revenue or 0.0),
            }
            for r in top_by_revenue
        ],
    }


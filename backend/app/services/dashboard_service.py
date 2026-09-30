"""
Dashboard service layer - Analytics and aggregation logic.
"""

from sqlalchemy.orm import Session
from sqlalchemy import func, and_, cast, Date
from datetime import datetime, timedelta, date
from typing import List, Dict, Any

from app.models.medicine import Medicine
from app.models.medicine_pricing import MedicinePricing
from app.models.sales import Sale
from app.models.pos_sale import POSSale, POSSaleItem


from typing import Optional

def get_stats(db: Session, start_date: Optional[str] = None, end_date: Optional[str] = None) -> Dict[str, Any]:
    """
    Get key metrics for the dashboard.

    Optimise pour les bases distantes (Aiven) : les requetes sont groupees
    en un minimum d'aller-retours reseau.
    Avant : ~15 requetes separees  ->  Apres : ~6 requetes groupees.
    """
    import traceback
    from sqlalchemy import case

    today = date.today()
    week_ago = today - timedelta(days=7)

    # ── 1. Stats medicaments (1 requete = total + expires + stock bas) ───────
    try:
        med_rows = db.query(
            func.count(Medicine.id).label("total"),
            func.sum(
                case((and_(Medicine.expiry_date.isnot(None), Medicine.expiry_date <= today), 1), else_=0)
            ).label("expired"),
            func.sum(
                case((Medicine.quantity <= Medicine.min_stock_alert, 1), else_=0)
            ).label("low_stock"),
        ).filter(Medicine.is_active == True).one()
        total_medicines     = int(med_rows.total    or 0)
        expired_medicines   = int(med_rows.expired  or 0)
        low_stock_medicines = int(med_rows.low_stock or 0)
    except Exception:
        print("Error getting medicine stats:")
        traceback.print_exc()
        total_medicines = expired_medicines = low_stock_medicines = 0

    # ── 2. Stats ventes legacy (1 requete = count + revenue + weekly) ────────
    try:
        sale_rows = db.query(
            func.count(Sale.id).label("total_count"),
            func.sum(Sale.total_amount).label("total_revenue"),
            func.sum(
                case((func.date(Sale.date) >= week_ago, Sale.total_amount), else_=0)
            ).label("weekly"),
        ).filter(Sale.status == "completed").one()
        legacy_count   = int(sale_rows.total_count   or 0)
        legacy_revenue = float(sale_rows.total_revenue or 0)
        legacy_weekly  = float(sale_rows.weekly       or 0)
    except Exception:
        print("Error getting legacy sale stats:")
        traceback.print_exc()
        legacy_count = legacy_revenue = legacy_weekly = 0

    # ── 3. Stats ventes POS (1 requete = count + revenue + weekly) ───────────
    try:
        pos_rows = db.query(
            func.count(POSSale.id).label("total_count"),
            func.sum(POSSale.total_amount).label("total_revenue"),
            func.sum(
                case((func.date(POSSale.date) >= week_ago, POSSale.total_amount), else_=0)
            ).label("weekly"),
        ).filter(POSSale.status == "completed").one()
        pos_count   = int(pos_rows.total_count   or 0)
        pos_revenue = float(pos_rows.total_revenue or 0)
        pos_weekly  = float(pos_rows.weekly       or 0)
    except Exception:
        print("Error getting POS sale stats:")
        traceback.print_exc()
        pos_count = pos_revenue = pos_weekly = 0

    total_sales_count = legacy_count + pos_count
    total_revenue     = legacy_revenue + pos_revenue
    weekly_sales      = legacy_weekly + pos_weekly

    # ── 4. Total fournisseurs ────────────────────────────────────────────────
    try:
        from app.models.supplier import Supplier
        total_suppliers = db.query(func.count(Supplier.id)).scalar() or 0
    except Exception:
        print("Error getting total suppliers:")
        traceback.print_exc()
        total_suppliers = 0

    # ── 5. Ventes annulees ───────────────────────────────────────────────────
    try:
        from app.models.sales import SaleStatus
        legacy_cancel_q = db.query(func.count(Sale.id)).filter(Sale.status == SaleStatus.CANCELLED)
        pos_cancel_q    = db.query(func.count(POSSale.id)).filter(POSSale.status == "cancelled")
        if start_date and end_date:
            dt_start_obj = datetime.strptime(start_date, "%Y-%m-%d").date()
            dt_end_obj   = datetime.strptime(end_date,   "%Y-%m-%d").date()
            legacy_cancel_q = legacy_cancel_q.filter(
                func.date(Sale.date) >= dt_start_obj,
                func.date(Sale.date) <= dt_end_obj,
            )
            pos_cancel_q = pos_cancel_q.filter(
                func.date(POSSale.date) >= dt_start_obj,
                func.date(POSSale.date) <= dt_end_obj,
            )
        cancelled_sales = (legacy_cancel_q.scalar() or 0) + (pos_cancel_q.scalar() or 0)
    except Exception:
        print("Error getting cancelled sales:")
        traceback.print_exc()
        cancelled_sales = 0

    # ── 6. Ventes recentes ───────────────────────────────────────────────────
    try:
        recent_sales = []
        for sale in (db.query(Sale)
                     .filter(Sale.status == "completed")
                     .order_by(Sale.date.desc()).limit(5).all()):
            recent_sales.append({
                "id": sale.id, "code": sale.code,
                "total_amount": float(sale.total_amount),
                "date": sale.date.isoformat() if sale.date else None,
            })
        for sale in (db.query(POSSale)
                     .filter(POSSale.status == "completed")
                     .order_by(POSSale.date.desc()).limit(5).all()):
            recent_sales.append({
                "id": sale.id, "code": sale.code,
                "total_amount": float(sale.total_amount),
                "date": sale.date.isoformat() if sale.date else None,
            })
        recent_sales.sort(key=lambda item: item.get("date") or "", reverse=True)
        recent_sales = recent_sales[:5]
    except Exception:
        print("Error getting recent sales:")
        traceback.print_exc()
        recent_sales = []

    # ── 7. Medicaments expirant bientot ─────────────────────────────────────
    try:
        candidates = db.query(Medicine).filter(
            Medicine.expiry_date > today,
            Medicine.is_active == True,
        ).order_by(Medicine.expiry_date).limit(50).all()
        expiring_soon_data = [
            m for m in candidates
            if m.expiry_date and m.expiry_date <= today + timedelta(days=m.expiry_alert_threshold or 30)
        ][:10]
        expiring_soon = [
            {"name": m.name, "code": m.code, "expiry_date": m.expiry_date, "quantity": m.quantity}
            for m in expiring_soon_data
        ]
    except Exception:
        print("Error getting expiring soon:")
        traceback.print_exc()
        expiring_soon = []

    # ── 8. Detail stock bas ──────────────────────────────────────────────────
    try:
        low_stock_list = [
            {"name": m.name, "code": m.code, "quantity": m.quantity, "min_stock": m.min_stock_alert}
            for m in db.query(Medicine).filter(
                Medicine.quantity <= Medicine.min_stock_alert,
                Medicine.is_active == True,
            ).order_by(Medicine.quantity.asc()).limit(10).all()
        ]
    except Exception:
        print("Error getting low stock list:")
        traceback.print_exc()
        low_stock_list = []

    # ── 9. Valeur inventaire (1 requete = purchase + sell) ───────────────────
    try:
        inv_rows = db.query(
            func.sum(MedicinePricing.achat_comprime * MedicinePricing.total_comprimes).label("purchase"),
            func.sum(MedicinePricing.vente_comprime  * MedicinePricing.total_comprimes).label("sell"),
        ).one()
        total_purchase_value = float(inv_rows.purchase or 0)
        total_sell_value     = float(inv_rows.sell     or 0)
    except Exception:
        print("Error computing inventory totals:")
        traceback.print_exc()
        total_purchase_value = total_sell_value = 0.0

    # ── 10. Agregations temporelles ──────────────────────────────────────────
    try:
        if start_date and end_date:
            dt_start_obj = datetime.strptime(start_date, "%Y-%m-%d").date()
            dt_end_obj   = datetime.strptime(end_date,   "%Y-%m-%d").date()
            days_range   = (dt_end_obj - dt_start_obj).days + 1
        else:
            days_range = 7
        sales_by_day  = get_sales_by_day_of_week(db, days=days_range)
        sales_by_hour = get_sales_by_hour(db, days=days_range)
        top_products  = get_top_selling_products(db, limit=15, start_date=start_date, end_date=end_date)
        revenue_chart = get_revenue_chart_data(db, days=days_range, start_date=start_date, end_date=end_date)
    except Exception:
        print("Error computing aggregated sales/time series:")
        traceback.print_exc()
        sales_by_day = sales_by_hour = top_products = revenue_chart = []

    return {
        "total_medicines":      total_medicines,
        "total_sales_count":    total_sales_count,
        "weekly_sales":         float(weekly_sales),
        "total_suppliers":      total_suppliers,
        "expired_medicines":    expired_medicines,
        "expiring_soon_count":  len(expiring_soon),
        "low_stock_medicines":  low_stock_medicines,
        "total_revenue":        float(total_revenue),
        "cancelled_sales":      cancelled_sales,
        "recent_sales":         recent_sales,
        "expiring_soon":        expiring_soon,
        "sales_by_day":         sales_by_day,
        "sales_by_hour":        sales_by_hour,
        "top_selling_products": top_products,
        "low_stock_list":       low_stock_list,
        "total_purchase_value": float(total_purchase_value),
        "total_sell_value":     float(total_sell_value),
        "revenue_chart":        revenue_chart,
    }


def get_cancelled_sales_details(db: Session, limit: int = 50, start_date: Optional[str] = None, end_date: Optional[str] = None) -> List[Dict[str, Any]]:
    """
    Get detailed list of cancelled sales.
    """
    try:
        from app.models.sales import Sale, SaleStatus
        from app.models.user import User
        
        query = db.query(Sale, User).outerjoin(
            User, Sale.cancelled_by == User.id
        ).filter(
            Sale.status == SaleStatus.CANCELLED
        )
        
        if start_date and end_date:
            dt_start_obj = datetime.strptime(start_date, "%Y-%m-%d").date()
            dt_end_obj = datetime.strptime(end_date, "%Y-%m-%d").date()
            query = query.filter(
                func.date(Sale.date) >= dt_start_obj,
                func.date(Sale.date) <= dt_end_obj
            )
            
        query = query.order_by(
            Sale.cancelled_at.desc()
        ).limit(limit)
        
        results = query.all()
        
        detailed_sales = []
        for sale, canceller in results:
            sale_items = []
            for item in sale.items:
                sale_items.append({
                    "medicine_name": item.medicine.name if item.medicine else "Unknown"
                })

            # Determine name to display
            # Request: "je veux un nom complet de l'utilisateur"
            user_name = "N/A"
            if canceller:
                if canceller.first_name and canceller.last_name:
                    user_name = f"{canceller.first_name} {canceller.last_name}"
                elif canceller.username:
                    user_name = canceller.username
            
            detailed_sales.append({
                "id": sale.id,
                "user_id": sale.user_id, # Original seller
                "user_name": user_name, # The one who cancelled
                "date": sale.date,
                "cancelled_at": sale.cancelled_at,
                "total_amount": sale.total_amount,
                "items": sale_items
            })

        pos_query = db.query(POSSale, User).outerjoin(
            User, POSSale.cancelled_by == User.id
        ).filter(
            POSSale.status == "cancelled"
        )

        if start_date and end_date:
            pos_query = pos_query.filter(
                func.date(POSSale.date) >= dt_start_obj,
                func.date(POSSale.date) <= dt_end_obj
            )

        for sale, canceller in pos_query.order_by(POSSale.cancelled_at.desc()).limit(limit).all():
            sale_items = [
                {"medicine_name": item.medicine.name if item.medicine else "Unknown"}
                for item in sale.items
            ]

            user_name = "N/A"
            if canceller:
                if getattr(canceller, "first_name", None) and getattr(canceller, "last_name", None):
                    user_name = f"{canceller.first_name} {canceller.last_name}"
                elif canceller.username:
                    user_name = canceller.username

            detailed_sales.append({
                "id": sale.id,
                "user_id": sale.user_id,
                "user_name": user_name,
                "date": sale.date,
                "cancelled_at": sale.cancelled_at,
                "total_amount": sale.total_amount,
                "items": sale_items
            })

        detailed_sales.sort(
            key=lambda sale: sale.get("cancelled_at") or datetime.min,
            reverse=True,
        )
            
        return detailed_sales[:limit]
    except Exception:
        import traceback
        print("Error getting cancelled sales details:")
        traceback.print_exc()
        return []


def get_revenue_chart_data(db: Session, days: int = 7, start_date: Optional[str] = None, end_date: Optional[str] = None) -> List[Dict[str, Any]]:
    """
    Get daily revenue for the last N days.
    
    Args:
        db: Database session
        days: Number of days to verify (default 7)
        
    Returns:
        List of dicts with 'date' and 'amount'
    """
    try:
        if start_date and end_date:
            # Use provided range
            dt_start_obj = datetime.strptime(start_date, "%Y-%m-%d").date()
            dt_end_obj = datetime.strptime(end_date, "%Y-%m-%d").date()
            start_date_val = dt_start_obj
            end_date_val = dt_end_obj
        else:
            # Use last N days
            end_date_val = date.today()
            start_date_val = end_date_val - timedelta(days=days - 1)
        
        daily_sales = db.query(
            func.date(Sale.date).label('sale_date'),
            func.sum(Sale.total_amount).label('total')
        ).filter(
            func.date(Sale.date) >= start_date_val,
            func.date(Sale.date) <= end_date_val,
            Sale.status == 'completed'
        ).group_by(
            func.date(Sale.date)
        ).all()
        daily_pos_sales = db.query(
            func.date(POSSale.date).label('sale_date'),
            func.sum(POSSale.total_amount).label('total')
        ).filter(
            func.date(POSSale.date) >= start_date_val,
            func.date(POSSale.date) <= end_date_val,
            POSSale.status == 'completed'
        ).group_by(
            func.date(POSSale.date)
        ).all()
        
        # Convert result to dict
        sales_map = {str(d[0]): float(d[1] or 0) for d in daily_sales}
        for sale_date, total in daily_pos_sales:
            key = str(sale_date)
            sales_map[key] = sales_map.get(key, 0.0) + float(total or 0)
        
        # Generate full list
        chart_data = []
        current_date = start_date_val
        while current_date <= end_date_val:
            date_str = current_date.isoformat()
            chart_data.append({
                "date": date_str,
                "amount": sales_map.get(date_str, 0.0)
            })
            current_date += timedelta(days=1)
            
        return chart_data
    except Exception:
        import traceback
        print("Error getting revenue chart data:")
        traceback.print_exc()
        return []


def get_top_selling_products(db: Session, limit: int = 15, start_date: Optional[str] = None, end_date: Optional[str] = None) -> List[Dict[str, Any]]:
    """
    Get top selling products/medicines.
    
    Args:
        db: Database session
        limit: Number of top products to return (default 5)
        
    Returns:
        List of dicts with medicine info and total sold quantity
    """
    from app.models.sales import SaleItem
    
    try:
        # Group sale items by medicine and sum quantities (completed sales only)
        query = db.query(
            Medicine.id,
            Medicine.name,
            Medicine.code,
            func.sum(SaleItem.quantity).label('total_sold')
        ).join(
            SaleItem, SaleItem.medicine_id == Medicine.id
        ).join(
            Sale, SaleItem.sale_id == Sale.id
        ).filter(
            Sale.status == 'completed'
        )
        
        if start_date and end_date:
            dt_start_obj = datetime.strptime(start_date, "%Y-%m-%d").date()
            dt_end_obj = datetime.strptime(end_date, "%Y-%m-%d").date()
            query = query.filter(
                func.date(Sale.date) >= dt_start_obj,
                func.date(Sale.date) <= dt_end_obj
            )
            
        top_products = query.group_by(
            Medicine.id, Medicine.name, Medicine.code
        ).order_by(
            func.sum(SaleItem.quantity).desc()
        ).limit(limit).all()

        products_map = {
            p.id: {
                "id": p.id,
                "name": p.name,
                "code": p.code,
                "total_sold": int(p.total_sold or 0),
            }
            for p in top_products
        }

        pos_query = db.query(
            Medicine.id,
            Medicine.name,
            Medicine.code,
            func.sum(POSSaleItem.quantity).label('total_sold')
        ).join(
            POSSaleItem, POSSaleItem.medicine_id == Medicine.id
        ).join(
            POSSale, POSSaleItem.sale_id == POSSale.id
        ).filter(
            POSSale.status == 'completed'
        )

        if start_date and end_date:
            pos_query = pos_query.filter(
                func.date(POSSale.date) >= dt_start_obj,
                func.date(POSSale.date) <= dt_end_obj
            )

        for p in pos_query.group_by(Medicine.id, Medicine.name, Medicine.code).all():
            if p.id not in products_map:
                products_map[p.id] = {
                    "id": p.id,
                    "name": p.name,
                    "code": p.code,
                    "total_sold": 0,
                }
            products_map[p.id]["total_sold"] += int(p.total_sold or 0)

        return sorted(
            products_map.values(),
            key=lambda item: item["total_sold"],
            reverse=True,
        )[:limit]
    except Exception:
        import traceback
        print("Error getting top selling products:")
        traceback.print_exc()
        return []


def get_sales_by_day_of_week(db: Session, days: int = 7) -> List[Dict[str, Any]]:
    """
    Aggregate sales by day of week.
    Returns list of {day: "Monday", amount: 123.0}
    """
    try:
        from app.models.sales import Sale
        from datetime import datetime, time

        start_dt = datetime.combine(date.today() - timedelta(days=days - 1), time.min)

        days_map = {
            '0': 'Sunday', '1': 'Monday', '2': 'Tuesday', '3': 'Wednesday', 
            '4': 'Thursday', '5': 'Friday', '6': 'Saturday'
        }
        results_dict = {str(i): 0.0 for i in range(7)}

        # Legacy sales
        sales = db.query(Sale.date, Sale.total_amount).filter(
            Sale.date >= start_dt,
            Sale.status == 'completed'
        ).all()
        for s_date, total in sales:
            if s_date:
                dow = s_date.strftime('%w')
                results_dict[dow] += float(total or 0.0)

        # POS sales
        pos_sales = db.query(POSSale.date, POSSale.total_amount).filter(
            POSSale.date >= start_dt,
            POSSale.status == 'completed'
        ).all()
        for s_date, total in pos_sales:
            if s_date:
                dow = s_date.strftime('%w')
                results_dict[dow] += float(total or 0.0)

        return [{"day": days_map[str(i)], "amount": round(results_dict[str(i)], 2)} for i in range(7)]

    except Exception:
        import traceback
        print("Error getting sales by day of week:")
        traceback.print_exc()
        return []


def get_sales_by_hour(db: Session, days: int = 7) -> List[Dict[str, Any]]:
    """
    Aggregate sales by hour of day.
    Returns list of {hour: 0-23, amount: 123.0}
    """
    try:
        from app.models.sales import Sale
        from datetime import datetime, time

        start_dt = datetime.combine(date.today() - timedelta(days=days - 1), time.min)
        results_dict = {h: 0.0 for h in range(24)}

        sales = db.query(Sale.date, Sale.total_amount).filter(
            Sale.date >= start_dt,
            Sale.status == 'completed'
        ).all()
        for s_date, total in sales:
            if s_date:
                results_dict[s_date.hour] += float(total or 0.0)

        pos_sales = db.query(POSSale.date, POSSale.total_amount).filter(
            POSSale.date >= start_dt,
            POSSale.status == 'completed'
        ).all()
        for s_date, total in pos_sales:
            if s_date:
                results_dict[s_date.hour] += float(total or 0.0)

        return [{"hour": h, "amount": round(results_dict[h], 2)} for h in range(24)]

    except Exception:
        import traceback
        print("Error getting sales by hour:")
        traceback.print_exc()
        return []


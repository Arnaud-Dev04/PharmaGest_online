"""
Notification and alert service for proactive inventory and license monitoring.
"""

from datetime import date, timedelta
from typing import Dict, List, Any
from sqlalchemy.orm import Session
from sqlalchemy import and_, or_

from app.models.medicine import Medicine
from app.models.batch import Batch
from app.core.license import license_service


def get_pending_alerts(db: Session, pharmacy_id: int | None = None) -> Dict[str, Any]:
    """
    Gather critical system alerts:
    - Low stock alerts (medicines below min_stock)
    - Expiration alerts (batches expired or expiring within 30 days)
    - License alerts (license validity and expiration warnings)
    """
    today = date.today()
    expiring_soon_threshold = today + timedelta(days=30)

    # 1. Low stock medicines
    med_query = db.query(Medicine).filter(
        Medicine.stock_total <= Medicine.min_stock,
        Medicine.min_stock > 0
    )
    if pharmacy_id is not None:
        med_query = med_query.filter(Medicine.pharmacy_id == pharmacy_id)
    low_stock_medicines = med_query.limit(50).all()

    low_stock_alerts = [
        {
            "medicine_id": m.id,
            "name": m.name,
            "code": m.code,
            "current_stock": m.stock_total,
            "min_stock": m.min_stock,
            "type": "low_stock",
            "message": f"Stock faible pour '{m.name}' : {m.stock_total} restant(s) (seuil minimum : {m.min_stock}).",
        }
        for m in low_stock_medicines
    ]

    # 2. Expired or soon-expiring batches
    batch_query = db.query(Batch, Medicine.name.label("medicine_name")).join(
        Medicine, Batch.medicine_id == Medicine.id
    ).filter(
        Batch.quantity_remaining > 0,
        Batch.expiry_date.isnot(None),
        Batch.expiry_date <= expiring_soon_threshold
    )
    if pharmacy_id is not None:
        batch_query = batch_query.filter(Batch.pharmacy_id == pharmacy_id)
    expiring_batches = batch_query.order_by(Batch.expiry_date.asc()).limit(50).all()

    expiration_alerts = []
    for b, med_name in expiring_batches:
        is_expired = b.expiry_date < today
        days_left = (b.expiry_date - today).days
        expiration_alerts.append({
            "batch_id": b.id,
            "batch_number": b.batch_number,
            "medicine_name": med_name,
            "quantity_remaining": b.quantity_remaining,
            "expiry_date": b.expiry_date.isoformat(),
            "is_expired": is_expired,
            "days_left": days_left,
            "type": "expired" if is_expired else "expiring_soon",
            "message": (
                f"Lot '{b.batch_number}' de '{med_name}' expiré depuis {-days_left} jour(s) !"
                if is_expired
                else f"Lot '{b.batch_number}' de '{med_name}' expire dans {days_left} jour(s)."
            ),
        })

    # 3. License alerts
    license_status = license_service.get_license_status(db)

    return {
        "low_stock_count": len(low_stock_alerts),
        "low_stock_alerts": low_stock_alerts,
        "expiration_count": len(expiration_alerts),
        "expiration_alerts": expiration_alerts,
        "license_status": license_status,
        "total_alerts": len(low_stock_alerts) + len(expiration_alerts) + (1 if license_status.get("status") in ["warning", "expired"] else 0)
    }

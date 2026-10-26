"""
OBR (Office Burundais des Recettes) EBMS Routes.
Provides connection testing, sync monitoring, and pending invoice transmission.
"""

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import func
from typing import Dict, Any

from app.database import get_local_db
from app.models.user import User
from app.models.pharmacy import Pharmacy
from app.models.pos_sale import POSSale
from app.services.obr_client import OBRClient
from app.auth.dependencies import get_current_user

router = APIRouter(prefix="/obr", tags=["OBR - Facturation Électronique EBMS"])


@router.post("/test-connection", summary="Tester la liaison avec les serveurs de l'OBR")
def test_obr_connection(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_local_db),
) -> Dict[str, Any]:
    """Vérifie la validité des identifiants API OBR et la joignabilité du serveur."""
    pharmacy = db.query(Pharmacy).filter(Pharmacy.id == current_user.pharmacy_id).first()
    if not pharmacy:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Pharmacie introuvable",
        )

    client = OBRClient(pharmacy)
    return client.test_connection()


@router.get("/status", summary="Statut et compteurs de synchronisation OBR")
def get_obr_sync_status(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_local_db),
) -> Dict[str, Any]:
    """Retourne l'état de la liaison et les compteurs de factures OBR."""
    pharmacy = db.query(Pharmacy).filter(Pharmacy.id == current_user.pharmacy_id).first()
    if not pharmacy:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Pharmacie introuvable")

    p_id = current_user.pharmacy_id

    total_sales = db.query(func.count(POSSale.id)).filter(POSSale.pharmacy_id == p_id).scalar() or 0
    synced = db.query(func.count(POSSale.id)).filter(
        POSSale.pharmacy_id == p_id, POSSale.obr_sync_status == "synced"
    ).scalar() or 0
    pending = db.query(func.count(POSSale.id)).filter(
        POSSale.pharmacy_id == p_id, POSSale.obr_sync_status == "pending"
    ).scalar() or 0
    errors = db.query(func.count(POSSale.id)).filter(
        POSSale.pharmacy_id == p_id, POSSale.obr_sync_status == "error"
    ).scalar() or 0

    return {
        "obr_enabled": bool(getattr(pharmacy, "obr_enabled", False)),
        "nif": getattr(pharmacy, "nif", None) or "",
        "rc_number": getattr(pharmacy, "rc_number", None) or "",
        "tax_center": getattr(pharmacy, "tax_center", None) or "DMC",
        "environment": getattr(pharmacy, "obr_environment", "sandbox"),
        "total_sales": total_sales,
        "synced_invoices": synced,
        "pending_invoices": pending,
        "error_invoices": errors,
    }


@router.post("/resync-pending", summary="Retransmettre les factures en attente vers l'OBR")
def resync_pending_invoices(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_local_db),
) -> Dict[str, Any]:
    """Relance l'envoi des factures restées en attente."""
    pharmacy = db.query(Pharmacy).filter(Pharmacy.id == current_user.pharmacy_id).first()
    if not pharmacy:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Pharmacie introuvable")

    client = OBRClient(pharmacy)
    p_id = current_user.pharmacy_id

    pending_sales = db.query(POSSale).filter(
        POSSale.pharmacy_id == p_id,
        POSSale.obr_sync_status.in_(["pending", "error"]),
    ).limit(50).all()

    success_count = 0
    for sale in pending_sales:
        items_payload = []
        for it in sale.items:
            m_name = getattr(it.medicine, "name", "") if it.medicine else "Article"
            items_payload.append({
                "name": m_name,
                "quantity": it.quantity,
                "unit_price": it.unit_price,
                "total_price": it.total_price,
                "tax_rate": it.tax_rate,
                "tax_amount": it.tax_amount,
                "price_nvat": it.price_nvat,
                "price_wvat": it.price_wvat,
            })

        res = client.send_invoice(
            invoice_code=sale.code,
            sale_date=sale.date,
            total_amount=sale.total_amount,
            items=items_payload,
            customer_tin=None,
            customer_name=sale.customer_name,
            payment_method=sale.payment_method,
        )
        if res.get("success"):
            sale.obr_invoice_number = res.get("obr_invoice_number")
            sale.obr_signature = res.get("obr_signature")
            sale.obr_electronic_signature = res.get("obr_electronic_signature")
            sale.obr_qr_code = res.get("obr_qr_code")
            sale.obr_sync_status = res.get("sync_status", "synced")
            success_count += 1

    db.commit()
    return {
        "processed": len(pending_sales),
        "synced": success_count,
        "remaining_pending": len(pending_sales) - success_count,
    }

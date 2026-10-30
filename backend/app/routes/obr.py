"""
OBR (Office Burundais des Recettes) EBMS Routes.
Spécifications V0.5 : Paramétrage fiscal, diagnostic de connexion,
retransmission, vérification NIF (/check-tin), annulation facture (/cancel-invoice)
et mouvements de stock (/stock-movement).
"""

from datetime import datetime
from typing import Any, Dict, Optional
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.auth.dependencies import get_current_user
from app.database import get_local_db
from app.models.pharmacy import Pharmacy
from app.models.pos_sale import POSSale
from app.models.user import User
from app.services.obr_client import OBRClient

router = APIRouter(prefix="/obr", tags=["OBR - Facturation Électronique EBMS"])


class OBRConfigUpdate(BaseModel):
    obr_enabled: Optional[bool] = None
    nif: Optional[str] = None
    rc_number: Optional[str] = None
    tax_center: Optional[str] = None
    environment: Optional[str] = None
    obr_system_id: Optional[str] = None
    obr_api_username: Optional[str] = None
    obr_api_password: Optional[str] = None

    # Champs fiscaux V0.5
    tp_type: Optional[str] = None
    tp_legal_form: Optional[str] = None
    tp_activity_sector: Optional[str] = None
    tp_address_province: Optional[str] = None
    tp_address_commune: Optional[str] = None
    tp_address_quartier: Optional[str] = None
    tp_address_avenue: Optional[str] = None
    tp_address_rue: Optional[str] = None
    tp_address_number: Optional[str] = None
    vat_taxpayer: Optional[str] = None
    ct_taxpayer: Optional[str] = None
    tl_taxpayer: Optional[str] = None


class CheckTINRequest(BaseModel):
    tin: str = Field(..., min_length=4, description="Numéro d'Identification Fiscale (NIF)")
    force_refresh: bool = Field(default=False, description="Forcer l'interrogation OBR sans utiliser le cache")


class CancelInvoiceRequest(BaseModel):
    invoice_code: Optional[str] = Field(None, description="Code de la vente / facture interne")
    invoice_identifier: Optional[str] = Field(None, description="Identifiant unique officiel OBR de la facture")
    cn_motif: str = Field(..., min_length=3, description="Motif officiel de l'annulation ou note de crédit")


class StockMovementRequest(BaseModel):
    item_code: str
    item_designation: str
    item_quantity: float
    item_measurement_unit: Optional[str] = "UNITE"
    item_purchase_or_sale_price: float = 0.0
    item_purchase_or_sale_currency: Optional[str] = "BIF"
    item_movement_type: str = "SN"  # SN = Sortie vente, EN = Entrée achat, EA = Ajustement
    item_movement_invoice_ref: Optional[str] = ""
    item_movement_description: Optional[str] = ""


@router.put("/config", summary="Mettre à jour la configuration fiscale OBR")
def update_obr_config(
    payload: OBRConfigUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_local_db),
) -> Dict[str, Any]:
    """Met à jour les identifiants et le régime fiscal OBR EBMS V0.5 de la pharmacie."""
    pharmacy = db.query(Pharmacy).filter(Pharmacy.id == current_user.pharmacy_id).first()
    if not pharmacy:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Pharmacie introuvable")

    if payload.obr_enabled is not None:
        pharmacy.obr_enabled = payload.obr_enabled
    if payload.nif is not None:
        pharmacy.nif = payload.nif.strip()
        from app.models.settings import Settings
        s = db.query(Settings).filter(Settings.key == "pharmacy_nif").first()
        if s:
            s.value = pharmacy.nif
        else:
            db.add(Settings(key="pharmacy_nif", value=pharmacy.nif))
    if payload.rc_number is not None:
        pharmacy.rc_number = payload.rc_number.strip()
    if payload.tax_center is not None:
        pharmacy.tax_center = payload.tax_center.strip()
    if payload.environment is not None:
        pharmacy.obr_environment = payload.environment.strip()
    if payload.obr_system_id is not None:
        pharmacy.obr_system_id = payload.obr_system_id.strip()
    if payload.obr_api_username is not None:
        pharmacy.obr_api_username = payload.obr_api_username.strip()
    if payload.obr_api_password is not None and payload.obr_api_password.strip():
        pharmacy.obr_api_password = payload.obr_api_password.strip()

    # Paramètres d'immatriculation fiscale V0.5
    if payload.tp_type is not None:
        pharmacy.tp_type = payload.tp_type.strip()
    if payload.tp_legal_form is not None:
        pharmacy.tp_legal_form = payload.tp_legal_form.strip()
    if payload.tp_activity_sector is not None:
        pharmacy.tp_activity_sector = payload.tp_activity_sector.strip()
    if payload.tp_address_province is not None:
        pharmacy.tp_address_province = payload.tp_address_province.strip()
    if payload.tp_address_commune is not None:
        pharmacy.tp_address_commune = payload.tp_address_commune.strip()
    if payload.tp_address_quartier is not None:
        pharmacy.tp_address_quartier = payload.tp_address_quartier.strip()
    if payload.tp_address_avenue is not None:
        pharmacy.tp_address_avenue = payload.tp_address_avenue.strip()
    if payload.tp_address_rue is not None:
        pharmacy.tp_address_rue = payload.tp_address_rue.strip()
    if payload.tp_address_number is not None:
        pharmacy.tp_address_number = payload.tp_address_number.strip()
    if payload.vat_taxpayer is not None:
        pharmacy.vat_taxpayer = payload.vat_taxpayer.strip()
    if payload.ct_taxpayer is not None:
        pharmacy.ct_taxpayer = payload.ct_taxpayer.strip()
    if payload.tl_taxpayer is not None:
        pharmacy.tl_taxpayer = payload.tl_taxpayer.strip()

    db.commit()
    return {"success": True, "message": "Paramètres fiscaux OBR EBMS V0.5 enregistrés avec succès"}


@router.post("/test-connection", summary="Tester la liaison avec les serveurs de l'OBR")
def test_obr_connection(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_local_db),
) -> Dict[str, Any]:
    """Vérifie la validité des identifiants API OBR sur le port 9443."""
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
    """Retourne l'état complet de la liaison et les compteurs de factures OBR."""
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
        "obr_system_id": getattr(pharmacy, "obr_system_id", "") or "",
        "obr_api_username": getattr(pharmacy, "obr_api_username", "") or "",
        # Métadonnées V0.5
        "tp_type": getattr(pharmacy, "tp_type", "2") or "2",
        "tp_legal_form": getattr(pharmacy, "tp_legal_form", "SUARL") or "SUARL",
        "tp_activity_sector": getattr(pharmacy, "tp_activity_sector", "Commerce de détail de produits pharmaceutiques") or "",
        "tp_address_province": getattr(pharmacy, "tp_address_province", "BUJUMBURA MAIRIE") or "",
        "tp_address_commune": getattr(pharmacy, "tp_address_commune", "MUKAZA") or "",
        "tp_address_quartier": getattr(pharmacy, "tp_address_quartier", "ROHERO") or "",
        "tp_address_avenue": getattr(pharmacy, "tp_address_avenue", "") or "",
        "tp_address_rue": getattr(pharmacy, "tp_address_rue", "") or "",
        "tp_address_number": getattr(pharmacy, "tp_address_number", "") or "",
        "vat_taxpayer": getattr(pharmacy, "vat_taxpayer", "1") or "1",
        "ct_taxpayer": getattr(pharmacy, "ct_taxpayer", "0") or "0",
        "tl_taxpayer": getattr(pharmacy, "tl_taxpayer", "0") or "0",
        # Compteurs
        "total_sales": total_sales,
        "synced_invoices": synced,
        "pending_invoices": pending,
        "error_invoices": errors,
    }


@router.post("/check-tin", summary="Vérifier la validité d'un NIF client auprès de l'OBR")
def check_tin_endpoint(
    payload: CheckTINRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_local_db),
) -> Dict[str, Any]:
    """Vérifie si un NIF client est valide et actif auprès de l'OBR EBMS (POST /checkTIN/)."""
    pharmacy = db.query(Pharmacy).filter(Pharmacy.id == current_user.pharmacy_id).first()
    if not pharmacy:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Pharmacie introuvable")

    client = OBRClient(pharmacy)
    return client.check_tin(payload.tin, db=db, force_refresh=payload.force_refresh)


@router.post("/cancel-invoice", summary="Annuler une facture fiscale OBR")
def cancel_invoice_endpoint(
    payload: CancelInvoiceRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_local_db),
) -> Dict[str, Any]:
    """
    Annule une facture transmise à l'OBR (POST /cancelInvoice/).
    Met à jour le statut de la vente en 'cancelled' et renseigne le motif d'annulation.
    """
    pharmacy = db.query(Pharmacy).filter(Pharmacy.id == current_user.pharmacy_id).first()
    if not pharmacy:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Pharmacie introuvable")

    p_id = current_user.pharmacy_id
    sale = None
    if payload.invoice_code:
        sale = db.query(POSSale).filter(
            POSSale.pharmacy_id == p_id,
            POSSale.code == payload.invoice_code.strip()
        ).first()
    elif payload.invoice_identifier:
        sale = db.query(POSSale).filter(
            POSSale.pharmacy_id == p_id,
            POSSale.invoice_identifier == payload.invoice_identifier.strip()
        ).first()

    identifier = payload.invoice_identifier
    if sale and sale.invoice_identifier:
        identifier = sale.invoice_identifier
    elif sale and not identifier:
        client = OBRClient(pharmacy)
        identifier = client.build_invoice_identifier(sale.code, sale.date)

    if not identifier:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Identifiant de facture ou code de vente introuvable.",
        )

    client = OBRClient(pharmacy)
    obr_result = client.cancel_invoice(identifier, payload.cn_motif)

    if sale:
        sale.status = "cancelled"
        sale.cancelled_at = datetime.now()
        sale.cancelled_by = current_user.id
        sale.cn_motif = payload.cn_motif
        db.commit()

    return {
        "success": True,
        "invoice_identifier": identifier,
        "message": "Facture marquée comme annulée",
        "obr_details": obr_result,
    }


@router.post("/stock-movement", summary="Déclarer un mouvement de stock auprès de l'OBR")
def stock_movement_endpoint(
    payload: StockMovementRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_local_db),
) -> Dict[str, Any]:
    """Transmet un mouvement de stock à l'OBR EBMS (POST /AddStockMovement/)."""
    pharmacy = db.query(Pharmacy).filter(Pharmacy.id == current_user.pharmacy_id).first()
    if not pharmacy:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Pharmacie introuvable")

    client = OBRClient(pharmacy)
    return client.send_stock_movement(payload.model_dump())


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
                "item_ct": float(getattr(it.medicine, "item_ct", 0.0) or 0.0) if it.medicine else 0.0,
                "item_tl": float(getattr(it.medicine, "item_tl", 0.0) or 0.0) if it.medicine else 0.0,
            })

        res = client.send_invoice(
            invoice_code=sale.code,
            sale_date=sale.date,
            total_amount=sale.total_amount,
            items=items_payload,
            customer_tin=sale.customer_tin,
            customer_name=sale.customer_name,
            payment_method=sale.payment_method,
        )
        if res.get("success"):
            sale.invoice_identifier = res.get("invoice_identifier")
            sale.obr_invoice_number = res.get("obr_invoice_number")
            sale.obr_signature = res.get("obr_signature")
            sale.obr_electronic_signature = res.get("obr_electronic_signature")
            sale.obr_qr_code = res.get("obr_qr_code")
            sale.obr_sync_status = res.get("sync_status", "synced")
            sale.obr_synced_at = datetime.now()
            success_count += 1

    db.commit()
    return {
        "processed": len(pending_sales),
        "synced": success_count,
        "remaining_pending": len(pending_sales) - success_count,
    }


@router.get("/taxpayers", summary="Liste des NIFs vérifiés en cache")
def list_taxpayers_endpoint(
    search: Optional[str] = None,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_local_db),
):
    """Retourne la liste des NIFs déjà vérifiés et enregistrés en cache pour cette pharmacie."""
    from app.models.taxpayer_verification import TaxpayerVerification
    from sqlalchemy import or_

    query = db.query(TaxpayerVerification).filter(
        TaxpayerVerification.pharmacy_id == current_user.pharmacy_id
    )
    if search:
        s = f"%{search.strip()}%"
        query = query.filter(
            or_(
                TaxpayerVerification.tin.ilike(s),
                TaxpayerVerification.taxpayer_name.ilike(s),
            )
        )
    items = query.order_by(TaxpayerVerification.verified_at.desc()).limit(100).all()
    return [
        {
            "id": it.id,
            "tin": it.tin,
            "taxpayer_name": it.taxpayer_name,
            "taxpayer_address": it.taxpayer_address,
            "status": it.status,
            "is_valid": it.is_valid,
            "verified_at": it.verified_at.isoformat() if it.verified_at else None,
        }
        for it in items
    ]


@router.post("/verify-taxpayer", summary="Alias pour la vérification du NIF (checkTIN)")
def verify_taxpayer_endpoint(
    payload: CheckTINRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_local_db),
):
    """Alias direct pour l'API de vérification NIF."""
    return check_tin_endpoint(payload, current_user=current_user, db=db)

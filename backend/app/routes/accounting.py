"""
Simplified Accounting Module (Journal des écritures, Bilan et Export CSV).
"""

from fastapi import APIRouter, Depends, Query, Response
from sqlalchemy.orm import Session
from sqlalchemy import func
from typing import Optional, Dict, Any, List
from datetime import date, datetime, timedelta
import csv
import io

from app.database import get_local_db
from app.models.user import User
from app.auth.dependencies import get_current_active_user, get_current_pharmacy_context, PharmacyContext
from app.core.license_guard import require_feature
from app.models.pos_sale import POSSale
from app.models.customer_credit import CustomerCredit
from app.models.cash_register import CashRegisterSession

router = APIRouter(
    prefix="/accounting",
    tags=["Accounting"],
    dependencies=[Depends(require_feature("financial_reports"))],
)


@router.get("/journal", summary="Journal des écritures comptables")
def get_accounting_journal(
    from_date: Optional[date] = Query(None, description="Date de début (YYYY-MM-DD)"),
    to_date: Optional[date] = Query(None, description="Date de fin (YYYY-MM-DD)"),
    limit: int = Query(100, ge=1, le=500),
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_local_db),
) -> Dict[str, Any]:
    """
    Retourne le journal des flux financiers (ventes POS, règlements, crédits).
    """
    if not to_date:
        to_date = date.today()
    if not from_date:
        from_date = to_date - timedelta(days=30)

    from_dt = datetime.combine(from_date, datetime.min.time())
    to_dt = datetime.combine(to_date, datetime.max.time())

    sales = (
        db.query(POSSale)
        .filter(POSSale.date >= from_dt, POSSale.date <= to_dt)
        .order_by(POSSale.date.desc())
        .limit(limit)
        .all()
    )

    entries = []
    total_debit = 0.0
    total_credit = 0.0

    for s in sales:
        is_cancelled = s.status == "cancelled"
        amt = float(s.total_amount or 0.0)

        # Ligne de débit (Trésorerie / Caisse / Créance client)
        account_debit = "5310 - Caisse" if s.payment_method == "cash" else ("4110 - Clients (Crédit)" if s.payment_method == "credit" else "5120 - Banque/Mobile Money")
        # Ligne de crédit (Ventes de médicaments)
        account_credit = "7010 - Ventes Médicaments"

        if not is_cancelled:
            total_debit += amt
            total_credit += amt

        entries.append({
            "id": s.id,
            "date": s.date.strftime("%Y-%m-%d %H:%M") if s.date else "",
            "reference": s.code,
            "label": f"Vente POS {s.code} ({s.payment_method})" + (" [ANNULÉE]" if is_cancelled else ""),
            "payment_method": s.payment_method,
            "debit_account": account_debit,
            "credit_account": account_credit,
            "amount": amt,
            "is_cancelled": is_cancelled,
        })

    return {
        "from_date": from_date.isoformat(),
        "to_date": to_date.isoformat(),
        "total_entries": len(entries),
        "total_debit": total_debit,
        "total_credit": total_credit,
        "balanced": round(total_debit, 2) == round(total_credit, 2),
        "entries": entries,
    }


@router.get("/balance", summary="Bilan comptable simplifié")
def get_accounting_balance(
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_local_db),
) -> Dict[str, Any]:
    """
    Calcule un bilan simplifié : total ventes encaissées, encours clients, fonds de caisse.
    """
    from app.models.medicine import Medicine

    # Total ventes validées
    sales_total = (
        db.query(func.sum(POSSale.total_amount))
        .filter(POSSale.status == "completed")
        .scalar() or 0.0
    )

    # Répartition par méthode
    by_method = dict(
        db.query(POSSale.payment_method, func.sum(POSSale.total_amount))
        .filter(POSSale.status == "completed")
        .group_by(POSSale.payment_method)
        .all()
    )

    # Valeur du stock (Actif circulant)
    stock_value = (
        db.query(func.sum(Medicine.quantity * Medicine.price_buy))
        .filter(Medicine.is_active == True)
        .scalar() or 0.0
    )

    # Créances clients en cours
    outstanding_credits = (
        db.query(func.sum(CustomerCredit.amount - CustomerCredit.amount_paid))
        .filter(CustomerCredit.status.in_(["pending", "partial", "overdue"]))
        .scalar() or 0.0
    )

    # Caisse actuelle
    open_session = (
        db.query(CashRegisterSession)
        .filter(CashRegisterSession.status == "open")
        .order_by(CashRegisterSession.opened_at.desc())
        .first()
    )
    current_cash_in_drawer = float(open_session.opening_amount or 0.0) if open_session else 0.0

    return {
        "as_of_date": date.today().isoformat(),
        "assets": {
            "inventory_valuation": round(float(stock_value), 2),
            "accounts_receivable": round(float(outstanding_credits), 2),
            "cash_in_drawer_active_session": round(current_cash_in_drawer, 2),
            "total_liquid_and_stock_assets": round(float(stock_value + outstanding_credits + current_cash_in_drawer), 2),
        },
        "revenue_cumulative": {
            "total_sales": round(float(sales_total), 2),
            "cash_sales": round(float(by_method.get("cash", 0.0)), 2),
            "ecocash_sales": round(float(by_method.get("ecocash", 0.0)), 2),
            "credit_sales": round(float(by_method.get("credit", 0.0)), 2),
            "other_sales": round(float(sum(v for k, v in by_method.items() if k not in ("cash", "ecocash", "credit"))), 2),
        },
    }


@router.get("/export", summary="Export CSV du journal comptable")
def export_accounting_journal_csv(
    from_date: Optional[date] = None,
    to_date: Optional[date] = None,
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_local_db),
):
    journal_data = get_accounting_journal(from_date=from_date, to_date=to_date, limit=500, current_user=current_user, db=db)

    output = io.StringIO()
    writer = csv.writer(output, delimiter=";")
    writer.writerow(["Date", "Reference", "Libelle", "Mode Reglement", "Compte Debit", "Compte Credit", "Montant (FBu)", "Annule"])

    for row in journal_data["entries"]:
        writer.writerow([
            row["date"],
            row["reference"],
            row["label"],
            row["payment_method"],
            row["debit_account"],
            row["credit_account"],
            f"{row['amount']:.2f}",
            "OUI" if row["is_cancelled"] else "NON",
        ])

    csv_content = output.getvalue().encode("utf-8-sig")  # UTF-8 with BOM for Excel compatibility
    filename = f"journal_comptable_{journal_data['from_date']}_{journal_data['to_date']}.csv"

    return Response(
        content=csv_content,
        media_type="text/csv",
        headers={"Content-Disposition": f"attachment; filename={filename}"},
    )

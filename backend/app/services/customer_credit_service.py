"""
Customer Credit service - Business logic for customer debts and repayments.
"""

from sqlalchemy.orm import Session
from sqlalchemy import func
from typing import List, Optional, Tuple
from datetime import date, datetime

from app.models.customer_credit import CustomerCredit, CustomerCreditPayment
from app.models.customer import Customer
from app.schemas.customer_credit import CustomerCreditCreate, CreditPaymentCreate


def create_credit(db: Session, pharmacy_id: int, payload: CustomerCreditCreate) -> CustomerCredit:
    """Accorde un crédit à un client."""
    # Vérifier client
    cust = db.query(Customer).filter(Customer.id == payload.customer_id).first()
    if not cust:
        raise ValueError(f"Client avec ID {payload.customer_id} introuvable")

    credit = CustomerCredit(
        customer_id=payload.customer_id,
        sale_id=payload.sale_id,
        amount=payload.amount,
        amount_paid=0.0,
        due_date=payload.due_date,
        status="pending",
        notes=payload.notes,
        pharmacy_id=pharmacy_id,
    )
    db.add(credit)
    db.commit()
    db.refresh(credit)
    return credit


def get_credit_by_id(db: Session, credit_id: int) -> Optional[CustomerCredit]:
    """Récupère un crédit par ID (automatiquement filtré par tenant)."""
    return db.query(CustomerCredit).filter(CustomerCredit.id == credit_id).first()


def list_credits(
    db: Session,
    customer_id: Optional[int] = None,
    status: Optional[str] = None,
    skip: int = 0,
    limit: int = 50,
) -> Tuple[List[CustomerCredit], int]:
    """Liste les crédits avec pagination et filtres."""
    query = db.query(CustomerCredit)
    if customer_id:
        query = query.filter(CustomerCredit.customer_id == customer_id)
    if status:
        query = query.filter(CustomerCredit.status == status)

    # Actualiser le statut overdue si la date d'échéance est passée
    today = date.today()
    for credit in query.all():
        if credit.due_date and credit.due_date < today and credit.status in ("pending", "partial"):
            credit.status = "overdue"

    total = query.count()
    records = query.order_by(CustomerCredit.created_at.desc()).offset(skip).limit(limit).all()
    return records, total


def record_payment(
    db: Session,
    credit_id: int,
    pharmacy_id: int,
    user_id: int,
    payload: CreditPaymentCreate,
) -> CustomerCredit:
    """Enregistre un remboursement pour un crédit existant."""
    credit = get_credit_by_id(db, credit_id)
    if not credit:
        raise ValueError(f"Crédit avec ID {credit_id} introuvable")

    remaining = credit.amount - credit.amount_paid
    if payload.amount > remaining:
        raise ValueError(f"Le montant du remboursement ({payload.amount}) dépasse le solde restant ({remaining})")

    payment = CustomerCreditPayment(
        credit_id=credit.id,
        amount=payload.amount,
        payment_method=payload.payment_method,
        payment_date=datetime.utcnow(),
        received_by=user_id,
        notes=payload.notes,
        pharmacy_id=pharmacy_id,
    )
    db.add(payment)

    credit.amount_paid += payload.amount
    if credit.amount_paid >= credit.amount:
        credit.status = "paid"
    else:
        credit.status = "partial"

    db.commit()
    db.refresh(credit)
    return credit


def get_credits_summary(db: Session) -> dict:
    """Calcule le résumé global des crédits."""
    credits = db.query(CustomerCredit).all()
    today = date.today()

    total_credit = sum(c.amount for c in credits)
    total_paid = sum(c.amount_paid for c in credits)
    total_outstanding = max(0.0, total_credit - total_paid)

    pending_count = sum(1 for c in credits if c.status == "pending")
    overdue_count = sum(1 for c in credits if c.due_date and c.due_date < today and c.status != "paid")
    paid_count = sum(1 for c in credits if c.status == "paid")

    return {
        "total_credit": total_credit,
        "total_paid": total_paid,
        "total_outstanding": total_outstanding,
        "pending_count": pending_count,
        "overdue_count": overdue_count,
        "paid_count": paid_count,
    }

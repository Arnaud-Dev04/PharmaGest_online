"""
Customer Credit and Payments model for credit management.
"""

from sqlalchemy import Column, Integer, Float, String, Date, DateTime, Text, ForeignKey
from sqlalchemy.orm import relationship
from datetime import datetime

from app.database import Base
from app.models.base import BaseModelMixin, PharmacyScopedMixin


class CustomerCredit(Base, BaseModelMixin, PharmacyScopedMixin):
    """
    Crédit accordé à un client pour une vente ou différé.
    """
    __tablename__ = "customer_credits"

    customer_id = Column(Integer, ForeignKey("customers.id", ondelete="CASCADE"), nullable=False, index=True)
    sale_id = Column(Integer, ForeignKey("pos_sales.id", ondelete="SET NULL"), nullable=True, index=True)
    amount = Column(Float, nullable=False)
    amount_paid = Column(Float, default=0.0, nullable=False)
    due_date = Column(Date, nullable=True, index=True)
    status = Column(String(20), default="pending", nullable=False, index=True)  # pending, partial, paid, overdue
    notes = Column(Text, nullable=True)

    # Relations
    customer = relationship("Customer")
    sale = relationship("POSSale")
    payments = relationship("CustomerCreditPayment", back_populates="credit", cascade="all, delete-orphan")

    @property
    def remaining_amount(self) -> float:
        return max(0.0, self.amount - self.amount_paid)

    def __repr__(self):
        return f"<CustomerCredit id={self.id} customer_id={self.customer_id} amount={self.amount} status={self.status}>"


class CustomerCreditPayment(Base, BaseModelMixin, PharmacyScopedMixin):
    """
    Remboursement partiel ou total d'un crédit client.
    """
    __tablename__ = "customer_credit_payments"

    credit_id = Column(Integer, ForeignKey("customer_credits.id", ondelete="CASCADE"), nullable=False, index=True)
    amount = Column(Float, nullable=False)
    payment_method = Column(String(20), default="cash", nullable=False)
    payment_date = Column(DateTime, default=datetime.utcnow, nullable=False)
    received_by = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    notes = Column(String(500), nullable=True)

    credit = relationship("CustomerCredit", back_populates="payments")
    user = relationship("User")

    def __repr__(self):
        return f"<CustomerCreditPayment id={self.id} credit_id={self.credit_id} amount={self.amount}>"

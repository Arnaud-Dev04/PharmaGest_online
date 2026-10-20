"""Tenant-scoped cashier sessions and manual cash movements."""

import uuid

from sqlalchemy import (
    Column,
    DateTime,
    Float,
    ForeignKey,
    Integer,
    String,
    UniqueConstraint,
)
from sqlalchemy.orm import relationship

from app.database import Base
from app.models.base import BaseModelMixin, PharmacyScopedMixin


class CashRegisterSession(Base, BaseModelMixin, PharmacyScopedMixin):
    """One cashier's cash drawer session for one pharmacy."""

    __tablename__ = "cash_register_sessions"
    __table_args__ = (
        UniqueConstraint("session_uuid", name="uq_cash_register_session_uuid"),
        # NULL is allowed for closed sessions; the stable tenant-code + username
        # key prevents concurrent duplicate sessions locally and after sync.
        UniqueConstraint("active_key", name="uq_cash_register_active_key"),
    )

    session_uuid = Column(String(36), nullable=False, default=lambda: str(uuid.uuid4()))
    active_key = Column(String(120), nullable=True)
    cashier_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    opened_at = Column(DateTime, nullable=False)
    opening_amount = Column(Float, nullable=False, default=0.0)
    closed_at = Column(DateTime, nullable=True)
    closed_by_id = Column(Integer, ForeignKey("users.id"), nullable=True)
    expected_amount = Column(Float, nullable=True)
    counted_amount = Column(Float, nullable=True)
    variance = Column(Float, nullable=True)
    status = Column(String(20), nullable=False, default="open", index=True)
    notes = Column(String(500), nullable=True)
    sync_status = Column(String(20), nullable=False, default="pending", index=True)

    cashier = relationship("User", foreign_keys=[cashier_id])
    closed_by = relationship("User", foreign_keys=[closed_by_id])
    movements = relationship(
        "CashRegisterMovement",
        back_populates="session",
        cascade="all, delete-orphan",
    )


class CashRegisterMovement(Base, BaseModelMixin, PharmacyScopedMixin):
    """Manual cash inflow or outflow associated with a cashier session."""

    __tablename__ = "cash_register_movements"
    __table_args__ = (
        UniqueConstraint("movement_uuid", name="uq_cash_register_movement_uuid"),
    )

    movement_uuid = Column(String(36), nullable=False, default=lambda: str(uuid.uuid4()))
    session_uuid = Column(String(36), nullable=False, index=True)
    session_id = Column(Integer, ForeignKey("cash_register_sessions.id"), nullable=False, index=True)
    cashier_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    movement_type = Column(String(20), nullable=False)  # cash_in | cash_out
    amount = Column(Float, nullable=False)
    reason = Column(String(255), nullable=False)
    occurred_at = Column(DateTime, nullable=False)

    session = relationship("CashRegisterSession", back_populates="movements")
    cashier = relationship("User", foreign_keys=[cashier_id])
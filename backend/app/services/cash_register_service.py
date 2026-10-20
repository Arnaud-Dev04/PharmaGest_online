"""Business rules for per-cashier, per-pharmacy cash register sessions."""

from datetime import datetime

from fastapi import HTTPException
from sqlalchemy import func
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.models.cash_register import CashRegisterMovement, CashRegisterSession
from app.models.pharmacy import Pharmacy
from app.models.pos_sale import POSSale
from app.models.user import User, UserRole


def _get_scoped_session(db: Session, session_id: int) -> CashRegisterSession:
    session = db.query(CashRegisterSession).filter(
        CashRegisterSession.id == session_id,
    ).with_for_update().first()
    if session is None:
        raise HTTPException(status_code=404, detail="Cash session not found")
    return session


def _assert_can_manage(session: CashRegisterSession, current_user: User) -> None:
    if session.cashier_id != current_user.id and current_user.role not in (
        UserRole.ADMIN,
        UserRole.SUPER_ADMIN,
    ):
        raise HTTPException(status_code=404, detail="Cash session not found")


def _totals(db: Session, session: CashRegisterSession) -> tuple[float, float, float, float]:
    cash_sales = db.query(func.coalesce(func.sum(POSSale.total_amount), 0.0)).filter(
        POSSale.cash_session_uuid == session.session_uuid,
        POSSale.payment_method == "cash",
        POSSale.status != "cancelled",
        POSSale.date >= session.opened_at,
        POSSale.pharmacy_id == session.pharmacy_id,
    ).scalar() or 0.0
    cash_in = db.query(func.coalesce(func.sum(CashRegisterMovement.amount), 0.0)).filter(
        CashRegisterMovement.session_id == session.id,
        CashRegisterMovement.movement_type == "cash_in",
        CashRegisterMovement.pharmacy_id == session.pharmacy_id,
    ).scalar() or 0.0
    cash_out = db.query(func.coalesce(func.sum(CashRegisterMovement.amount), 0.0)).filter(
        CashRegisterMovement.session_id == session.id,
        CashRegisterMovement.movement_type == "cash_out",
        CashRegisterMovement.pharmacy_id == session.pharmacy_id,
    ).scalar() or 0.0
    expected = round(float(session.opening_amount) + float(cash_sales) + float(cash_in) - float(cash_out), 2)
    return round(float(cash_sales), 2), round(float(cash_in), 2), round(float(cash_out), 2), expected


def _response(db: Session, session: CashRegisterSession) -> dict:
    cash_sales, cash_in, cash_out, calculated_expected = _totals(db, session)
    expected = (
        float(session.expected_amount)
        if session.status == "closed" and session.expected_amount is not None
        else calculated_expected
    )
    return {
        "id": session.id,
        "session_uuid": session.session_uuid,
        "pharmacy_id": session.pharmacy_id,
        "cashier_id": session.cashier_id,
        "cashier_username": session.cashier.username if session.cashier else "",
        "opened_at": session.opened_at,
        "opening_amount": session.opening_amount,
        "closed_at": session.closed_at,
        "expected_amount": expected,
        "current_expected_amount": expected,
        "counted_amount": session.counted_amount,
        "variance": session.variance,
        "status": session.status,
        "notes": session.notes,
        "cash_sales_total": cash_sales,
        "cash_in_total": cash_in,
        "cash_out_total": cash_out,
        "movements": [
            {
                "id": movement.id,
                "movement_uuid": movement.movement_uuid,
                "session_id": movement.session_id,
                "session_uuid": movement.session_uuid,
                "cashier_id": movement.cashier_id,
                "movement_type": movement.movement_type,
                "amount": movement.amount,
                "reason": movement.reason,
                "occurred_at": movement.occurred_at,
            }
            for movement in sorted(session.movements, key=lambda movement: movement.occurred_at)
        ],
    }


def get_current_session(db: Session, current_user: User):
    session = db.query(CashRegisterSession).filter(
        CashRegisterSession.cashier_id == current_user.id,
        CashRegisterSession.status == "open",
    ).first()
    return _response(db, session) if session else None


def open_session(db: Session, current_user: User, opening_amount: float, notes: str | None):
    pharmacy_id = current_user.pharmacy_id
    if pharmacy_id is None:
        raise HTTPException(status_code=403, detail="A pharmacy assignment is required")

    # Serialize concurrent open requests for this pharmacy; the unique key remains
    # the final guard on databases where row locks are unavailable (e.g. SQLite).
    pharmacy = db.query(Pharmacy).filter(Pharmacy.id == pharmacy_id).with_for_update().first()
    if pharmacy is None or not pharmacy.is_active:
        raise HTTPException(status_code=403, detail="Pharmacy is unavailable")
    if get_current_session(db, current_user):
        raise HTTPException(status_code=409, detail="You already have an open cash session")

    session = CashRegisterSession(
        pharmacy_id=pharmacy_id,
        cashier_id=current_user.id,
        active_key=f"{pharmacy.code}:{current_user.username}",
        opened_at=datetime.utcnow(),
        opening_amount=round(float(opening_amount), 2),
        status="open",
        notes=notes,
    )
    db.add(session)
    try:
        db.commit()
        db.refresh(session)
    except IntegrityError as exc:
        db.rollback()
        raise HTTPException(status_code=409, detail="You already have an open cash session") from exc
    return _response(db, session)


def validate_sale_session(
    db: Session,
    current_user: User,
    session_uuid: str | None,
    payment_method: str,
) -> CashRegisterSession | None:
    """Require and validate an open cashier session for cash POS payments."""
    if payment_method.lower() != "cash":
        if session_uuid:
            raise HTTPException(
                status_code=422,
                detail="Cash session UUID is only valid for cash payments",
            )
        return None
    if not session_uuid:
        raise HTTPException(status_code=409, detail="Open a cash session before making a cash sale")

    session = db.query(CashRegisterSession).filter(
        CashRegisterSession.pharmacy_id == current_user.pharmacy_id,
        CashRegisterSession.session_uuid == session_uuid,
        CashRegisterSession.cashier_id == current_user.id,
        CashRegisterSession.status == "open",
    ).with_for_update().first()
    if session is None:
        raise HTTPException(status_code=409, detail="The cashier session is not open or does not belong to you")
    if session.pharmacy_id != current_user.pharmacy_id:
        raise HTTPException(status_code=404, detail="Cash session not found")
    return session


def validate_synced_sale_session(db: Session, sale: POSSale) -> CashRegisterSession:
    """Resolve the source cashier session by portable UUID when POS sale syncs."""
    session = db.query(CashRegisterSession).filter(
        CashRegisterSession.session_uuid == sale.cash_session_uuid,
        CashRegisterSession.pharmacy_id == sale.pharmacy_id,
        CashRegisterSession.cashier_id == sale.user_id,
    ).first()
    if session is None or session.status != "open":
        raise HTTPException(
            status_code=409,
            detail="A cash session must be opened and synced before its cash POS sales",
        )
    return session


def add_movement(
    db: Session,
    session_id: int,
    current_user: User,
    movement_type: str,
    amount: float,
    reason: str,
):
    session = _get_scoped_session(db, session_id)
    _assert_can_manage(session, current_user)
    if session.status != "open":
        raise HTTPException(status_code=409, detail="Cash session is already closed")
    movement = CashRegisterMovement(
        pharmacy_id=session.pharmacy_id,
        session_uuid=session.session_uuid,
        session_id=session.id,
        cashier_id=current_user.id,
        movement_type=movement_type,
        amount=round(float(amount), 2),
        reason=reason.strip(),
        occurred_at=datetime.utcnow(),
    )
    session.sync_status = "pending"
    db.add(movement)
    db.commit()
    db.refresh(session)
    return _response(db, session)


def close_session(
    db: Session,
    session_id: int,
    current_user: User,
    counted_amount: float,
    notes: str | None,
):
    session = _get_scoped_session(db, session_id)
    _assert_can_manage(session, current_user)
    if session.status != "open":
        raise HTTPException(status_code=409, detail="Cash session is already closed")

    _, _, _, expected = _totals(db, session)
    counted = round(float(counted_amount), 2)
    session.closed_at = datetime.utcnow()
    session.closed_by_id = current_user.id
    session.expected_amount = expected
    session.counted_amount = counted
    session.variance = round(counted - expected, 2)
    session.status = "closed"
    session.active_key = None
    session.sync_status = "pending"
    if notes and notes.strip():
        session.notes = f"{session.notes}\n{notes.strip()}" if session.notes else notes.strip()
    db.commit()
    db.refresh(session)
    return _response(db, session)


def list_sessions(db: Session, current_user: User, page: int, page_size: int, status_filter: str | None):
    query = db.query(CashRegisterSession)
    if current_user.role not in (UserRole.ADMIN, UserRole.SUPER_ADMIN):
        query = query.filter(CashRegisterSession.cashier_id == current_user.id)
    if status_filter:
        query = query.filter(CashRegisterSession.status == status_filter)
    total = query.count()
    sessions = (
        query.order_by(CashRegisterSession.opened_at.desc(), CashRegisterSession.id.desc())
        .offset((page - 1) * page_size)
        .limit(page_size)
        .all()
    )
    return {
        "items": [_response(db, session) for session in sessions],
        "total": total,
        "page": page,
        "page_size": page_size,
        "total_pages": (total + page_size - 1) // page_size,
    }
"""Integration tests for tenant-scoped cashier sessions and reconciliation."""

from datetime import datetime

from app.models.cash_register import CashRegisterMovement, CashRegisterSession
from app.models.pharmacy import Pharmacy
from app.models.pos_sale import POSSale
from app.models.user import User, UserRole
from app.utils.security import create_access_token, hash_password


def _headers(user):
    token = create_access_token(data={"sub": user.username})
    return {"Authorization": f"Bearer {token}"}


def test_cash_session_open_movement_and_close_reconciles_cash_sales(
    client, db, admin_user, admin_headers, pharmacy
):
    opened = client.post(
        "/cash-register/open",
        json={"opening_amount": 1000, "notes": "Morning float"},
        headers=admin_headers,
    )
    assert opened.status_code == 201, opened.text
    session = opened.json()
    assert session["status"] == "open"
    assert session["opening_amount"] == 1000
    assert session["cashier_id"] == admin_user.id
    assert session["current_expected_amount"] == 1000

    duplicate_open = client.post(
        "/cash-register/open",
        json={"opening_amount": 500},
        headers=admin_headers,
    )
    assert duplicate_open.status_code == 409

    db.add_all([
        POSSale(
            sale_uuid="b12b344b-b37c-4b3e-9a33-692985fc3001",
            code="CASH-SESSION-SALE",
            total_amount=2500,
            payment_method="cash",
            date=datetime.utcnow(),
            user_id=admin_user.id,
            cash_session_uuid=session["session_uuid"],
            pharmacy_id=pharmacy.id,
        ),
        POSSale(
            sale_uuid="b12b344b-b37c-4b3e-9a33-692985fc3002",
            code="CASH-SESSION-NONCASH",
            total_amount=9000,
            payment_method="insurance",
            date=datetime.utcnow(),
            user_id=admin_user.id,
            cash_session_uuid=None,
            pharmacy_id=pharmacy.id,
        ),
    ])
    db.commit()

    cash_in = client.post(
        f"/cash-register/{session['id']}/movements",
        json={"movement_type": "cash_in", "amount": 500, "reason": "Change fund"},
        headers=admin_headers,
    )
    assert cash_in.status_code == 200, cash_in.text
    cash_out = client.post(
        f"/cash-register/{session['id']}/movements",
        json={"movement_type": "cash_out", "amount": 200, "reason": "Petty cash"},
        headers=admin_headers,
    )
    assert cash_out.status_code == 200, cash_out.text
    assert cash_out.json()["current_expected_amount"] == 3800
    assert cash_out.json()["cash_sales_total"] == 2500

    closed = client.post(
        f"/cash-register/{session['id']}/close",
        json={"counted_amount": 3790, "notes": "Count completed after midnight"},
        headers=admin_headers,
    )
    assert closed.status_code == 200, closed.text
    result = closed.json()
    assert result["status"] == "closed"
    assert result["expected_amount"] == 3800
    assert result["counted_amount"] == 3790
    assert result["variance"] == -10
    assert result["cash_in_total"] == 500
    assert result["cash_out_total"] == 200
    assert len(result["movements"]) == 2

    second_close = client.post(
        f"/cash-register/{session['id']}/close",
        json={"counted_amount": 3800},
        headers=admin_headers,
    )
    assert second_close.status_code == 409


def test_cash_session_is_private_per_cashier_and_admin_can_close_other_cashier(
    client, db, admin_user, admin_headers, pharmacist_user, pharmacist_headers, pharmacy
):
    opened = client.post(
        "/cash-register/open",
        json={"opening_amount": 300},
        headers=pharmacist_headers,
    )
    assert opened.status_code == 201, opened.text
    session = opened.json()

    own_current = client.get("/cash-register/current", headers=pharmacist_headers)
    assert own_current.status_code == 200
    assert own_current.json()["id"] == session["id"]

    admin_current = client.get("/cash-register/current", headers=admin_headers)
    assert admin_current.status_code == 200
    assert admin_current.json() is None

    forbidden_close = client.post(
        f"/cash-register/{session['id']}/close",
        json={"counted_amount": 300},
        headers=admin_headers,
    )
    assert forbidden_close.status_code == 200, forbidden_close.text
    assert forbidden_close.json()["status"] == "closed"


def test_cash_session_routes_hide_other_tenant_sessions(
    client, db, admin_user, admin_headers, pharmacy
):
    foreign_pharmacy = Pharmacy(name="Cash Foreign", code="CASH-FOREIGN-PHARMACY")
    db.add(foreign_pharmacy)
    db.commit()
    db.refresh(foreign_pharmacy)
    foreign_cashier = User(
        username="cash_foreign_user",
        password_hash=hash_password("CashForeign@123!"),
        role=UserRole.PHARMACIST,
        is_active=True,
        pharmacy_id=foreign_pharmacy.id,
    )
    db.add(foreign_cashier)
    db.commit()
    db.refresh(foreign_cashier)
    foreign_session = CashRegisterSession(
        session_uuid="ba87aeb1-c15c-47b2-8969-a64edaf71e1c",
        active_key=f"{foreign_pharmacy.code}:{foreign_cashier.username}",
        cashier_id=foreign_cashier.id,
        opened_at=datetime.utcnow(),
        opening_amount=100,
        status="open",
        pharmacy_id=foreign_pharmacy.id,
    )
    db.add(foreign_session)
    db.commit()
    db.refresh(foreign_session)

    response = client.post(
        f"/cash-register/{foreign_session.id}/movements",
        json={"movement_type": "cash_in", "amount": 50, "reason": "Not allowed"},
        headers=admin_headers,
    )
    assert response.status_code == 404
    assert db.query(CashRegisterMovement).filter(
        CashRegisterMovement.session_uuid == foreign_session.session_uuid
    ).count() == 0


def test_cash_pos_sale_requires_an_open_owned_session(client, admin_headers):
    response = client.post(
        "/pos/checkout",
        headers=admin_headers,
        json={
            "items": [{
                "medicine_id": 1,
                "allocations": [{"batch_id": 1, "quantity": 1}],
                "quantity": 1,
                "unit_price": 100,
            }],
            "payment_method": "cash",
        },
    )
    assert response.status_code == 409
    assert response.json()["detail"] == "Open a cash session before making a cash sale"
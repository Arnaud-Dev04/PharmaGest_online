"""
test_customer_credits.py — Tests for Customer Credits and Debt Repayments.
"""

import pytest
from datetime import date, timedelta
from app.models.customer import Customer
from app.models.customer_credit import CustomerCredit


@pytest.fixture
def test_customer(db, pharmacy):
    pharmacy.plan = "pro"
    db.commit()

    cust = Customer(
        first_name="Alice",
        last_name="Niyonzima",
        phone="+25779888999",
        pharmacy_id=pharmacy.id,
    )
    db.add(cust)
    db.commit()
    db.refresh(cust)
    return cust


class TestCustomerCredits:
    def test_create_and_get_credit(self, client, admin_headers, test_customer):
        future_due = (date.today() + timedelta(days=15)).isoformat()
        resp = client.post(
            "/credits/",
            json={
                "customer_id": test_customer.id,
                "amount": 50000.0,
                "due_date": future_due,
                "notes": "Achat médicaments à crédit",
            },
            headers=admin_headers,
        )
        assert resp.status_code == 201, resp.text
        data = resp.json()
        assert data["amount"] == 50000.0
        assert data["amount_paid"] == 0.0
        assert data["remaining_amount"] == 50000.0
        assert data["status"] == "pending"
        credit_id = data["id"]

        # Détails par ID
        resp_get = client.get(f"/credits/{credit_id}", headers=admin_headers)
        assert resp_get.status_code == 200
        assert resp_get.json()["id"] == credit_id

    def test_repayments_partial_and_full(self, client, admin_headers, test_customer):
        resp = client.post(
            "/credits/",
            json={"customer_id": test_customer.id, "amount": 20000.0},
            headers=admin_headers,
        )
        credit_id = resp.json()["id"]

        # Remboursement partiel de 8 000 FBu
        resp_p1 = client.post(
            f"/credits/{credit_id}/payments",
            json={"amount": 8000.0, "payment_method": "cash"},
            headers=admin_headers,
        )
        assert resp_p1.status_code == 200
        d1 = resp_p1.json()
        assert d1["amount_paid"] == 8000.0
        assert d1["remaining_amount"] == 12000.0
        assert d1["status"] == "partial"

        # Remboursement excessif (15 000 > 12 000 restant) -> Refusé 400
        resp_excess = client.post(
            f"/credits/{credit_id}/payments",
            json={"amount": 15000.0, "payment_method": "cash"},
            headers=admin_headers,
        )
        assert resp_excess.status_code == 400

        # Solde final de 12 000 FBu -> Status paid
        resp_p2 = client.post(
            f"/credits/{credit_id}/payments",
            json={"amount": 12000.0, "payment_method": "ecocash"},
            headers=admin_headers,
        )
        assert resp_p2.status_code == 200
        d2 = resp_p2.json()
        assert d2["amount_paid"] == 20000.0
        assert d2["remaining_amount"] == 0.0
        assert d2["status"] == "paid"

    def test_credits_summary_and_list(self, client, admin_headers, test_customer):
        resp_summary = client.get("/credits/summary", headers=admin_headers)
        assert resp_summary.status_code == 200
        summary = resp_summary.json()
        assert "total_credit" in summary
        assert "total_outstanding" in summary
        assert "pending_count" in summary

        # Liste paginée
        resp_list = client.get("/credits/", headers=admin_headers)
        assert resp_list.status_code == 200
        assert "items" in resp_list.json()

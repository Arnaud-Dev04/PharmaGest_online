"""
test_business_features.py — Tests for Phase D features:
- Global unified search (Ctrl+K)
- Thermal ticket generation (58mm/80mm text & ESC/POS)
- Restock suggestions & stockout predictions
- Accounting journal, balance & CSV export
"""

import pytest
from datetime import datetime, date, timedelta
from app.models.medicine import Medicine
from app.models.customer import Customer
from app.models.pos_sale import POSSale, POSSaleItem
from app.models.customer_credit import CustomerCredit


@pytest.fixture
def business_setup(db, pharmacy, admin_user):
    pharmacy.plan = "enterprise"
    db.commit()

    # Créer client
    cust = Customer(
        first_name="Jean-Paul",
        last_name="Habimana",
        phone="+25771234567",
        pharmacy_id=pharmacy.id,
    )
    # Créer médicament
    med = Medicine(
        code="MED-BIZ-01",
        name="Amoxicilline Gélule 500mg",
        dci="Amoxicilline",
        price_buy=800.0,
        price_sell=1200.0,
        quantity=25.0,
        min_stock_alert=10,
        pharmacy_id=pharmacy.id,
    )
    db.add_all([cust, med])
    db.commit()
    db.refresh(cust)
    db.refresh(med)

    # Créer vente POS
    sale = POSSale(
        sale_uuid="sale-uuid-biz-001",
        code="POS-2026-BIZ-001",
        total_amount=2400.0,
        payment_method="cash",
        date=datetime.utcnow() - timedelta(days=2),
        user_id=admin_user.id,
        customer_id=cust.id,
        customer_name=f"{cust.first_name} {cust.last_name}",
        customer_phone=cust.phone,
        status="completed",
        pharmacy_id=pharmacy.id,
    )
    db.add(sale)
    db.commit()
    db.refresh(sale)

    sale_item = POSSaleItem(
        sale_id=sale.id,
        medicine_id=med.id,
        quantity=2,
        unit_price=1200.0,
        total_price=2400.0,
        pharmacy_id=pharmacy.id,
    )
    db.add(sale_item)
    db.commit()

    return {"customer": cust, "medicine": med, "sale": sale}


class TestGlobalSearch:
    def test_global_search_finds_all_categories(self, client, admin_headers, business_setup):
        resp = client.get("/search?q=Amox", headers=admin_headers)
        assert resp.status_code == 200, resp.text
        data = resp.json()
        assert data["total_matches"] >= 1
        med_results = data["results"]["medicines"]
        assert any("Amoxicilline" in m["name"] for m in med_results)

        # Recherche client par téléphone
        resp_cust = client.get("/search?q=712345", headers=admin_headers)
        assert resp_cust.status_code == 200
        assert len(resp_cust.json()["results"]["customers"]) >= 1


class TestThermalPrinter:
    def test_thermal_ticket_formats(self, client, admin_headers, business_setup):
        sale_id = business_setup["sale"].id

        # Format texte 58mm
        resp_text = client.get(f"/pos/sale/{sale_id}/ticket?format=text&width=58", headers=admin_headers)
        assert resp_text.status_code == 200
        assert "TICKET DE CAISSE" in resp_text.text
        assert "TOTAL:" in resp_text.text

        # Format ESC/POS binaire
        resp_escpos = client.get(f"/pos/sale/{sale_id}/ticket?format=escpos&width=58", headers=admin_headers)
        assert resp_escpos.status_code == 200
        assert resp_escpos.headers["content-type"] == "application/octet-stream"
        assert len(resp_escpos.content) > 30

        # Format JSON
        resp_json = client.get(f"/pos/sale/{sale_id}/ticket?format=json", headers=admin_headers)
        assert resp_json.status_code == 200
        assert resp_json.json()["code"] == "POS-2026-BIZ-001"


class TestStockSuggestionsAndPredictions:
    def test_restock_suggestions(self, client, admin_headers, business_setup):
        resp = client.get("/stock/restock-suggestions?days=30", headers=admin_headers)
        assert resp.status_code == 200, resp.text
        data = resp.json()
        assert "suggestions" in data
        assert data["total_medicines_analyzed"] >= 1

    def test_stock_predictions(self, client, admin_headers, business_setup):
        resp = client.get("/stock/predictions", headers=admin_headers)
        assert resp.status_code == 200, resp.text
        data = resp.json()
        assert "predictions" in data
        assert "at_risk_within_60_days" in data or "total_at_risk_within_60_days" in data


class TestAccounting:
    def test_journal_balance_and_export(self, client, admin_headers, business_setup):
        # Journal
        resp_journal = client.get("/accounting/journal", headers=admin_headers)
        assert resp_journal.status_code == 200, resp_journal.text
        j_data = resp_journal.json()
        assert j_data["total_entries"] >= 1
        assert "total_debit" in j_data

        # Bilan simplifié
        resp_bal = client.get("/accounting/balance", headers=admin_headers)
        assert resp_bal.status_code == 200, resp_bal.text
        b_data = resp_bal.json()
        assert "assets" in b_data
        assert "revenue_cumulative" in b_data

        # Export CSV
        resp_csv = client.get("/accounting/export", headers=admin_headers)
        assert resp_csv.status_code == 200
        assert "text/csv" in resp_csv.headers["content-type"]
        assert len(resp_csv.content) > 50

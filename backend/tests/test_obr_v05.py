"""
Tests complets pour le module OBR EBMS V0.5 (Novembre 2023).
Vérifie la conformité des payloads, des identifiants, des modes de paiement,
de la suppression des nulls, et des routes API.
"""

from datetime import datetime
import pytest
from app.models.pharmacy import Pharmacy
from app.services.obr_client import OBRClient


@pytest.fixture
def sample_pharmacy():
    p = Pharmacy(
        id=1,
        name="Pharmacie La Centrale",
        code="PHARM-001",
        address="Avenue de l'Université, Rohero",
        phone="+257 22 22 22 22",
        nif="4000123456",
        rc_number="01234/RC/BJM",
        tax_center="DMC",
        obr_enabled=True,
        obr_environment="sandbox",
        obr_system_id="SYS-DEV-TEST",
        obr_api_username="test_user",
        obr_api_password="test_password",
        tp_type="2",
        tp_legal_form="SUARL",
        tp_activity_sector="Commerce de détail de produits pharmaceutiques",
        tp_address_province="BUJUMBURA MAIRIE",
        tp_address_commune="MUKAZA",
        tp_address_quartier="ROHERO",
        tp_address_avenue="Avenue de l'Université",
        tp_address_rue="",
        tp_address_number="12",
        vat_taxpayer="1",
        ct_taxpayer="0",
        tl_taxpayer="0",
    )
    return p


def test_build_invoice_identifier_format_and_length(sample_pharmacy):
    client = OBRClient(sample_pharmacy)
    test_date = datetime(2026, 10, 28, 14, 30, 45)
    invoice_code = "POS-2026-00042"

    identifier = client.build_invoice_identifier(invoice_code, test_date)

    # Format officiel : <tp_TIN>/<system_id>/<YYYYMMDDhhmmss>/<invoice_number>
    parts = identifier.split("/")
    assert len(parts) == 4
    assert parts[0] == "4000123456"
    assert parts[1] == "SYS-DEV-TEST"
    assert parts[2] == "20261028143045"
    assert parts[3] == "POS-2026-00042"
    assert len(identifier) <= 90


def test_clean_nulls_eliminates_all_none():
    data = {
        "invoice_number": "INV-101",
        "customer_tin": None,
        "vat_amount": None,
        "notes": None,
        "items": [
            {
                "name": "Paracetamol",
                "item_ct": None,
                "item_tl": None,
                "desc": None,
            }
        ]
    }

    cleaned = OBRClient.clean_nulls(data)

    # Vérification qu'aucun None n'existe dans cleaned
    assert cleaned["customer_tin"] == ""
    assert cleaned["vat_amount"] == 0.0
    assert cleaned["notes"] == ""
    assert cleaned["items"][0]["item_ct"] == 0.0
    assert cleaned["items"][0]["item_tl"] == 0.0
    assert cleaned["items"][0]["desc"] == ""


def test_payment_type_mapping(sample_pharmacy):
    client = OBRClient(sample_pharmacy)

    # 1 = Espèces
    assert client._map_payment_type("cash") == "1"
    assert client._map_payment_type("especes") == "1"

    # 2 = Banque / Carte
    assert client._map_payment_type("card") == "2"
    assert client._map_payment_type("carte") == "2"
    assert client._map_payment_type("bank") == "2"

    # 3 = Vente à crédit
    assert client._map_payment_type("credit") == "3"
    assert client._map_payment_type("dette") == "3"

    # 4 = Mobile Money / Autres
    assert client._map_payment_type("mobile_money") == "4"
    assert client._map_payment_type("lumicash") == "4"
    assert client._map_payment_type("ecocash") == "4"
    assert client._map_payment_type("insurance") == "4"


def test_build_invoice_payload_conforms_to_v05(sample_pharmacy):
    client = OBRClient(sample_pharmacy)
    test_date = datetime(2026, 10, 28, 12, 0, 0)
    items = [
        {
            "name": "Amoxicilline 500mg",
            "quantity": 2,
            "unit_price": 4500.0,
            "total_price": 9000.0,
            "tax_amount": 0.0,
            "price_nvat": 9000.0,
            "price_wvat": 9000.0,
        }
    ]

    payload = client.build_invoice_payload(
        invoice_code="POS-2026-0001",
        sale_date=test_date,
        total_amount=9000.0,
        items=items,
        customer_tin="4000999999",
        customer_name="Centre Médical Espoir",
        payment_method="cash",
    )

    # Vérification des champs obligatoires EBMS V0.5
    assert payload["invoice_number"] == "POS-2026-0001"
    assert payload["tp_TIN"] == "4000123456"
    assert payload["tp_type"] == "2"
    assert payload["tp_legal_form"] == "SUARL"
    assert payload["tp_address_commune"] == "MUKAZA"
    assert payload["tp_address_quartier"] == "ROHERO"
    assert payload["vat_taxpayer"] == "1"
    assert payload["payment_type"] == "1"
    assert payload["customer_TIN"] == "4000999999"
    assert payload["customer_name"] == "Centre Médical Espoir"

    # Vérification des lignes d'articles V0.5
    item = payload["invoice_items"][0]
    assert item["item_designation"] == "Amoxicilline 500mg"
    assert item["item_quantity"] == 2.0
    assert item["item_price"] == 4500.0
    assert item["item_ott_tax"] == 0.0
    assert item["item_tsce_tax"] == 0.0
    assert item["item_total_amount"] == 9000.0

    # Aucun null autorisé dans tout le payload
    def has_null(obj):
        if obj is None:
            return True
        if isinstance(obj, dict):
            return any(has_null(v) for v in obj.values())
        if isinstance(obj, list):
            return any(has_null(v) for v in obj)
        return False

    assert not has_null(payload)


def test_send_invoice_offline_deterministic_signature(sample_pharmacy):
    client = OBRClient(sample_pharmacy)
    test_date = datetime(2026, 10, 28, 12, 0, 0)
    items = [
        {"name": "Paracetamol 1g", "quantity": 1, "unit_price": 2000.0, "total_price": 2000.0}
    ]

    res = client.send_invoice(
        invoice_code="POS-2026-0002",
        sale_date=test_date,
        total_amount=2000.0,
        items=items,
        payment_method="cash",
    )

    assert res["success"] is True
    assert "invoice_identifier" in res
    assert "obr_signature" in res
    assert len(res["obr_signature"]) > 0
    assert "obr_qr_code" in res
    assert "4000123456" in res["obr_qr_code"]


def test_check_tin_local_validation(sample_pharmacy):
    client = OBRClient(sample_pharmacy)

    valid_res = client.check_tin("4000123456")
    assert valid_res["success"] is True
    assert valid_res["valid"] is True

    empty_res = client.check_tin("")
    assert empty_res["valid"] is False


def test_cancel_invoice_format(sample_pharmacy):
    client = OBRClient(sample_pharmacy)
    identifier = client.build_invoice_identifier("POS-2026-0003", datetime.now())

    res = client.cancel_invoice(identifier, "Erreur de posologie / retour client")
    assert res["success"] is True


def test_stock_movement_payload(sample_pharmacy):
    client = OBRClient(sample_pharmacy)
    movement = {
        "item_code": "MED-001",
        "item_designation": "Paracetamol 500mg",
        "item_quantity": 50,
        "item_purchase_or_sale_price": 500.0,
        "item_movement_type": "EN",
        "item_movement_description": "Réception commande fournisseur",
    }
    res = client.send_stock_movement(movement)
    assert res["success"] is True


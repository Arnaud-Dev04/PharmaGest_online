"""
test_tenant_isolation_exhaustive.py — Audit exhaustif route-par-route de l'isolation multi-tenant.

Vérifie de manière systématique que :
- Les listes ne retournent jamais d'enregistrements appartenant à une autre pharmacie.
- Les requêtes par ID étranger (GET, PUT, DELETE) retournent 404.
- Aucune donnée métier (stock, clients, fournisseurs, ventes, utilisateurs, caisse, settings)
  ne fuite entre tenants.
"""

import pytest
from datetime import date, timedelta
from app.models.pharmacy import Pharmacy
from app.models.user import User, UserRole
from app.models.medicine import Medicine
from app.models.batch import Batch
from app.models.pos_sale import POSSale, POSSaleItem
from app.models.customer import Customer
from app.models.supplier import Supplier
from app.models.cash_register import CashRegisterSession
from app.utils.security import hash_password, create_access_token


@pytest.fixture
def two_tenants(db):
    """Crée deux pharmacies en plan pro et deux administrateurs isolés."""
    pharma_a = Pharmacy(name="Pharmacie des Lilas", code="LILAS-01", plan="pro")
    pharma_b = Pharmacy(name="Pharmacie du Soleil", code="SOLEIL-02", plan="pro")
    db.add_all([pharma_a, pharma_b])
    db.commit()
    db.refresh(pharma_a)
    db.refresh(pharma_b)

    user_a = User(
        username="admin_lilas",
        password_hash=hash_password("PassLilas@123"),
        role=UserRole.SUPER_ADMIN,
        is_active=True,
        must_change_password=False,
        pharmacy_id=pharma_a.id,
    )
    user_b = User(
        username="admin_soleil",
        password_hash=hash_password("PassSoleil@123"),
        role=UserRole.SUPER_ADMIN,
        is_active=True,
        must_change_password=False,
        pharmacy_id=pharma_b.id,
    )
    db.add_all([user_a, user_b])
    db.commit()
    db.refresh(user_a)
    db.refresh(user_b)

    token_a = create_access_token(data={"sub": user_a.username}, expires_delta=timedelta(hours=1))
    token_b = create_access_token(data={"sub": user_b.username}, expires_delta=timedelta(hours=1))

    return {
        "pharma_a": pharma_a,
        "pharma_b": pharma_b,
        "user_a": user_a,
        "user_b": user_b,
        "headers_a": {"Authorization": f"Bearer {token_a}"},
        "headers_b": {"Authorization": f"Bearer {token_b}"},
    }


class TestCustomersIsolation:
    def test_customers_crud_isolation(self, client, two_tenants):
        headers_a = two_tenants["headers_a"]
        headers_b = two_tenants["headers_b"]

        # Création client dans pharmacie A
        resp_create = client.post(
            "/customers/",
            json={"first_name": "Jean", "last_name": "Dupont", "phone": "+25779001122"},
            headers=headers_a,
        )
        assert resp_create.status_code == 201, resp_create.text
        customer_a_id = resp_create.json()["id"]

        # Pharmacie A voit son client
        resp_list_a = client.get("/customers/", headers=headers_a)
        assert resp_list_a.status_code == 200
        ids_a = [c["id"] for c in resp_list_a.json()["items"]]
        assert customer_a_id in ids_a

        # Pharmacie B ne voit PAS le client de A dans sa liste
        resp_list_b = client.get("/customers/", headers=headers_b)
        assert resp_list_b.status_code == 200
        ids_b = [c["id"] for c in resp_list_b.json()["items"]]
        assert customer_a_id not in ids_b

        # Pharmacie B tente d'accéder au client de A par ID -> 404
        resp_get_b = client.get(f"/customers/{customer_a_id}", headers=headers_b)
        assert resp_get_b.status_code == 404

        # Pharmacie B tente de modifier le client de A -> 404
        resp_put_b = client.put(
            f"/customers/{customer_a_id}",
            json={"first_name": "Piratage"},
            headers=headers_b,
        )
        assert resp_put_b.status_code == 404

        # Pharmacie B tente de supprimer le client de A -> 404
        resp_del_b = client.delete(f"/customers/{customer_a_id}", headers=headers_b)
        assert resp_del_b.status_code == 404


class TestSuppliersIsolation:
    def test_suppliers_crud_isolation(self, client, two_tenants):
        headers_a = two_tenants["headers_a"]
        headers_b = two_tenants["headers_b"]

        # Création fournisseur dans pharmacie A
        resp_create = client.post(
            "/suppliers/",
            json={"name": "Labo Lilas Pharma", "phone": "+25722001122", "email": "contact@lilas.bi"},
            headers=headers_a,
        )
        assert resp_create.status_code == 201, resp_create.text
        supplier_a_id = resp_create.json()["id"]

        # Pharmacie A voit son fournisseur
        resp_list_a = client.get("/suppliers/", headers=headers_a)
        assert resp_list_a.status_code == 200
        ids_a = [s["id"] for s in resp_list_a.json()["items"]]
        assert supplier_a_id in ids_a

        # Pharmacie B ne voit pas le fournisseur de A
        resp_list_b = client.get("/suppliers/", headers=headers_b)
        assert resp_list_b.status_code == 200
        ids_b = [s["id"] for s in resp_list_b.json()["items"]]
        assert supplier_a_id not in ids_b

        # Pharmacie B tente GET, PUT, DELETE par ID étranger -> 404
        assert client.get(f"/suppliers/{supplier_a_id}", headers=headers_b).status_code == 404
        assert client.put(f"/suppliers/{supplier_a_id}", json={"name": "Piratage"}, headers=headers_b).status_code == 404
        assert client.delete(f"/suppliers/{supplier_a_id}", headers=headers_b).status_code == 404


class TestStockAndMedicinesIsolation:
    def test_medicines_crud_isolation(self, client, two_tenants):
        headers_a = two_tenants["headers_a"]
        headers_b = two_tenants["headers_b"]

        # Création médicament dans pharmacie A
        resp_create = client.post(
            "/stock/medicines",
            json={
                "name": "Doliprane Lilas 1000mg",
                "dosage_form": "Comprimé",
                "packaging": "Boîte",
                "alert_threshold": 10,
                "quantity": 50,
                "price_buy": 1000.0,
                "price_sell": 1500.0,
            },
            headers=headers_a,
        )
        assert resp_create.status_code == 201, resp_create.text
        med_a_id = resp_create.json()["id"]

        # Pharmacie A voit le médicament
        resp_list_a = client.get("/stock/medicines", headers=headers_a)
        assert resp_list_a.status_code == 200
        ids_a = [m["id"] for m in resp_list_a.json()["items"]]
        assert med_a_id in ids_a

        # Pharmacie B ne voit pas le médicament de A
        resp_list_b = client.get("/stock/medicines", headers=headers_b)
        assert resp_list_b.status_code == 200
        ids_b = [m["id"] for m in resp_list_b.json()["items"]]
        assert med_a_id not in ids_b

        # Pharmacie B requêtes directes sur med_a_id -> 404
        assert client.get(f"/stock/medicines/{med_a_id}", headers=headers_b).status_code == 404
        assert client.put(f"/stock/medicines/{med_a_id}", json={"name": "Hacked", "price_buy": 1000.0, "price_sell": 1500.0}, headers=headers_b).status_code == 404
        assert client.delete(f"/stock/medicines/{med_a_id}", headers=headers_b).status_code == 404


class TestPOSSalesIsolation:
    def test_pos_sales_isolation(self, client, two_tenants, db):
        headers_a = two_tenants["headers_a"]
        headers_b = two_tenants["headers_b"]
        pharma_a_id = two_tenants["pharma_a"].id
        user_a_id = two_tenants["user_a"].id

        # Créer vente POS directement attachée à Pharma A
        sale_a = POSSale(
            sale_uuid="pos-uuid-pharma-a-test-isolation-12345",
            code="POS-2026-A-0001",
            user_id=user_a_id,
            pharmacy_id=pharma_a_id,
            total_amount=15000.0,
            payment_method="cash",
            status="completed",
        )
        db.add(sale_a)
        db.commit()
        db.refresh(sale_a)

        # Pharmacie A peut consulter sa vente
        resp_a = client.get(f"/pos/sale/{sale_a.id}", headers=headers_a)
        assert resp_a.status_code == 200, resp_a.text

        # Pharmacie B tente de consulter la vente de A -> 404
        resp_b = client.get(f"/pos/sale/{sale_a.id}", headers=headers_b)
        assert resp_b.status_code == 404

        # Pharmacie B tente d'annuler la vente de A -> rejeté (400 ou 404)
        resp_cancel_b = client.post(
            f"/pos/sale/{sale_a.id}/cancel",
            json={"reason": "Annulation malveillante"},
            headers=headers_b,
        )
        assert resp_cancel_b.status_code in (400, 404)
        # Vérification formelle en DB : la vente de A n'a PAS été modifiée ni annulée
        db.refresh(sale_a)
        assert sale_a.status == "completed"


class TestSettingsIsolation:
    def test_settings_isolation(self, client, two_tenants):
        headers_a = two_tenants["headers_a"]
        headers_b = two_tenants["headers_b"]

        # Pharmacie A modifie son nom
        resp_put_a = client.put(
            "/settings",
            json={"pharmacy_name": "Grande Pharmacie Lilas Internationale"},
            headers=headers_a,
        )
        assert resp_put_a.status_code == 200, resp_put_a.text
        assert resp_put_a.json()["pharmacy_name"] == "Grande Pharmacie Lilas Internationale"

        # Pharmacie B consulte ses settings -> ne doit pas voir le nom de A
        resp_get_b = client.get("/settings", headers=headers_b)
        assert resp_get_b.status_code == 200, resp_get_b.text
        assert resp_get_b.json()["pharmacy_name"] != "Grande Pharmacie Lilas Internationale"


class TestUsersIsolation:
    def test_users_isolation(self, client, two_tenants):
        headers_a = two_tenants["headers_a"]
        headers_b = two_tenants["headers_b"]

        # Pharmacie A crée un pharmacien
        resp_create = client.post(
            "/auth/register",
            json={
                "username": "pharma_aide_lilas",
                "password": "PasswordAide@123",
                "role": "pharmacist",
            },
            headers=headers_a,
        )
        assert resp_create.status_code == 200, resp_create.text
        user_a_id = resp_create.json()["id"]

        # Pharmacie B ne voit pas ce user dans sa liste
        resp_list_b = client.get("/users/", headers=headers_b)
        assert resp_list_b.status_code == 200
        ids_b = [u["id"] for u in resp_list_b.json()]
        assert user_a_id not in ids_b

        # Pharmacie B tente d'accéder au user de A par ID -> 404
        assert client.get(f"/users/{user_a_id}", headers=headers_b).status_code == 404
        # Pharmacie B tente de modifier le mot de passe du user de A -> 404
        assert client.post(f"/users/{user_a_id}/password", json={"password": "NewSecret@123"}, headers=headers_b).status_code == 404
        # Pharmacie B tente de supprimer le user de A -> 404
        assert client.delete(f"/users/{user_a_id}", headers=headers_b).status_code == 404

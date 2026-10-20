"""
test_auth.py — Tests d'intégration des endpoints d'authentification.

Couvre :
  - POST /auth/login  (succès, mauvais mdp, user inactif, rate limit)
  - GET  /auth/me     (token valide, token absent, token expiré)
  - POST /auth/register (admin crée user, non-admin refusé, doublon refusé)
  - Changement de mot de passe initial
"""

import pytest
import os

os.environ.setdefault("SECRET_KEY", "test-secret-key-pharmagestion-32chars!!")
os.environ.setdefault("DB_URL_LOCAL", "sqlite:///:memory:")

from datetime import timedelta
from app.utils.security import create_access_token


# ═══════════════════════════════════════════════════════════════════════════════
# LOGIN
# ═══════════════════════════════════════════════════════════════════════════════

class TestLogin:
    def test_login_valide_retourne_token(self, client, admin_user):
        """Un admin peut se connecter et reçoit un JWT."""
        resp = client.post("/auth/login", data={
            "username": "test_admin",
            "password": "Admin@123!",
        })
        assert resp.status_code == 200
        body = resp.json()
        assert "access_token" in body
        assert body["token_type"] == "bearer"
        assert isinstance(body["access_token"], str)
        assert len(body["access_token"]) > 20

    def test_login_mauvais_mot_de_passe_retourne_401(self, client, admin_user):
        resp = client.post("/auth/login", data={
            "username": "test_admin",
            "password": "mauvais_mdp",
        })
        assert resp.status_code == 401

    def test_login_utilisateur_inexistant_retourne_401(self, client):
        resp = client.post("/auth/login", data={
            "username": "utilisateur_fantome",
            "password": "nimportequoi",
        })
        assert resp.status_code == 401

    def test_login_utilisateur_inactif_retourne_400(self, client, db):
        """Un compte désactivé ne peut pas se connecter."""
        from app.models.user import User, UserRole
        from app.utils.security import hash_password

        user = User(
            username="inactif_user",
            password_hash=hash_password("Pass@123!"),
            role=UserRole.PHARMACIST,
            is_active=False,
        )
        db.add(user)
        db.commit()

        resp = client.post("/auth/login", data={
            "username": "inactif_user",
            "password": "Pass@123!",
        })
        assert resp.status_code == 400

    def test_login_retourne_must_change_password(self, client, db):
        """Le champ must_change_password est retourné après login."""
        from app.models.user import User, UserRole
        from app.utils.security import hash_password

        user = User(
            username="new_user",
            password_hash=hash_password("Temp@123!"),
            role=UserRole.PHARMACIST,
            is_active=True,
            must_change_password=True,
        )
        db.add(user)
        db.commit()

        resp = client.post("/auth/login", data={
            "username": "new_user",
            "password": "Temp@123!",
        })
        assert resp.status_code == 200
        assert resp.json()["must_change_password"] is True

    def test_login_username_case_sensitive(self, client, admin_user):
        """Le login est case-sensitive."""
        resp = client.post("/auth/login", data={
            "username": "TEST_ADMIN",
            "password": "Admin@123!",
        })
        assert resp.status_code == 401

    def test_login_sans_credentials_retourne_422(self, client):
        resp = client.post("/auth/login")
        assert resp.status_code == 422


# ═══════════════════════════════════════════════════════════════════════════════
# GET /auth/me
# ═══════════════════════════════════════════════════════════════════════════════

class TestGetMe:
    def test_get_me_avec_token_valide(self, client, admin_user, admin_headers):
        resp = client.get("/auth/me", headers=admin_headers)
        assert resp.status_code == 200
        body = resp.json()
        assert body["username"] == "test_admin"
        assert "password_hash" not in body  # Ne jamais exposer le hash

    def test_get_me_sans_token_retourne_401(self, client):
        resp = client.get("/auth/me")
        assert resp.status_code == 401

    def test_get_me_token_invalide_retourne_401(self, client):
        resp = client.get("/auth/me", headers={"Authorization": "Bearer token.invalide"})
        assert resp.status_code == 401

    def test_get_me_token_expire_retourne_401(self, client, admin_user):
        expired_token = create_access_token(
            data={"sub": admin_user.username},
            expires_delta=timedelta(seconds=-1),
        )
        resp = client.get("/auth/me", headers={"Authorization": f"Bearer {expired_token}"})
        assert resp.status_code == 401

    def test_get_me_retourne_role(self, client, admin_user, admin_headers):
        resp = client.get("/auth/me", headers=admin_headers)
        body = resp.json()
        assert "role" in body

    def test_get_me_pharmacien(self, client, pharmacist_user, pharmacist_headers):
        resp = client.get("/auth/me", headers=pharmacist_headers)
        assert resp.status_code == 200
        assert resp.json()["username"] == "test_pharmacist"


class TestPharmacyContext:
    def test_context_resolves_pharmacy_from_user(self, db):
        import asyncio

        from app.auth.dependencies import get_current_pharmacy_context
        from app.models.pharmacy import Pharmacy
        from app.models.user import User

        pharmacy = Pharmacy(name="Tenant A", code="TENANT-A")
        db.add(pharmacy)
        db.commit()
        db.refresh(pharmacy)

        user = User(
            username="tenant_user",
            password_hash="hash",
            role="admin",
            pharmacy_id=pharmacy.id,
        )
        context = asyncio.run(get_current_pharmacy_context(user, db))

        assert context.pharmacy_id == pharmacy.id
        assert context.is_platform_admin is False

    def test_context_rejects_user_without_pharmacy(self, db):
        import asyncio

        from fastapi import HTTPException

        from app.auth.dependencies import get_current_pharmacy_context
        from app.models.user import User

        user = User(
            username="unassigned_user",
            password_hash="hash",
            role="admin",
        )

        with pytest.raises(HTTPException) as error:
            asyncio.run(get_current_pharmacy_context(user, db))

        assert error.value.status_code == 403

    def test_platform_admin_has_unscoped_context(self, db):
        import asyncio

        from app.auth.dependencies import get_current_pharmacy_context
        from app.models.user import User, UserRole

        user = User(
            username="platform_admin",
            password_hash="hash",
            role=UserRole.PLATFORM_ADMIN,
        )
        context = asyncio.run(get_current_pharmacy_context(user, db))

        assert context.pharmacy_id is None
        assert context.is_platform_admin is True

    def test_platform_admin_cannot_use_pharmacy_customer_routes(self, client, db):
        from app.models.user import User, UserRole
        from app.utils.security import create_access_token

        user = User(
            username="platform_admin_blocked_from_pharmacy_routes",
            password_hash="hash",
            role=UserRole.PLATFORM_ADMIN,
        )
        db.add(user)
        db.commit()
        token = create_access_token(
            data={"sub": user.username},
            expires_delta=timedelta(minutes=60),
        )

        response = client.get(
            "/customers/",
            headers={"Authorization": f"Bearer {token}"},
        )

        assert response.status_code == 403

    def test_platform_guard_rejects_pharmacy_super_admin(self):
        import asyncio

        from fastapi import HTTPException

        from app.auth.dependencies import require_platform_admin
        from app.models.user import User, UserRole

        user = User(
            username="pharmacy_super_admin",
            password_hash="hash",
            role=UserRole.SUPER_ADMIN,
        )

        with pytest.raises(HTTPException) as error:
            asyncio.run(require_platform_admin(user))

        assert error.value.status_code == 403

    def test_license_bypass_sets_pharmacy_scope(self, db, pharmacy):
        import asyncio

        from app.auth.dependencies import get_super_admin_user_bypass_license
        from app.models.user import User, UserRole

        user = User(
            username="license_bypass_admin",
            password_hash="hash",
            role=UserRole.SUPER_ADMIN,
            pharmacy_id=pharmacy.id,
        )
        db.add(user)
        db.commit()
        token = create_access_token(
            data={"sub": user.username},
            expires_delta=timedelta(minutes=60),
        )

        resolved_user = asyncio.run(
            get_super_admin_user_bypass_license(token=token, db=db)
        )

        assert resolved_user.id == user.id
        assert db.info["pharmacy_scope_enabled"] is True
        assert db.info["pharmacy_id"] == pharmacy.id

    def test_customer_api_is_scoped_to_authenticated_pharmacy(self, client, db):
        from app.models.customer import Customer
        from app.models.pharmacy import Pharmacy
        from app.models.user import User, UserRole
        from app.utils.security import create_access_token

        pharmacy_a = Pharmacy(name="Tenant A", code="TENANT-A-API", plan="pro")
        pharmacy_b = Pharmacy(name="Tenant B", code="TENANT-B-API")
        db.add_all([pharmacy_a, pharmacy_b])
        db.commit()
        db.refresh(pharmacy_a)
        db.refresh(pharmacy_b)

        user_a = User(
            username="tenant_api_user_a",
            password_hash="hash",
            role=UserRole.SUPER_ADMIN,
            pharmacy_id=pharmacy_a.id,
        )
        customer_a = Customer(
            first_name="Customer",
            last_name="A",
            phone="22500000001",
            pharmacy_id=pharmacy_a.id,
        )
        customer_b = Customer(
            first_name="Customer",
            last_name="B",
            phone="22500000002",
            pharmacy_id=pharmacy_b.id,
        )
        db.add_all([user_a, customer_a, customer_b])
        db.commit()
        db.refresh(customer_b)

        token = create_access_token(
            data={"sub": user_a.username},
            expires_delta=timedelta(minutes=60),
        )
        headers = {"Authorization": f"Bearer {token}"}

        customer_list = client.get("/customers/", headers=headers)
        assert customer_list.status_code == 200
        assert [item["last_name"] for item in customer_list.json()["items"]] == ["A"]

        cross_tenant_read = client.get(f"/customers/{customer_b.id}", headers=headers)
        assert cross_tenant_read.status_code == 404

        created = client.post("/customers/", json={
            "first_name": "New",
            "last_name": "Customer",
            "phone": "22500000003",
        }, headers=headers)
        assert created.status_code == 201
        created_customer = db.query(Customer).filter(
            Customer.phone == "22500000003"
        ).one()
        assert created_customer.pharmacy_id == pharmacy_a.id

    def test_write_rejects_foreign_pharmacy_reference(self, db):
        from fastapi import HTTPException

        from app.models.customer import Customer
        from app.models.pharmacy import Pharmacy
        from app.models.sales import Sale
        from app.models.user import User, UserRole

        pharmacy_a = Pharmacy(name="Tenant A", code="TENANT-A-FK")
        pharmacy_b = Pharmacy(name="Tenant B", code="TENANT-B-FK")
        db.add_all([pharmacy_a, pharmacy_b])
        db.commit()
        db.refresh(pharmacy_a)
        db.refresh(pharmacy_b)

        user_a = User(
            username="tenant_fk_user_a",
            password_hash="hash",
            role=UserRole.SUPER_ADMIN,
            pharmacy_id=pharmacy_a.id,
        )
        customer_b = Customer(
            first_name="Foreign",
            last_name="Customer",
            phone="22500000004",
            pharmacy_id=pharmacy_b.id,
        )
        db.add_all([user_a, customer_b])
        db.commit()

        db.info.update({
            "pharmacy_scope_enabled": True,
            "pharmacy_id": pharmacy_a.id,
            "is_platform_admin": False,
        })
        sale = Sale(
            code="TENANT-A-CROSS-REF",
            total_amount=100,
            user_id=user_a.id,
            customer_id=customer_b.id,
        )
        db.add(sale)

        with pytest.raises(HTTPException) as error:
            db.commit()

        assert error.value.status_code == 404
        db.rollback()

    def test_bulk_delete_only_affects_current_pharmacy(self, db):
        from app.models.customer import Customer
        from app.models.pharmacy import Pharmacy

        pharmacy_a = Pharmacy(name="Tenant A", code="TENANT-A-BULK")
        pharmacy_b = Pharmacy(name="Tenant B", code="TENANT-B-BULK")
        db.add_all([pharmacy_a, pharmacy_b])
        db.commit()
        db.refresh(pharmacy_a)
        db.refresh(pharmacy_b)

        db.add_all([
            Customer(first_name="Bulk", last_name="A", phone="22500000005", pharmacy_id=pharmacy_a.id),
            Customer(first_name="Bulk", last_name="B", phone="22500000006", pharmacy_id=pharmacy_b.id),
        ])
        db.commit()
        db.info.update({
            "pharmacy_scope_enabled": True,
            "pharmacy_id": pharmacy_a.id,
            "is_platform_admin": False,
        })

        deleted = db.query(Customer).delete(synchronize_session=False)
        db.commit()
        db.info["pharmacy_scope_enabled"] = False

        remaining = db.query(Customer).all()
        assert deleted == 1
        assert [customer.pharmacy_id for customer in remaining] == [pharmacy_b.id]

    def test_phone_uniqueness_is_per_pharmacy(self, db):
        from app.models.customer import Customer
        from app.models.pharmacy import Pharmacy

        pharmacy_a = Pharmacy(name="Tenant A", code="TENANT-A-PHONE")
        pharmacy_b = Pharmacy(name="Tenant B", code="TENANT-B-PHONE")
        db.add_all([pharmacy_a, pharmacy_b])
        db.commit()
        db.refresh(pharmacy_a)
        db.refresh(pharmacy_b)

        db.add_all([
            Customer(first_name="Same", last_name="Phone", phone="22500000007", pharmacy_id=pharmacy_a.id),
            Customer(first_name="Same", last_name="Phone", phone="22500000007", pharmacy_id=pharmacy_b.id),
        ])
        db.commit()

        assert db.query(Customer).count() == 2

    def test_pharmacy_admin_cannot_modify_user_from_another_pharmacy(
        self, client, db, admin_user, admin_headers
    ):
        from app.models.pharmacy import Pharmacy
        from app.models.user import User, UserRole
        from app.utils.security import hash_password, verify_password

        foreign_pharmacy = Pharmacy(name="Foreign Tenant", code="TENANT-USER-API-B")
        db.add(foreign_pharmacy)
        db.commit()
        db.refresh(foreign_pharmacy)

        foreign_user = User(
            username="foreign_tenant_user",
            password_hash=hash_password("Original@123!"),
            role=UserRole.PHARMACIST,
            is_active=True,
            pharmacy_id=foreign_pharmacy.id,
        )
        db.add(foreign_user)
        db.commit()
        db.refresh(foreign_user)
        foreign_user_id = foreign_user.id

        attempts = [
            client.post(
                f"/users/{foreign_user_id}/password",
                json={"password": "Changed@123!"},
                headers=admin_headers,
            ),
            client.put(
                f"/users/{foreign_user_id}",
                json={"username": "hijacked_user", "is_active": False},
                headers=admin_headers,
            ),
            client.post(
                f"/users/{foreign_user_id}/toggle-status",
                headers=admin_headers,
            ),
            client.delete(f"/users/{foreign_user_id}", headers=admin_headers),
        ]

        assert [response.status_code for response in attempts] == [404, 404, 404, 404]

        # Turn off the request tenant scope only for this direct fixture integrity check.
        db.info["pharmacy_scope_enabled"] = False
        unchanged_user = db.query(User).filter(User.id == foreign_user_id).one()
        assert unchanged_user.username == "foreign_tenant_user"
        assert unchanged_user.is_active is True
        assert unchanged_user.pharmacy_id == foreign_pharmacy.id
        assert verify_password("Original@123!", unchanged_user.password_hash)

    def test_legacy_auth_user_routes_are_tenant_scoped(
        self, client, db, admin_user, admin_headers
    ):
        from app.models.pharmacy import Pharmacy
        from app.models.sales import Sale
        from app.models.user import User, UserRole
        from app.utils.security import hash_password, verify_password

        foreign_pharmacy = Pharmacy(name="Foreign Auth Tenant", code="TENANT-AUTH-LEGACY-B")
        db.add(foreign_pharmacy)
        db.commit()
        db.refresh(foreign_pharmacy)
        foreign_user = User(
            username="legacy_foreign_user",
            password_hash=hash_password("LegacyOriginal@123!"),
            role=UserRole.PHARMACIST,
            is_active=True,
            pharmacy_id=foreign_pharmacy.id,
        )
        db.add(foreign_user)
        db.commit()
        db.refresh(foreign_user)
        foreign_user_id = foreign_user.id
        foreign_sale = Sale(
            code="LEGACY-FOREIGN-SALE",
            total_amount=250,
            user_id=foreign_user_id,
            pharmacy_id=foreign_pharmacy.id,
        )
        db.add(foreign_sale)
        db.commit()

        listed_users = client.get("/auth/users", headers=admin_headers)
        assert listed_users.status_code == 200
        assert "legacy_foreign_user" not in {
            user["username"] for user in listed_users.json()
        }

        attempts = [
            client.put(
                f"/auth/users/{foreign_user_id}/password",
                json={"password": "LegacyChanged@123!"},
                headers=admin_headers,
            ),
            client.put(
                f"/auth/users/{foreign_user_id}/toggle-status",
                headers=admin_headers,
            ),
            client.delete(f"/auth/users/{foreign_user_id}", headers=admin_headers),
            client.get(
                f"/auth/users/{foreign_user_id}/sales-stats",
                headers=admin_headers,
            ),
        ]
        assert [response.status_code for response in attempts] == [404, 404, 404, 404]

        # The request dependency scoped this session to the admin's pharmacy.
        db.info["pharmacy_scope_enabled"] = False
        unchanged = db.query(User).filter(User.id == foreign_user_id).one()
        assert unchanged.username == "legacy_foreign_user"
        assert unchanged.is_active is True
        assert unchanged.pharmacy_id == foreign_pharmacy.id
        assert verify_password("LegacyOriginal@123!", unchanged.password_hash)

    def test_settings_read_and_update_are_tenant_scoped(
        self, client, db, admin_user, admin_headers, pharmacy
    ):
        from app.models.pharmacy import Pharmacy
        from app.models.settings import Settings

        pharmacy.plan = "pro"
        foreign_pharmacy = Pharmacy(name="Foreign Settings Tenant", code="TENANT-SETTINGS-API-B", plan="pro")
        db.add(foreign_pharmacy)
        db.commit()
        db.refresh(foreign_pharmacy)
        db.add_all([
            Settings(key="pharmacy_name", value="Pharmacie A", pharmacy_id=pharmacy.id),
            Settings(key="pharmacy_name", value="Pharmacie B", pharmacy_id=foreign_pharmacy.id),
        ])
        db.commit()

        read_response = client.get("/settings", headers=admin_headers)
        assert read_response.status_code == 200, read_response.text
        assert read_response.json()["pharmacy_name"] == "Pharmacie A"

        update_response = client.put(
            "/settings",
            json={"pharmacy_name": "Pharmacie A Modifiée"},
            headers=admin_headers,
        )
        assert update_response.status_code == 200, update_response.text
        assert update_response.json()["pharmacy_name"] == "Pharmacie A Modifiée"

        db.info["pharmacy_scope_enabled"] = False
        values = {
            setting.pharmacy_id: setting.value
            for setting in db.query(Settings).filter(Settings.key == "pharmacy_name").all()
        }
        assert values == {
            pharmacy.id: "Pharmacie A Modifiée",
            foreign_pharmacy.id: "Pharmacie B",
        }

    def test_stock_and_sales_id_routes_hide_foreign_tenant_records(
        self, client, db, admin_user, admin_headers, pharmacy
    ):
        from datetime import datetime

        from app.models.medicine import Medicine
        from app.models.pharmacy import Pharmacy
        from app.models.sales import Sale
        from app.models.user import User, UserRole

        pharmacy.plan = "pro"
        foreign_pharmacy = Pharmacy(
            name="Foreign Inventory Tenant",
            code="TENANT-INVENTORY-API-B",
            plan="pro",
        )
        db.add(foreign_pharmacy)
        db.commit()
        db.refresh(foreign_pharmacy)
        foreign_user = User(
            username="foreign_inventory_seller",
            password_hash="test-hash",
            role=UserRole.PHARMACIST,
            is_active=True,
            pharmacy_id=foreign_pharmacy.id,
        )
        foreign_medicine = Medicine(
            code="FOREIGN-MED-API-01",
            name="Foreign Tenant Medicine",
            quantity=17,
            pharmacy_id=foreign_pharmacy.id,
        )
        db.add_all([foreign_user, foreign_medicine])
        db.commit()
        db.refresh(foreign_user)
        db.refresh(foreign_medicine)
        foreign_medicine_id = foreign_medicine.id

        foreign_sale = Sale(
            code="FOREIGN-SALE-API-01",
            total_amount=500,
            payment_method="cash",
            date=datetime.now(),
            user_id=foreign_user.id,
            status="completed",
            pharmacy_id=foreign_pharmacy.id,
        )
        db.add(foreign_sale)
        db.commit()
        db.refresh(foreign_sale)
        foreign_sale_id = foreign_sale.id

        attempts = [
            client.get(f"/stock/medicines/{foreign_medicine_id}", headers=admin_headers),
            client.put(
                f"/stock/medicines/{foreign_medicine_id}",
                json={"name": "Hijacked medicine"},
                headers=admin_headers,
            ),
            client.delete(f"/stock/medicines/{foreign_medicine_id}", headers=admin_headers),
            client.get(f"/sales/{foreign_sale_id}", headers=admin_headers),
            client.get(f"/sales/{foreign_sale_id}/invoice", headers=admin_headers),
            client.post(f"/sales/{foreign_sale_id}/cancel", headers=admin_headers),
        ]
        assert [response.status_code for response in attempts] == [
            404, 404, 404, 404, 404, 404,
        ]

        # Verify the foreign tenant's records were untouched, from an unscoped test fixture view.
        db.info["pharmacy_scope_enabled"] = False
        unchanged_medicine = db.query(Medicine).filter(
            Medicine.id == foreign_medicine_id
        ).one()
        unchanged_sale = db.query(Sale).filter(Sale.id == foreign_sale_id).one()
        assert unchanged_medicine.name == "Foreign Tenant Medicine"
        assert unchanged_medicine.quantity == 17
        assert unchanged_medicine.pharmacy_id == foreign_pharmacy.id
        assert unchanged_sale.status == "completed"
        assert unchanged_sale.pharmacy_id == foreign_pharmacy.id

    def test_restock_rejects_foreign_supplier_and_medicine_references(
        self, client, db, admin_user, admin_headers, pharmacy
    ):
        from app.models.medicine import Medicine
        from app.models.pharmacy import Pharmacy
        from app.models.restock import RestockOrder
        from app.models.supplier import Supplier
        from app.models.user import User, UserRole

        pharmacy.plan = "pro"
        foreign_pharmacy = Pharmacy(
            name="Foreign Restock Tenant",
            code="TENANT-RESTOCK-API-B",
            plan="pro",
        )
        db.add(foreign_pharmacy)
        db.commit()
        db.refresh(foreign_pharmacy)
        foreign_supplier = Supplier(
            name="Foreign Supplier",
            pharmacy_id=foreign_pharmacy.id,
        )
        own_supplier = Supplier(name="Own Supplier", pharmacy_id=pharmacy.id)
        foreign_medicine = Medicine(
            code="FOREIGN-RESTOCK-MED",
            name="Foreign Restock Medicine",
            pharmacy_id=foreign_pharmacy.id,
        )
        own_medicine = Medicine(
            code="OWN-RESTOCK-MED",
            name="Own Restock Medicine",
            pharmacy_id=pharmacy.id,
        )
        foreign_user = User(
            username="foreign_restock_user",
            password_hash="test-hash",
            role=UserRole.PHARMACIST,
            is_active=True,
            pharmacy_id=foreign_pharmacy.id,
        )
        db.add_all([foreign_supplier, own_supplier, foreign_medicine, own_medicine, foreign_user])
        db.commit()
        for row in (foreign_supplier, own_supplier, foreign_medicine, foreign_user):
            db.refresh(row)

        payload_base = {
            "date": "2026-10-19",
            "items": [{
                "medicine_id": own_medicine.id,
                "quantity": 2,
                "price_buy": 10,
            }],
        }
        foreign_supplier_response = client.post(
            "/restock/create",
            json={**payload_base, "supplier_id": foreign_supplier.id},
            headers=admin_headers,
        )
        assert foreign_supplier_response.status_code == 404

        foreign_medicine_payload = {
            **payload_base,
            "supplier_id": own_supplier.id,
            "items": [{
                "medicine_id": foreign_medicine.id,
                "quantity": 2,
                "price_buy": 10,
            }],
        }
        foreign_medicine_response = client.post(
            "/restock/create",
            json=foreign_medicine_payload,
            headers=admin_headers,
        )
        assert foreign_medicine_response.status_code == 404
        assert db.query(RestockOrder).count() == 0

    def test_admin_reset_bulk_operations_only_affect_own_pharmacy(
        self, client, db, admin_user, admin_headers, pharmacy
    ):
        from app.models.customer import Customer
        from app.models.medicine import Medicine
        from app.models.pharmacy import Pharmacy
        from app.models.sales import Sale
        from app.models.user import User, UserRole

        foreign_pharmacy = Pharmacy(name="Foreign Reset Tenant", code="TENANT-RESET-API-B")
        db.add(foreign_pharmacy)
        db.commit()
        db.refresh(foreign_pharmacy)
        own_customer = Customer(
            first_name="Own", last_name="Customer", phone="22500000081",
            pharmacy_id=pharmacy.id,
        )
        foreign_customer = Customer(
            first_name="Foreign", last_name="Customer", phone="22500000082",
            pharmacy_id=foreign_pharmacy.id,
        )
        own_medicine = Medicine(
            code="RESET-OWN-MED", name="Own Reset Medicine", quantity=5,
            pharmacy_id=pharmacy.id,
        )
        foreign_medicine = Medicine(
            code="RESET-FOREIGN-MED", name="Foreign Reset Medicine", quantity=9,
            pharmacy_id=foreign_pharmacy.id,
        )
        foreign_user = User(
            username="foreign_reset_user",
            password_hash="test-hash",
            role=UserRole.PHARMACIST,
            is_active=True,
            pharmacy_id=foreign_pharmacy.id,
        )
        db.add_all([
            own_customer, foreign_customer, own_medicine, foreign_medicine, foreign_user,
        ])
        db.commit()
        db.refresh(foreign_user)
        db.refresh(own_medicine)
        db.refresh(foreign_medicine)
        own_sale = Sale(
            code="RESET-OWN-SALE", total_amount=100, user_id=admin_user.id,
            customer_id=own_customer.id, pharmacy_id=pharmacy.id,
        )
        foreign_sale = Sale(
            code="RESET-FOREIGN-SALE", total_amount=200, user_id=foreign_user.id,
            customer_id=foreign_customer.id, pharmacy_id=foreign_pharmacy.id,
        )
        db.add_all([own_sale, foreign_sale])
        db.commit()

        response = client.post(
            "/admin/reset",
            json={"sales": True, "products": True, "users": True},
            headers=admin_headers,
        )
        assert response.status_code == 200, response.text

        # Check fixture state through an explicitly unscoped inspection only.
        db.info["pharmacy_scope_enabled"] = False
        assert db.query(Sale).filter(Sale.pharmacy_id == pharmacy.id).count() == 0
        assert db.query(Medicine).filter(Medicine.pharmacy_id == pharmacy.id).count() == 0
        assert db.query(User).filter(User.pharmacy_id == pharmacy.id, User.id != admin_user.id).count() == 0
        assert db.query(Sale).filter(Sale.pharmacy_id == foreign_pharmacy.id).count() == 1
        assert db.query(Medicine).filter(Medicine.pharmacy_id == foreign_pharmacy.id).count() == 1
        assert db.query(User).filter(User.pharmacy_id == foreign_pharmacy.id).count() == 1


# ═══════════════════════════════════════════════════════════════════════════════
# POST /auth/register
# ═══════════════════════════════════════════════════════════════════════════════

class TestRegister:
    def test_admin_ne_peut_pas_creer_platform_admin(self, client, admin_user, admin_headers):
        response = client.post("/auth/register", json={
            "username": "forbidden_platform_admin",
            "password": "NewPass@123!",
            "role": "platform_admin",
        }, headers=admin_headers)

        assert response.status_code == 403

    def test_admin_ne_peut_pas_depasse_limite_utilisateurs(
        self, client, db, pharmacy, admin_headers
    ):
        pharmacy.max_users = 1
        db.commit()

        response = client.post("/auth/register", json={
            "username": "over_limit_user",
            "password": "NewPass@123!",
            "role": "pharmacist",
        }, headers=admin_headers)

        assert response.status_code == 409
        assert response.json()["detail"] == "User limit reached for this pharmacy"

    def test_admin_peut_creer_utilisateur(self, client, db, admin_user, admin_headers):
        resp = client.post("/auth/register", json={
            "username": "nouveau_pharma",
            "password": "NewPass@123!",
            "role": "pharmacist",
            "is_active": True,
        }, headers=admin_headers)
        assert resp.status_code == 200
        body = resp.json()
        assert body["username"] == "nouveau_pharma"
        assert "password_hash" not in body
        from app.models.user import User
        created_user = db.query(User).filter(User.username == "nouveau_pharma").one()
        assert created_user.pharmacy_id == admin_user.pharmacy_id

    def test_pharmacien_ne_peut_pas_creer_utilisateur(
        self, client, pharmacist_user, pharmacist_headers
    ):
        resp = client.post("/auth/register", json={
            "username": "autre_user",
            "password": "Pass@123!",
            "role": "pharmacist",
        }, headers=pharmacist_headers)
        assert resp.status_code == 403

    def test_creation_doublon_username_retourne_400(self, client, admin_user, admin_headers):
        # Créer le premier utilisateur
        client.post("/auth/register", json={
            "username": "doublon_user",
            "password": "Pass@123!",
            "role": "pharmacist",
        }, headers=admin_headers)

        # Tenter de créer le même username
        resp = client.post("/auth/register", json={
            "username": "doublon_user",
            "password": "AutrePass@123!",
            "role": "pharmacist",
        }, headers=admin_headers)
        assert resp.status_code == 400

    def test_creation_sans_token_retourne_401(self, client):
        resp = client.post("/auth/register", json={
            "username": "user_anon",
            "password": "Pass@123!",
            "role": "pharmacist",
        })
        assert resp.status_code == 401

    def test_utilisateur_cree_doit_changer_mdp(self, client, admin_user, admin_headers):
        """Un nouvel utilisateur a must_change_password=True par défaut."""
        resp = client.post("/auth/register", json={
            "username": "must_change",
            "password": "Temp@123!",
            "role": "pharmacist",
        }, headers=admin_headers)
        assert resp.status_code == 200
        assert resp.json()["must_change_password"] is True


class TestLicenseStatus:
    def test_license_status_requires_authentication(self, client):
        response = client.get("/license/status")

        assert response.status_code == 401

    def test_customer_loyalty_is_enterprise_only(
        self, client, db, admin_user, admin_headers, pharmacy
    ):
        from app.core.license import license_service

        pharmacy.plan = "pro"
        db.commit()
        license_service.invalidate_cache()
        pro_status = client.get("/license/status", headers=admin_headers)

        pharmacy.plan = "enterprise"
        db.commit()
        license_service.invalidate_cache()
        enterprise_status = client.get("/license/status", headers=admin_headers)
        license_service.invalidate_cache()

        assert pro_status.status_code == 200
        assert "customer_management" in pro_status.json()["available_features"]
        assert "customer_loyalty" not in pro_status.json()["available_features"]
        assert enterprise_status.status_code == 200
        assert "customer_loyalty" in enterprise_status.json()["available_features"]

    def test_license_status_is_scoped_to_authenticated_pharmacy(
        self, client, db, admin_user, admin_headers, pharmacy
    ):
        from datetime import date, timedelta

        from app.core.license import license_service
        from app.models.pharmacy import Pharmacy
        from app.models.settings import Settings
        from app.models.user import User, UserRole

        other_pharmacy = Pharmacy(name="Other Pharmacy", code="LICENSE-OTHER")
        db.add(other_pharmacy)
        db.flush()
        other_user = User(
            username="other_license_admin",
            password_hash="unused",
            role=UserRole.ADMIN,
            is_active=True,
            pharmacy_id=other_pharmacy.id,
        )
        db.add_all([
            other_user,
            Settings(
                key="license_expiry_date",
                value=(date.today() + timedelta(days=180)).isoformat(),
                pharmacy_id=pharmacy.id,
            ),
            Settings(
                key="license_expiry_date",
                value=(date.today() - timedelta(days=1)).isoformat(),
                pharmacy_id=other_pharmacy.id,
            ),
        ])
        db.commit()
        other_token = create_access_token(
            data={"sub": other_user.username},
            expires_delta=timedelta(minutes=60),
        )
        license_service.invalidate_cache()

        first = client.get("/license/status", headers=admin_headers)
        db.info.clear()
        second = client.get(
            "/license/status",
            headers={"Authorization": f"Bearer {other_token}"},
        )

        assert first.status_code == 200, first.text
        assert first.json()["is_valid"] is True
        assert first.json()["plan"] == "basic"
        assert first.json()["max_users"] == pharmacy.max_users
        assert first.json()["active_users"] == 1
        assert first.json()["available_features"] == []
        assert second.status_code == 200, second.text
        assert second.json()["is_expired"] is True
        license_service.invalidate_cache()

    def test_expired_super_admin_can_renew_but_not_use_business_routes(
        self, client, db, admin_user, admin_headers, pharmacy
    ):
        from datetime import date, timedelta

        from app.core.license import license_service
        from app.models.settings import Settings

        db.add(Settings(
            key="license_expiry_date",
            value=(date.today() - timedelta(days=1)).isoformat(),
            pharmacy_id=pharmacy.id,
        ))
        db.commit()
        license_service.invalidate_cache()

        profile = client.get("/auth/me", headers=admin_headers)
        blocked_business_route = client.get(
            "/reports/stock/pdf", headers=admin_headers
        )
        renewed = client.put(
            "/license/update",
            headers=admin_headers,
            json={
                "expiration_date": (date.today() + timedelta(days=365)).isoformat(),
                "warning_days": 30,
                "warning_message": "Renewed",
            },
        )

        assert profile.status_code == 200, profile.text
        assert blocked_business_route.status_code == 403
        assert renewed.status_code == 200, renewed.text
        assert renewed.json()["license_status"]["status"] == "valid"
        license_service.invalidate_cache()


class TestPlanAccess:
    def test_platform_admin_has_no_pharmacy_feature_access(self, client, db):
        from app.models.user import User, UserRole

        platform_admin = User(
            username="platform_has_no_tenant_features",
            password_hash="unused",
            role=UserRole.PLATFORM_ADMIN,
            is_active=True,
            pharmacy_id=None,
        )
        db.add(platform_admin)
        db.commit()
        token = create_access_token(
            data={"sub": platform_admin.username},
            expires_delta=timedelta(minutes=60),
        )

        response = client.get(
            "/customers/",
            headers={"Authorization": f"Bearer {token}"},
        )

        assert response.status_code == 403
        assert response.json()["detail"] == (
            "Platform administrators do not have pharmacy feature access"
        )

    def test_basic_pharmacy_cannot_access_customer_management(
        self, client, db, admin_user, admin_headers, pharmacy
    ):
        pharmacy.plan = "basic"
        db.commit()

        response = client.get("/customers/", headers=admin_headers)

        assert response.status_code == 403
        assert response.json()["detail"]["error"] == "PLAN_UPGRADE_REQUIRED"

    def test_pro_pharmacy_can_access_customer_management(
        self, client, db, admin_user, admin_headers, pharmacy
    ):
        pharmacy.plan = "pro"
        db.commit()

        response = client.get("/customers/", headers=admin_headers)

        assert response.status_code == 200

    def test_basic_pharmacy_cannot_push_cloud_sync(
        self, client, db, admin_user, admin_headers, pharmacy
    ):
        pharmacy.plan = "basic"
        db.commit()

        response = client.post("/sync/push", headers=admin_headers)

        assert response.status_code == 403
        assert response.json()["detail"]["error"] == "PLAN_UPGRADE_REQUIRED"

    @pytest.mark.parametrize(
        "path",
        [
            "/reports/financial/pdf",
            "/reports/sales/pdf",
            "/reports/stock/excel",
            "/dashboard/cancelled-sales",
            "/pos/user-sales-summary",
            "/pos/reports/top-medicines",
            "/stock/movements",
            "/stock/integrity",
            "/stock/audit-logs",
        ],
    )
    def test_basic_pharmacy_cannot_access_advanced_reports_or_inventory(
        self, client, db, admin_user, admin_headers, pharmacy, path
    ):
        pharmacy.plan = "basic"
        db.commit()

        response = client.get(path, headers=admin_headers)

        assert response.status_code == 403
        assert response.json()["detail"]["error"] == "PLAN_UPGRADE_REQUIRED"

    def test_basic_pharmacy_cannot_fix_stock_integrity(
        self, client, db, admin_user, admin_headers, pharmacy
    ):
        pharmacy.plan = "basic"
        db.commit()

        response = client.post("/stock/integrity/fix", headers=admin_headers)

        assert response.status_code == 403
        assert response.json()["detail"]["error"] == "PLAN_UPGRADE_REQUIRED"

    @pytest.mark.parametrize(
        ("method", "path", "payload"),
        [
            ("POST", "/users/{user_id}/toggle-status", None),
            ("PUT", "/users/{user_id}", {"is_active": True}),
            ("PUT", "/auth/users/{user_id}/toggle-status", None),
        ],
    )
    def test_reactivation_cannot_exceed_user_quota(
        self, client, db, admin_user, admin_headers, pharmacy,
        method, path, payload,
    ):
        from app.models.user import User, UserRole

        pharmacy.max_users = 1
        inactive_user = User(
            username="inactive_at_user_limit",
            password_hash="unused",
            role=UserRole.PHARMACIST,
            is_active=False,
            pharmacy_id=pharmacy.id,
        )
        db.add(inactive_user)
        db.commit()
        db.refresh(inactive_user)

        response = client.request(
            method,
            path.format(user_id=inactive_user.id),
            headers=admin_headers,
            json=payload,
        )

        assert response.status_code == 409
        assert response.json()["detail"] == "User limit reached for this pharmacy"

    def test_basic_checkout_cannot_apply_discount(
        self, client, db, admin_user, admin_headers, pharmacy
    ):
        pharmacy.plan = "basic"
        db.commit()

        response = client.post(
            "/pos/checkout",
            headers=admin_headers,
            json={
                "items": [{
                    "medicine_id": 1,
                    "allocations": [{"batch_id": 1, "quantity": 1}],
                    "quantity": 1,
                    "unit_price": 100,
                    "discount_percent": 10,
                }],
                "payment_method": "cash",
            },
        )

        assert response.status_code == 403
        assert response.json()["detail"]["error"] == "PLAN_UPGRADE_REQUIRED"

    @pytest.mark.parametrize(
        ("plan", "expected_bonus"),
        [("pro", 0), ("enterprise", 2)],
    )
    def test_pos_checkout_credits_loyalty_only_on_enterprise(
        self, client, db, admin_user, admin_headers, pharmacy, open_cash_session, plan, expected_bonus
    ):
        from datetime import date, timedelta

        from app.models.batch import Batch
        from app.models.customer import Customer
        from app.models.medicine import Medicine

        pharmacy.plan = plan
        medicine = Medicine(
            code=f"LOYALTY-{plan.upper()}",
            name="Loyalty Test Medicine",
            quantity=10,
            price_sell=1000,
            units_per_packaging=1,
            pharmacy_id=pharmacy.id,
        )
        customer = Customer(
            first_name="Test",
            last_name="Customer",
            phone=f"225{len(plan):08d}",
            total_points=0,
            pharmacy_id=pharmacy.id,
        )
        batch = Batch(
            batch_number=f"LOT-{plan.upper()}",
            medicine=medicine,
            expiration_date=date.today() + timedelta(days=365),
            quantity=10,
            pharmacy_id=pharmacy.id,
        )
        db.add_all([medicine, customer, batch])
        db.commit()
        db.refresh(medicine)
        db.refresh(customer)
        db.refresh(batch)

        response = client.post(
            "/pos/checkout",
            headers=admin_headers,
            json={
                "items": [{
                    "medicine_id": medicine.id,
                    "allocations": [{"batch_id": batch.id, "quantity": 2}],
                    "quantity": 2,
                    "level": "unite",
                    "base_units": 2,
                    "unit_price": 1000,
                }],
                "payment_method": "cash",
                "cash_session_uuid": open_cash_session["session_uuid"],
                "customer_id": customer.id,
            },
        )

        db.refresh(customer)
        assert response.status_code == 201, response.text
        assert response.json()["bonus_earned"] == expected_bonus
        assert customer.total_points == expected_bonus

    @pytest.mark.parametrize(
        ("option", "expected_feature"),
        [
            ("insurance", "insurance_sales"),
            ("customer", "customer_management"),
        ],
    )
    def test_basic_checkout_rejects_pro_only_options(
        self, client, db, admin_user, admin_headers, pharmacy, open_cash_session, option, expected_feature
    ):
        pharmacy.plan = "basic"
        db.commit()
        payload = {
            "items": [{
                "medicine_id": 1,
                "allocations": [{"batch_id": 1, "quantity": 1}],
                "quantity": 1,
                "unit_price": 100,
            }],
            "payment_method": "insurance" if option == "insurance" else "cash",
            "cash_session_uuid": open_cash_session["session_uuid"] if option != "insurance" else None,
            "customer_id": 1 if option == "customer" else None,
        }

        response = client.post(
            "/pos/checkout",
            headers=admin_headers,
            json=payload,
        )

        assert response.status_code == 403
        assert response.json()["detail"]["error"] == "PLAN_UPGRADE_REQUIRED"
        assert response.json()["detail"]["current_plan"] == "basic"

    def test_basic_legacy_sale_cannot_use_insurance(
        self, client, db, admin_user, admin_headers, pharmacy
    ):
        pharmacy.plan = "basic"
        db.commit()

        response = client.post(
            "/sales/create",
            headers=admin_headers,
            json={
                "items": [{"medicine_id": 1, "quantity": 1}],
                "payment_method": "insurance_card",
            },
        )

        assert response.status_code == 403
        assert response.json()["detail"]["error"] == "PLAN_UPGRADE_REQUIRED"

    def test_basic_legacy_sale_cannot_apply_discount(
        self, client, db, admin_user, admin_headers, pharmacy
    ):
        pharmacy.plan = "basic"
        db.commit()

        response = client.post(
            "/sales/create",
            headers=admin_headers,
            json={
                "items": [{"medicine_id": 1, "quantity": 1}],
                "discount_percent": 10,
            },
        )

        assert response.status_code == 403
        assert response.json()["detail"]["error"] == "PLAN_UPGRADE_REQUIRED"

    def test_basic_pos_history_is_limited_to_thirty_days(
        self, client, db, admin_user, admin_headers, pharmacy
    ):
        pharmacy.plan = "basic"
        db.commit()

        response = client.get(
            "/pos/history?start_date=2000-01-01",
            headers=admin_headers,
        )

        assert response.status_code == 403
        assert response.json()["detail"]["required_plan"] == "pro"

    def test_basic_sales_history_is_limited_to_thirty_days(
        self, client, db, admin_user, admin_headers, pharmacy
    ):
        pharmacy.plan = "basic"
        db.commit()

        response = client.get(
            "/sales/history?start_date=2000-01-01",
            headers=admin_headers,
        )

        assert response.status_code == 403
        assert response.json()["detail"]["required_plan"] == "pro"

    def test_basic_history_cannot_select_an_old_end_date(
        self, client, db, admin_user, admin_headers, pharmacy
    ):
        pharmacy.plan = "basic"
        db.commit()

        response = client.get(
            "/pos/history?end_date=2000-01-01",
            headers=admin_headers,
        )

        assert response.status_code == 403
        assert response.json()["detail"]["required_plan"] == "pro"

    def test_basic_cannot_read_old_sale_details_or_invoice(
        self, client, db, admin_user, admin_headers, pharmacy
    ):
        from datetime import datetime, timedelta

        from app.models.pos_sale import POSSale
        from app.models.sales import Sale

        pharmacy.plan = "basic"
        old_date = datetime.now() - timedelta(days=40)
        pos_sale = POSSale(
            code="OLD-POS-SALE",
            total_amount=100,
            date=old_date,
            user_id=admin_user.id,
            pharmacy_id=pharmacy.id,
        )
        legacy_sale = Sale(
            code="OLD-LEGACY-SALE",
            total_amount=100,
            date=old_date,
            user_id=admin_user.id,
            pharmacy_id=pharmacy.id,
        )
        db.add_all([pos_sale, legacy_sale])
        db.commit()
        db.refresh(pos_sale)
        db.refresh(legacy_sale)

        for path in (
            f"/pos/sale/{pos_sale.id}",
            f"/sales/{legacy_sale.id}",
            f"/sales/{legacy_sale.id}/invoice",
        ):
            response = client.get(path, headers=admin_headers)
            assert response.status_code == 403, (path, response.text)

"""
Tests complets pour les nouveaux chantiers PharmaGest Online :
1. Admin Plateforme Étendu (CRUD Admins Plateforme)
2. Gestion des Licences Plateforme (Génération de Clés, Révocation)
3. Activation / Renouvellement de Licence Client (Redeem & History)
4. Module d'Analyse (Finance, Stock, Vendeurs, Produits)
5. Permissions Granulaires Utilisateurs (PUT /users/{id}/permissions)
"""

from datetime import datetime, timedelta, date
import pytest
from app.models.pharmacy import Pharmacy
from app.models.user import User, UserRole
from app.models.license_key import LicenseKey
from app.models.pos_sale import POSSale, POSSaleItem
from app.models.medicine import Medicine
from app.utils.security import create_access_token, hash_password


def _auth_headers(user: User) -> dict:
    token = create_access_token(
        data={"sub": user.username},
        expires_delta=timedelta(minutes=60),
    )
    return {"Authorization": f"Bearer {token}"}


@pytest.fixture
def platform_admin_user(db):
    user = User(
        username="super_plat_admin_test",
        password_hash=hash_password("Pass123!"),
        role=UserRole.PLATFORM_ADMIN,
        is_active=True,
        pharmacy_id=None,
        is_super_platform_admin=True,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


@pytest.fixture
def sample_pharmacy(db):
    pharm = Pharmacy(
        name="Pharmacie Test Centrale",
        code="PHARM-CENTRAL-TEST",
        plan="basic",
        max_users=3,
        license_expires_at=date.today() + timedelta(days=10),
        is_active=True,
    )
    db.add(pharm)
    db.commit()
    db.refresh(pharm)
    return pharm


@pytest.fixture
def pharmacy_admin_user(db, sample_pharmacy):
    user = User(
        username="pharm_admin_test",
        password_hash=hash_password("Pass123!"),
        role=UserRole.ADMIN,
        is_active=True,
        pharmacy_id=sample_pharmacy.id,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


@pytest.fixture
def pharmacy_cashier_user(db, sample_pharmacy):
    user = User(
        username="cashier_test",
        password_hash=hash_password("Pass123!"),
        role=UserRole.PHARMACIST,
        is_active=True,
        pharmacy_id=sample_pharmacy.id,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


# ============================================================================
# 1. TESTS CRUD ADMINS PLATEFORME
# ============================================================================

def test_platform_admins_crud(client, db, platform_admin_user):
    headers = _auth_headers(platform_admin_user)

    # 1. Lister les admins
    res = client.get("/platform/admins", headers=headers)
    assert res.status_code == 200
    admins = res.json()
    assert any(a["username"] == platform_admin_user.username for a in admins)

    # 2. Créer un nouvel admin
    new_admin_payload = {
        "username": "sub_admin_ops",
        "password": "PasswordOps123!",
        "first_name": "Jean",
        "last_name": "Support",
        "email": "jean.support@pharmagest.bi",
    }
    create_res = client.post("/platform/admins", headers=headers, json=new_admin_payload)
    assert create_res.status_code == 201
    created_id = create_res.json()["id"]

    # 3. Modifier l'admin
    update_res = client.put(
        f"/platform/admins/{created_id}",
        headers=headers,
        json={"first_name": "Jean-Pierre", "phone": "+25779000000"},
    )
    assert update_res.status_code == 200
    assert update_res.json()["first_name"] == "Jean-Pierre"

    # 4. Soft-delete (désactiver) l'admin
    del_res = client.delete(f"/platform/admins/{created_id}", headers=headers)
    assert del_res.status_code == 200

    # 5. Tentative de suppression du super platform admin -> 400 ou 403
    self_del = client.delete(f"/platform/admins/{platform_admin_user.id}", headers=headers)
    assert self_del.status_code in [400, 403]


# ============================================================================
# 2. TESTS GESTION DES CLÉS DE LICENCE PLATEFORME
# ============================================================================

def test_license_keys_generation_and_revocation(client, db, platform_admin_user):
    headers = _auth_headers(platform_admin_user)

    # Générer 2 clés de licence Pro
    gen_payload = {
        "plan": "pro",
        "duration_days": 180,
        "max_users": 5,
        "quantity": 2,
        "notes": "Pack 6 mois client partenaire",
    }
    gen_res = client.post("/license/platform/generate", headers=headers, json=gen_payload)
    assert gen_res.status_code == 200
    keys = gen_res.json()
    assert len(keys) == 2
    assert keys[0]["plan"] == "pro"
    assert keys[0]["duration_days"] == 180

    key_id = keys[0]["id"]

    # Lister les clés
    list_res = client.get("/license/platform/keys?plan=pro", headers=headers)
    assert list_res.status_code == 200
    assert any(k["id"] == key_id for k in list_res.json())

    # Révoquer la première clé
    revoke_res = client.put(f"/license/platform/keys/{key_id}/revoke", headers=headers)
    assert revoke_res.status_code == 200


# ============================================================================
# 3. TESTS ACTIVATION LICENCE CLIENT (REDEEM & HISTORY)
# ============================================================================

def test_license_redemption_by_pharmacy(client, db, platform_admin_user, pharmacy_admin_user, sample_pharmacy):
    plat_headers = _auth_headers(platform_admin_user)
    pharm_headers = _auth_headers(pharmacy_admin_user)

    # 1. Plateforme génère une clé Enterprise 365 jours
    gen_res = client.post(
        "/license/platform/generate",
        headers=plat_headers,
        json={"plan": "enterprise", "duration_days": 365, "max_users": 10, "quantity": 1},
    )
    generated_key = gen_res.json()[0]["key"]

    # 2. Pharmacie active la clé
    old_expiry = sample_pharmacy.license_expires_at
    redeem_res = client.post("/license/redeem", headers=pharm_headers, json={"key": generated_key})
    assert redeem_res.status_code == 200
    assert redeem_res.json()["success"] is True
    assert redeem_res.json()["plan"] == "enterprise"

    # Vérifier que la date d'expiration a bien été repoussée
    db.refresh(sample_pharmacy)
    assert sample_pharmacy.plan == "enterprise"
    assert sample_pharmacy.license_expires_at > old_expiry

    # 3. Tentative de réutiliser la même clé -> Rejet 400
    reuse_res = client.post("/license/redeem", headers=pharm_headers, json={"key": generated_key})
    assert reuse_res.status_code == 400

    # 4. Consulter l'historique de la pharmacie
    hist_res = client.get("/license/history", headers=pharm_headers)
    assert hist_res.status_code == 200
    hist = hist_res.json()
    assert len(hist) >= 1
    assert hist[0]["key"] == generated_key


# ============================================================================
# 4. TESTS MODULE D'ANALYSE
# ============================================================================

def test_analyse_endpoints(client, db, pharmacy_admin_user, sample_pharmacy):
    headers = _auth_headers(pharmacy_admin_user)

    # Insérer quelques données de test
    med = Medicine(
        name="Paracétamol 500mg Test",
        code="PARA-TEST-01",
        pharmacy_id=sample_pharmacy.id,
        quantity=100,
        price_buy=500.0,
        price_sell=800.0,
    )
    db.add(med)
    db.commit()

    sale = POSSale(
        pharmacy_id=sample_pharmacy.id,
        user_id=pharmacy_admin_user.id,
        code="POS-2026-TEST01",
        total_amount=1600.0,
        status="completed",
        created_at=datetime.utcnow(),
    )
    db.add(sale)
    db.commit()

    item = POSSaleItem(
        sale_id=sale.id,
        medicine_id=med.id,
        quantity=2,
        unit_price=800.0,
        total_price=1600.0,
    )
    db.add(item)
    db.commit()

    # Test GET /analyse/finance
    res_fin = client.get("/analyse/finance", headers=headers)
    assert res_fin.status_code == 200
    assert "total_revenue_12m" in res_fin.json()

    # Test GET /analyse/stock
    res_stock = client.get("/analyse/stock", headers=headers)
    assert res_stock.status_code == 200
    assert "total_stock_value_purchase" in res_stock.json()

    # Test GET /analyse/vendors
    res_vend = client.get("/analyse/vendors", headers=headers)
    assert res_vend.status_code == 200
    assert isinstance(res_vend.json(), list)

    # Test GET /analyse/products
    res_prod = client.get("/analyse/products", headers=headers)
    assert res_prod.status_code == 200
    assert "top_by_volume" in res_prod.json()


# ============================================================================
# 5. TESTS PERMISSIONS GRANULAIRES UTILISATEURS
# ============================================================================

def test_user_granular_permissions(client, db, pharmacy_admin_user, pharmacy_cashier_user):
    admin_headers = _auth_headers(pharmacy_admin_user)

    payload = {
        "allowed_features": ["pos", "stock"]
    }
    res = client.put(
        f"/users/{pharmacy_cashier_user.id}/permissions",
        headers=admin_headers,
        json=payload,
    )
    assert res.status_code == 200
    assert res.json()["allowed_features"] == ["pos", "stock"]

    # Vérifier persistance
    db.refresh(pharmacy_cashier_user)
    assert pharmacy_cashier_user.allowed_features == ["pos", "stock"]

    # Tentative pour un admin de modifier ses propres permissions -> 400
    self_res = client.put(
        f"/users/{pharmacy_admin_user.id}/permissions",
        headers=admin_headers,
        json=payload,
    )
    assert self_res.status_code == 400


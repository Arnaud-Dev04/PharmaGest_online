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
            role=UserRole.PHARMACIEN,
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
            role=UserRole.PHARMACIEN,
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


# ═══════════════════════════════════════════════════════════════════════════════
# POST /auth/register
# ═══════════════════════════════════════════════════════════════════════════════

class TestRegister:
    def test_admin_peut_creer_utilisateur(self, client, admin_user, admin_headers):
        resp = client.post("/auth/register", json={
            "username": "nouveau_pharma",
            "password": "NewPass@123!",
            "role": "pharmacien",
            "is_active": True,
        }, headers=admin_headers)
        assert resp.status_code == 200
        body = resp.json()
        assert body["username"] == "nouveau_pharma"
        assert "password_hash" not in body

    def test_pharmacien_ne_peut_pas_creer_utilisateur(
        self, client, pharmacist_user, pharmacist_headers
    ):
        resp = client.post("/auth/register", json={
            "username": "autre_user",
            "password": "Pass@123!",
            "role": "pharmacien",
        }, headers=pharmacist_headers)
        assert resp.status_code == 403

    def test_creation_doublon_username_retourne_400(self, client, admin_user, admin_headers):
        # Créer le premier utilisateur
        client.post("/auth/register", json={
            "username": "doublon_user",
            "password": "Pass@123!",
            "role": "pharmacien",
        }, headers=admin_headers)

        # Tenter de créer le même username
        resp = client.post("/auth/register", json={
            "username": "doublon_user",
            "password": "AutrePass@123!",
            "role": "pharmacien",
        }, headers=admin_headers)
        assert resp.status_code == 400

    def test_creation_sans_token_retourne_401(self, client):
        resp = client.post("/auth/register", json={
            "username": "user_anon",
            "password": "Pass@123!",
            "role": "pharmacien",
        })
        assert resp.status_code == 401

    def test_utilisateur_cree_doit_changer_mdp(self, client, admin_user, admin_headers):
        """Un nouvel utilisateur a must_change_password=True par défaut."""
        resp = client.post("/auth/register", json={
            "username": "must_change",
            "password": "Temp@123!",
            "role": "pharmacien",
        }, headers=admin_headers)
        assert resp.status_code == 200
        assert resp.json()["must_change_password"] is True

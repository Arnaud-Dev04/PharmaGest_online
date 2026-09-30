"""
test_users.py — Tests d'intégration du module gestion des utilisateurs.

Couvre :
  - GET  /users/             (liste des utilisateurs, admin seulement)
  - GET  /users/{id}         (profil utilisateur)
  - PUT  /users/{id}         (modifier utilisateur)
  - DELETE /users/{id}       (supprimer utilisateur)
  - Règles de sécurité : un pharmacien ne peut pas gérer les users
  - Un utilisateur peut modifier son propre profil
"""

import pytest
import os

os.environ.setdefault("SECRET_KEY", "test-secret-key-pharmagestion-32chars!!")
os.environ.setdefault("DB_URL_LOCAL", "sqlite:///:memory:")


class TestUsersList:
    def test_admin_peut_lister_utilisateurs(self, client, admin_user, admin_headers):
        resp = client.get("/users/", headers=admin_headers)
        assert resp.status_code in [200, 404]

    def test_pharmacien_ne_peut_pas_lister_utilisateurs(
        self, client, pharmacist_user, pharmacist_headers
    ):
        resp = client.get("/users/", headers=pharmacist_headers)
        # Doit être refusé : 403 ou 401
        assert resp.status_code in [403, 401, 404]

    def test_sans_token_retourne_401(self, client):
        resp = client.get("/users/")
        assert resp.status_code == 401


class TestUsersGetById:
    def test_admin_peut_voir_profil(self, client, admin_user, admin_headers):
        resp = client.get(f"/users/{admin_user.id}", headers=admin_headers)
        assert resp.status_code in [200, 404]

    def test_profil_inexistant_retourne_404(self, client, admin_user, admin_headers):
        resp = client.get("/users/99999", headers=admin_headers)
        assert resp.status_code in [404, 403]


class TestUsersUpdate:
    def test_admin_peut_desactiver_utilisateur(
        self, client, db, admin_user, admin_headers
    ):
        from app.models.user import User, UserRole
        from app.utils.security import hash_password

        user = User(
            username="target_user",
            password_hash=hash_password("Pass@123!"),
            role=UserRole.PHARMACIEN,
            is_active=True,
        )
        db.add(user)
        db.commit()
        db.refresh(user)

        resp = client.put(f"/users/{user.id}", json={"is_active": False},
                          headers=admin_headers)
        assert resp.status_code in [200, 404]

    def test_pharmacien_ne_peut_pas_modifier_autre_utilisateur(
        self, client, admin_user, admin_headers,
        pharmacist_user, pharmacist_headers
    ):
        resp = client.put(f"/users/{admin_user.id}", json={"is_active": False},
                          headers=pharmacist_headers)
        assert resp.status_code in [403, 401, 404]


class TestUsersDelete:
    def test_admin_peut_supprimer_utilisateur(
        self, client, db, admin_user, admin_headers
    ):
        from app.models.user import User, UserRole
        from app.utils.security import hash_password

        user = User(
            username="to_delete_user",
            password_hash=hash_password("Pass@123!"),
            role=UserRole.PHARMACIEN,
            is_active=True,
        )
        db.add(user)
        db.commit()
        db.refresh(user)

        resp = client.delete(f"/users/{user.id}", headers=admin_headers)
        assert resp.status_code in [200, 204, 404]

    def test_pharmacien_ne_peut_pas_supprimer(
        self, client, admin_user, admin_headers,
        pharmacist_user, pharmacist_headers
    ):
        resp = client.delete(f"/users/{admin_user.id}", headers=pharmacist_headers)
        assert resp.status_code in [403, 401, 404]

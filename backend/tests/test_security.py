"""
test_security.py — Tests unitaires des fonctions de sécurité.

Couvre :
  - Hachage bcrypt des mots de passe
  - Vérification des mots de passe
  - Génération de tokens JWT
  - Vérification et décodage des tokens
  - Gestion des tokens expirés
  - Gestion des entrées invalides
"""

import pytest
import os

os.environ.setdefault("SECRET_KEY", "test-secret-key-pharmagestion-32chars!!")

from datetime import timedelta
from app.utils.security import (
    hash_password,
    verify_password,
    create_access_token,
    verify_token,
    decode_token,
)


# ═══════════════════════════════════════════════════════════════════════════════
# HACHAGE DES MOTS DE PASSE
# ═══════════════════════════════════════════════════════════════════════════════

class TestPasswordHashing:
    def test_hash_retourne_chaine_non_vide(self):
        hashed = hash_password("monMotDePasse")
        assert isinstance(hashed, str)
        assert len(hashed) > 0

    def test_hash_different_du_original(self):
        password = "secret123"
        hashed = hash_password(password)
        assert hashed != password

    def test_deux_hash_du_meme_mot_de_passe_sont_differents(self):
        """bcrypt utilise un salt aléatoire → deux hash ne sont jamais identiques."""
        hashed1 = hash_password("meme_mot_de_passe")
        hashed2 = hash_password("meme_mot_de_passe")
        assert hashed1 != hashed2

    def test_hash_commence_par_bcrypt_prefix(self):
        hashed = hash_password("test")
        assert hashed.startswith("$2b$")

    def test_hash_mot_de_passe_special_chars(self):
        hashed = hash_password("P@$$w0rd!#%^&*()")
        assert hashed is not None

    def test_hash_mot_de_passe_unicode(self):
        hashed = hash_password("mötdépàssé")
        assert hashed is not None

    def test_hash_mot_de_passe_long(self):
        long_password = "a" * 72  # bcrypt limite à 72 bytes
        hashed = hash_password(long_password)
        assert hashed is not None


# ═══════════════════════════════════════════════════════════════════════════════
# VÉRIFICATION DES MOTS DE PASSE
# ═══════════════════════════════════════════════════════════════════════════════

class TestPasswordVerification:
    def test_mot_de_passe_correct_retourne_true(self):
        password = "Admin@123!"
        hashed = hash_password(password)
        assert verify_password(password, hashed) is True

    def test_mot_de_passe_incorrect_retourne_false(self):
        hashed = hash_password("correct_password")
        assert verify_password("wrong_password", hashed) is False

    def test_mot_de_passe_vide_retourne_false(self):
        hashed = hash_password("nonvide")
        assert verify_password("", hashed) is False

    def test_hash_invalide_retourne_false(self):
        """Pas d'exception levée sur hash invalide."""
        result = verify_password("password", "not_a_valid_hash")
        assert result is False

    def test_majuscules_differentes_retourne_false(self):
        hashed = hash_password("Password123")
        assert verify_password("password123", hashed) is False

    def test_espace_supplementaire_retourne_false(self):
        hashed = hash_password("password")
        assert verify_password("password ", hashed) is False

    def test_verification_roundtrip_avec_caracteres_speciaux(self):
        password = "P@$$w0rd!™€"
        hashed = hash_password(password)
        assert verify_password(password, hashed) is True


# ═══════════════════════════════════════════════════════════════════════════════
# CRÉATION DE TOKENS JWT
# ═══════════════════════════════════════════════════════════════════════════════

class TestJWTCreation:
    def test_token_retourne_chaine_non_vide(self):
        token = create_access_token(data={"sub": "arnaud"})
        assert isinstance(token, str)
        assert len(token) > 20

    def test_token_contient_trois_segments_jwt(self):
        """Un JWT valide = header.payload.signature (3 parties séparées par '.')"""
        token = create_access_token(data={"sub": "arnaud"})
        parts = token.split(".")
        assert len(parts) == 3

    def test_token_avec_expires_delta(self):
        token = create_access_token(
            data={"sub": "arnaud"},
            expires_delta=timedelta(hours=1),
        )
        payload = verify_token(token)
        assert payload is not None
        assert "exp" in payload

    def test_token_contient_subject(self):
        token = create_access_token(data={"sub": "test_user"})
        payload = verify_token(token)
        assert payload["sub"] == "test_user"

    def test_token_contient_expiration(self):
        token = create_access_token(data={"sub": "arnaud"})
        payload = verify_token(token)
        assert "exp" in payload

    def test_token_avec_donnees_supplementaires(self):
        token = create_access_token(data={"sub": "arnaud", "role": "admin"})
        payload = verify_token(token)
        assert payload["role"] == "admin"


# ═══════════════════════════════════════════════════════════════════════════════
# VÉRIFICATION ET DÉCODAGE DES TOKENS
# ═══════════════════════════════════════════════════════════════════════════════

class TestJWTVerification:
    def test_token_valide_retourne_payload(self):
        token = create_access_token(data={"sub": "arnaud"})
        payload = verify_token(token)
        assert payload is not None
        assert isinstance(payload, dict)

    def test_token_invalide_retourne_none(self):
        result = verify_token("token.invalide.xx")
        assert result is None

    def test_token_vide_retourne_none(self):
        result = verify_token("")
        assert result is None

    def test_token_expire_retourne_none(self):
        token = create_access_token(
            data={"sub": "arnaud"},
            expires_delta=timedelta(seconds=-1),  # Déjà expiré
        )
        result = verify_token(token)
        assert result is None

    def test_decode_token_retourne_username(self):
        token = create_access_token(data={"sub": "arnaud"})
        username = decode_token(token)
        assert username == "arnaud"

    def test_decode_token_invalide_retourne_none(self):
        result = decode_token("mauvais_token")
        assert result is None

    def test_token_falsifie_retourne_none(self):
        """Un token avec signature modifiée doit être rejeté."""
        token = create_access_token(data={"sub": "arnaud"})
        # Modifier le payload (partie du milieu)
        parts = token.split(".")
        falsified = parts[0] + ".FALSIFIED_PAYLOAD" + "." + parts[2]
        result = verify_token(falsified)
        assert result is None

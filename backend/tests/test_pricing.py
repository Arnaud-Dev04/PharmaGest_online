"""
test_pricing.py — Tests d'intégration des endpoints de tarification médicament.

Couvre :
  - Calcul des prix (pct_marge, carton_fixe, manuel)
  - CRUD /pricing/entries (créer, lister, récupérer, modifier, supprimer)
  - Validation Pydantic (422 sur champs invalides)
  - Détection des doublons (même nom + même lot)
  - Alertes (stock faible, expiration proche)
  - Autocomplétion
  - Contrôle d'accès (admin requis pour écriture)
"""

import pytest
import os
from datetime import date, timedelta

os.environ.setdefault("SECRET_KEY", "test-secret-key-pharmagestion-32chars!!")
os.environ.setdefault("DB_URL_LOCAL", "sqlite:///:memory:")

from app.services.medicine_pricing_service import calculate_prices
from app.schemas.medicine_pricing import MedicinePricingCreate, PricingMode, OrdonnanceType


# ═══════════════════════════════════════════════════════════════════════════════
# TESTS UNITAIRES — CALCUL DES PRIX
# ═══════════════════════════════════════════════════════════════════════════════

class TestCalculatePrices:
    """Tests unitaires de la logique de calcul sans base de données."""

    def _make_data(self, **overrides) -> MedicinePricingCreate:
        future = date.today() + timedelta(days=365)
        defaults = dict(
            nom="Amoxicilline 500mg",
            lot="LOT-001",
            nb_cartons=5,
            boites_par_carton=10,
            plaquettes_par_boite=3,
            comprimes_par_plaquette=8,
            prix_mode=PricingMode.PCT_MARGE,
            achat_carton=120000.0,
            marge_pct=25.0,
            ordonnance=OrdonnanceType.NON,
            date_peremption=future,
        )
        defaults.update(overrides)
        return MedicinePricingCreate(**defaults)

    def test_mode_pct_marge_calcule_vente_carton(self):
        data = self._make_data(achat_carton=100000.0, marge_pct=20.0)
        result = calculate_prices(data)
        assert result["vente_carton"] == pytest.approx(120000.0, rel=1e-3)

    def test_mode_pct_marge_calcule_vente_boite(self):
        data = self._make_data(achat_carton=100000.0, marge_pct=20.0, boites_par_carton=10)
        result = calculate_prices(data)
        assert result["vente_boite"] == pytest.approx(12000.0, rel=1e-3)

    def test_mode_pct_marge_calcule_vente_comprime(self):
        data = self._make_data(
            achat_carton=100000.0, marge_pct=20.0,
            boites_par_carton=10, plaquettes_par_boite=3, comprimes_par_plaquette=8
        )
        result = calculate_prices(data)
        # vente_carton=120000 / 10 / 3 / 8
        assert result["vente_comprime"] == pytest.approx(500.0, rel=1e-3)

    def test_mode_pct_marge_calcule_totaux(self):
        data = self._make_data(
            nb_cartons=5, boites_par_carton=10,
            plaquettes_par_boite=3, comprimes_par_plaquette=8
        )
        result = calculate_prices(data)
        assert result["total_boites"] == 50
        assert result["total_plaquettes"] == 150
        assert result["total_comprimes"] == 1200

    def test_mode_pct_marge_calcule_benefice(self):
        data = self._make_data(
            nb_cartons=10, achat_carton=100000.0, marge_pct=25.0,
            boites_par_carton=10, plaquettes_par_boite=3, comprimes_par_plaquette=8
        )
        result = calculate_prices(data)
        # Bénéfice = total_comprimes * vente_comprime - nb_cartons * achat_carton
        assert result["benefice_estime"] > 0

    def test_mode_carton_fixe_calcule_vente_boite(self):
        data = self._make_data(
            prix_mode=PricingMode.CARTON_FIXE,
            achat_carton=80000.0,
            vente_carton=100000.0,
            marge_pct=None,
            boites_par_carton=10,
        )
        result = calculate_prices(data)
        assert result["vente_boite"] == pytest.approx(10000.0, rel=1e-3)

    def test_mode_carton_fixe_calcule_marge_pct(self):
        data = self._make_data(
            prix_mode=PricingMode.CARTON_FIXE,
            achat_carton=80000.0,
            vente_carton=100000.0,
            marge_pct=None,
        )
        result = calculate_prices(data)
        # marge = (100000 - 80000) / 80000 * 100 = 25%
        assert result["marge_pct"] == pytest.approx(25.0, rel=1e-3)

    def test_calcule_achat_boite(self):
        data = self._make_data(achat_carton=100000.0, boites_par_carton=10)
        result = calculate_prices(data)
        assert result["achat_boite"] == pytest.approx(10000.0, rel=1e-3)

    def test_division_par_zero_retourne_zero(self):
        """Conditionnement à 0 ne doit pas lever d'exception."""
        data = self._make_data(
            prix_mode=PricingMode.CARTON_FIXE,
            achat_carton=100000.0,
            vente_carton=120000.0,
            marge_pct=None,
            boites_par_carton=0,  # Division par 0
            plaquettes_par_boite=0,
            comprimes_par_plaquette=0,
        )
        # Le modèle Pydantic valide > 0, donc ce test vérifie que le service
        # gère le cas sans planter
        # (ce payload ne passera pas la validation Pydantic normalement)
        # On contourne en appelant directement la fonction avec un objet modifié
        import types
        mock = types.SimpleNamespace(
            prix_mode=types.SimpleNamespace(value="carton_fixe"),
            achat_carton=100000.0, marge_pct=None,
            vente_carton=120000.0, vente_boite=0.0, vente_plaquette=0.0, vente_comprime=0.0,
            nb_cartons=1, boites_par_carton=0, plaquettes_par_boite=0, comprimes_par_plaquette=0,
            achat_boite=0.0, achat_plaquette=0.0, achat_comprime=0.0,
        )
        from app.services.medicine_pricing_service import calculate_prices as _calc
        result = _calc(mock)
        assert result["vente_boite"] == 0.0


# ═══════════════════════════════════════════════════════════════════════════════
# TESTS D'INTÉGRATION — CRUD API
# ═══════════════════════════════════════════════════════════════════════════════

class TestPricingCRUD:
    def test_creer_pricing_pct_marge_retourne_201(
        self, client, admin_user, admin_headers, pricing_payload_pct_marge
    ):
        resp = client.post("/pricing/entries", json=pricing_payload_pct_marge,
                           headers=admin_headers)
        assert resp.status_code == 201
        body = resp.json()
        assert body["nom"] == "Amoxicilline 500mg"
        assert body["id"] is not None
        assert body["total_comprimes"] == 5 * 10 * 3 * 8  # 1200

    def test_creer_pricing_carton_fixe_retourne_201(
        self, client, admin_user, admin_headers, pricing_payload_carton_fixe
    ):
        resp = client.post("/pricing/entries", json=pricing_payload_carton_fixe,
                           headers=admin_headers)
        assert resp.status_code == 201
        body = resp.json()
        assert body["vente_carton"] == pytest.approx(100000.0, rel=1e-2)

    def test_creer_pricing_calcule_vente_automatiquement(
        self, client, admin_user, admin_headers, pricing_payload_pct_marge
    ):
        """Pour le mode pct_marge, la vente est calculée depuis l'achat × marge."""
        resp = client.post("/pricing/entries", json=pricing_payload_pct_marge,
                           headers=admin_headers)
        body = resp.json()
        expected_vente = 120000.0 * 1.25
        assert body["vente_carton"] == pytest.approx(expected_vente, rel=1e-2)

    def test_lister_pricing_retourne_liste_vide_si_aucun(
        self, client, admin_user, admin_headers
    ):
        resp = client.get("/pricing/entries", headers=admin_headers)
        assert resp.status_code == 200
        body = resp.json()
        assert "items" in body
        assert isinstance(body["items"], list)

    def test_lister_pricing_retourne_entree_creee(
        self, client, admin_user, admin_headers, pricing_payload_pct_marge
    ):
        client.post("/pricing/entries", json=pricing_payload_pct_marge, headers=admin_headers)
        resp = client.get("/pricing/entries", headers=admin_headers)
        body = resp.json()
        assert body["total"] >= 1
        assert any(e["nom"] == "Amoxicilline 500mg" for e in body["items"])

    def test_lister_avec_recherche(
        self, client, admin_user, admin_headers,
        pricing_payload_pct_marge, pricing_payload_carton_fixe
    ):
        client.post("/pricing/entries", json=pricing_payload_pct_marge, headers=admin_headers)
        client.post("/pricing/entries", json=pricing_payload_carton_fixe, headers=admin_headers)

        resp = client.get("/pricing/entries?search=amoxicilline", headers=admin_headers)
        body = resp.json()
        assert all("amoxicilline" in e["nom"].lower() for e in body["items"])

    def test_lister_avec_pagination(
        self, client, admin_user, admin_headers, pricing_payload_pct_marge
    ):
        resp = client.get("/pricing/entries?page=1&page_size=5", headers=admin_headers)
        assert resp.status_code == 200
        body = resp.json()
        assert "page" in body
        assert "page_size" in body
        assert len(body["items"]) <= 5

    def test_recuperer_pricing_par_id(
        self, client, admin_user, admin_headers, pricing_payload_pct_marge
    ):
        created = client.post("/pricing/entries", json=pricing_payload_pct_marge,
                              headers=admin_headers).json()
        entry_id = created["id"]

        resp = client.get(f"/pricing/entries/{entry_id}", headers=admin_headers)
        assert resp.status_code == 200
        assert resp.json()["id"] == entry_id

    def test_recuperer_pricing_inexistant_retourne_404(
        self, client, admin_user, admin_headers
    ):
        resp = client.get("/pricing/entries/99999", headers=admin_headers)
        assert resp.status_code == 404

    def test_modifier_pricing_retourne_200(
        self, client, admin_user, admin_headers, pricing_payload_pct_marge
    ):
        created = client.post("/pricing/entries", json=pricing_payload_pct_marge,
                              headers=admin_headers).json()
        entry_id = created["id"]

        resp = client.put(f"/pricing/entries/{entry_id}", json={
            "fournisseur": "NouveauFournisseur",
        }, headers=admin_headers)
        assert resp.status_code == 200
        assert resp.json()["fournisseur"] == "NouveauFournisseur"

    def test_modifier_pricing_inexistant_retourne_404(
        self, client, admin_user, admin_headers
    ):
        resp = client.put("/pricing/entries/99999", json={"fournisseur": "X"},
                          headers=admin_headers)
        assert resp.status_code == 404

    def test_supprimer_pricing_retourne_204(
        self, client, admin_user, admin_headers, pricing_payload_pct_marge
    ):
        created = client.post("/pricing/entries", json=pricing_payload_pct_marge,
                              headers=admin_headers).json()
        entry_id = created["id"]

        resp = client.delete(f"/pricing/entries/{entry_id}", headers=admin_headers)
        assert resp.status_code == 204

        # Vérifier que l'entrée n'existe plus
        resp2 = client.get(f"/pricing/entries/{entry_id}", headers=admin_headers)
        assert resp2.status_code == 404

    def test_supprimer_pricing_inexistant_retourne_404(
        self, client, admin_user, admin_headers
    ):
        resp = client.delete("/pricing/entries/99999", headers=admin_headers)
        assert resp.status_code == 404


# ═══════════════════════════════════════════════════════════════════════════════
# VALIDATION PYDANTIC — CHAMPS INVALIDES (422)
# ═══════════════════════════════════════════════════════════════════════════════

class TestPricingValidation:
    def test_nom_manquant_retourne_422(self, client, admin_user, admin_headers,
                                       pricing_payload_pct_marge):
        payload = pricing_payload_pct_marge.copy()
        del payload["nom"]
        resp = client.post("/pricing/entries", json=payload, headers=admin_headers)
        assert resp.status_code == 422

    def test_achat_carton_zero_retourne_422(self, client, admin_user, admin_headers,
                                             pricing_payload_pct_marge):
        payload = pricing_payload_pct_marge.copy()
        payload["achat_carton"] = 0
        resp = client.post("/pricing/entries", json=payload, headers=admin_headers)
        assert resp.status_code == 422

    def test_achat_carton_negatif_retourne_422(self, client, admin_user, admin_headers,
                                                pricing_payload_pct_marge):
        payload = pricing_payload_pct_marge.copy()
        payload["achat_carton"] = -100
        resp = client.post("/pricing/entries", json=payload, headers=admin_headers)
        assert resp.status_code == 422

    def test_marge_nulle_en_mode_pct_marge_retourne_422(
        self, client, admin_user, admin_headers, pricing_payload_pct_marge
    ):
        payload = pricing_payload_pct_marge.copy()
        payload["marge_pct"] = 0
        resp = client.post("/pricing/entries", json=payload, headers=admin_headers)
        assert resp.status_code == 422

    def test_date_peremption_passee_retourne_422(
        self, client, admin_user, admin_headers, pricing_payload_pct_marge
    ):
        payload = pricing_payload_pct_marge.copy()
        payload["date_peremption"] = "2020-01-01"
        resp = client.post("/pricing/entries", json=payload, headers=admin_headers)
        assert resp.status_code == 422

    def test_nb_cartons_zero_retourne_422(self, client, admin_user, admin_headers,
                                           pricing_payload_pct_marge):
        payload = pricing_payload_pct_marge.copy()
        payload["nb_cartons"] = 0
        resp = client.post("/pricing/entries", json=payload, headers=admin_headers)
        assert resp.status_code == 422

    def test_lot_manquant_retourne_422(self, client, admin_user, admin_headers,
                                        pricing_payload_pct_marge):
        payload = pricing_payload_pct_marge.copy()
        del payload["lot"]
        resp = client.post("/pricing/entries", json=payload, headers=admin_headers)
        assert resp.status_code == 422

    def test_mode_prix_invalide_retourne_422(self, client, admin_user, admin_headers,
                                              pricing_payload_pct_marge):
        payload = pricing_payload_pct_marge.copy()
        payload["prix_mode"] = "mode_inexistant"
        resp = client.post("/pricing/entries", json=payload, headers=admin_headers)
        assert resp.status_code == 422


# ═══════════════════════════════════════════════════════════════════════════════
# CONTRÔLE D'ACCÈS
# ═══════════════════════════════════════════════════════════════════════════════

class TestPricingAccessControl:
    def test_lecture_sans_token_retourne_401(self, client):
        resp = client.get("/pricing/entries")
        assert resp.status_code == 401

    def test_pharmacien_peut_lire(
        self, client, pharmacist_user, pharmacist_headers
    ):
        resp = client.get("/pricing/entries", headers=pharmacist_headers)
        assert resp.status_code == 200

    def test_pharmacien_ne_peut_pas_creer(
        self, client, pharmacist_user, pharmacist_headers, pricing_payload_pct_marge
    ):
        resp = client.post("/pricing/entries", json=pricing_payload_pct_marge,
                           headers=pharmacist_headers)
        assert resp.status_code == 403

    def test_pharmacien_ne_peut_pas_supprimer(
        self, client, admin_user, admin_headers, pharmacist_user, pharmacist_headers,
        pricing_payload_pct_marge
    ):
        created = client.post("/pricing/entries", json=pricing_payload_pct_marge,
                              headers=admin_headers).json()
        resp = client.delete(f"/pricing/entries/{created['id']}",
                             headers=pharmacist_headers)
        assert resp.status_code == 403


# ═══════════════════════════════════════════════════════════════════════════════
# DÉTECTION DES DOUBLONS
# ═══════════════════════════════════════════════════════════════════════════════

class TestPricingDuplicates:
    def test_meme_nom_meme_lot_fusionne_quantites(
        self, client, admin_user, admin_headers, pricing_payload_pct_marge
    ):
        """R3: même nom + même lot → fusion des quantités, pas de doublon."""
        first = client.post("/pricing/entries", json=pricing_payload_pct_marge,
                            headers=admin_headers).json()
        second = client.post("/pricing/entries", json=pricing_payload_pct_marge,
                             headers=admin_headers).json()

        # Les deux ont le même ID (fusion)
        assert first["id"] == second["id"]
        # Les quantités ont été doublées
        expected_comprimes = pricing_payload_pct_marge["nb_cartons"] * \
                             pricing_payload_pct_marge["boites_par_carton"] * \
                             pricing_payload_pct_marge["plaquettes_par_boite"] * \
                             pricing_payload_pct_marge["comprimes_par_plaquette"] * 2
        assert second["total_comprimes"] == expected_comprimes

    def test_meme_nom_lot_different_cree_nouvelle_entree(
        self, client, admin_user, admin_headers, pricing_payload_pct_marge
    ):
        """Même médicament, lot différent → nouvelle entrée."""
        p2 = pricing_payload_pct_marge.copy()
        p2["lot"] = "LOT-TEST-DIFFERENT"

        first = client.post("/pricing/entries", json=pricing_payload_pct_marge,
                            headers=admin_headers).json()
        second = client.post("/pricing/entries", json=p2, headers=admin_headers).json()

        assert first["id"] != second["id"]


# ═══════════════════════════════════════════════════════════════════════════════
# ALERTES
# ═══════════════════════════════════════════════════════════════════════════════

class TestPricingAlerts:
    def test_alerte_expiration_bientot(
        self, client, admin_user, admin_headers, pricing_payload_pct_marge
    ):
        """Un médicament qui expire dans moins de 6 mois doit être flaggé."""
        payload = pricing_payload_pct_marge.copy()
        soon = (date.today() + timedelta(days=30)).isoformat()
        payload["date_peremption"] = soon

        client.post("/pricing/entries", json=payload, headers=admin_headers)

        resp = client.get("/pricing/alerts", headers=admin_headers)
        assert resp.status_code == 200
        body = resp.json()
        assert "expiring_soon" in body
        assert body["total_alerts"] >= 1

    def test_alerte_stock_faible(
        self, client, admin_user, admin_headers, pricing_payload_pct_marge
    ):
        """Un médicament sous le seuil d'alerte doit apparaître dans low_stock."""
        payload = pricing_payload_pct_marge.copy()
        payload["nb_cartons"] = 1
        payload["boites_par_carton"] = 1
        payload["plaquettes_par_boite"] = 1
        payload["comprimes_par_plaquette"] = 1
        payload["seuil_alerte"] = 100  # Seuil > stock réel (1 unité)

        client.post("/pricing/entries", json=payload, headers=admin_headers)

        resp = client.get("/pricing/alerts", headers=admin_headers)
        body = resp.json()
        assert body["total_alerts"] >= 1
        assert len(body["low_stock"]) >= 1

    def test_alertes_retournent_structure_correcte(
        self, client, admin_user, admin_headers
    ):
        resp = client.get("/pricing/alerts", headers=admin_headers)
        assert resp.status_code == 200
        body = resp.json()
        assert "expiring_soon" in body
        assert "low_stock" in body
        assert "total_alerts" in body


# ═══════════════════════════════════════════════════════════════════════════════
# AUTOCOMPLÉTION
# ═══════════════════════════════════════════════════════════════════════════════

class TestPricingAutocomplete:
    def test_autocomplete_retourne_resultats(
        self, client, admin_user, admin_headers, pricing_payload_pct_marge
    ):
        client.post("/pricing/entries", json=pricing_payload_pct_marge, headers=admin_headers)
        resp = client.get("/pricing/autocomplete?q=amox", headers=admin_headers)
        assert resp.status_code == 200
        body = resp.json()
        assert "results" in body
        assert len(body["results"]) >= 1
        assert any("amox" in r.lower() for r in body["results"])

    def test_autocomplete_sans_resultat(
        self, client, admin_user, admin_headers
    ):
        resp = client.get("/pricing/autocomplete?q=zzz_inexistant", headers=admin_headers)
        assert resp.status_code == 200
        assert resp.json()["results"] == []

    def test_autocomplete_sans_query_retourne_422(
        self, client, admin_user, admin_headers
    ):
        resp = client.get("/pricing/autocomplete", headers=admin_headers)
        assert resp.status_code == 422

    def test_autocomplete_sans_token_retourne_401(self, client):
        resp = client.get("/pricing/autocomplete?q=amox")
        assert resp.status_code == 401

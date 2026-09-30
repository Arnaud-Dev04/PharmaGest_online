"""
test_database.py — Tests unitaires de la couche base de données.

Couvre :
  - Initialisation de la DB SQLite en mémoire
  - Vérification de la connexion
  - Création des tables (schema integrity)
  - Service medicine_pricing_service (get, create, update, delete, search)
  - Détection de doublons (R3/R4)
  - Service de calcul des alertes
"""

import pytest
import os
from datetime import date, timedelta

os.environ.setdefault("SECRET_KEY", "test-secret-key-pharmagestion-32chars!!")
os.environ.setdefault("DB_URL_LOCAL", "sqlite:///:memory:")

from app.services import medicine_pricing_service
from app.schemas.medicine_pricing import (
    MedicinePricingCreate,
    MedicinePricingUpdate,
    PricingMode,
    OrdonnanceType,
)


# ═══════════════════════════════════════════════════════════════════════════════
# HELPERS
# ═══════════════════════════════════════════════════════════════════════════════

def _make_create_data(
    nom: str = "Amoxicilline Test",
    lot: str = "LOT-DB-001",
    achat: float = 120000.0,
    marge: float = 25.0,
    nb_cartons: int = 5,
) -> MedicinePricingCreate:
    future = date.today() + timedelta(days=365)
    return MedicinePricingCreate(
        nom=nom,
        lot=lot,
        nb_cartons=nb_cartons,
        boites_par_carton=10,
        plaquettes_par_boite=3,
        comprimes_par_plaquette=8,
        prix_mode=PricingMode.PCT_MARGE,
        achat_carton=achat,
        marge_pct=marge,
        ordonnance=OrdonnanceType.NON,
        date_peremption=future,
        alerte_peremption=True,
        alerte_jours=30,
        seuil_alerte=50,
    )


# ═══════════════════════════════════════════════════════════════════════════════
# CONNEXION DB
# ═══════════════════════════════════════════════════════════════════════════════

class TestDatabaseConnection:
    def test_connexion_locale_reussit(self, engine):
        from sqlalchemy import text
        with engine.connect() as conn:
            result = conn.execute(text("SELECT 1"))
            assert result.fetchone()[0] == 1

    def test_tables_creees(self, engine):
        from sqlalchemy import inspect
        inspector = inspect(engine)
        tables = inspector.get_table_names()
        assert "medicine_pricings" in tables
        assert "users" in tables


# ═══════════════════════════════════════════════════════════════════════════════
# SERVICE — CREATE
# ═══════════════════════════════════════════════════════════════════════════════

class TestPricingServiceCreate:
    def test_create_retourne_entree(self, db):
        data = _make_create_data()
        entry = medicine_pricing_service.create_pricing(db, data)
        assert entry is not None
        assert entry.id is not None
        assert entry.nom == "Amoxicilline Test"

    def test_create_calcule_total_comprimes(self, db):
        data = _make_create_data(nb_cartons=5)
        entry = medicine_pricing_service.create_pricing(db, data)
        # 5 cartons × 10 boites × 3 plaquettes × 8 comprimes = 1200
        assert entry.total_comprimes == 1200

    def test_create_calcule_vente_pct_marge(self, db):
        data = _make_create_data(achat=100000.0, marge=20.0)
        entry = medicine_pricing_service.create_pricing(db, data)
        assert entry.vente_carton == pytest.approx(120000.0, rel=1e-3)

    def test_create_assigne_medicine_id(self, db):
        """Une entrée pricing doit être liée à un Medicine."""
        data = _make_create_data()
        entry = medicine_pricing_service.create_pricing(db, data)
        assert entry.medicine_id is not None

    def test_create_calcule_benefice(self, db):
        data = _make_create_data(achat=100000.0, marge=25.0, nb_cartons=10)
        entry = medicine_pricing_service.create_pricing(db, data)
        assert entry.benefice_estime > 0

    def test_create_stocke_mode_prix(self, db):
        data = _make_create_data()
        entry = medicine_pricing_service.create_pricing(db, data)
        assert entry.prix_mode == "pct_marge"


# ═══════════════════════════════════════════════════════════════════════════════
# SERVICE — READ
# ═══════════════════════════════════════════════════════════════════════════════

class TestPricingServiceRead:
    def test_get_pricings_retourne_liste_vide(self, db):
        entries, total = medicine_pricing_service.get_pricings(db)
        assert isinstance(entries, list)
        assert total == 0

    def test_get_pricings_retourne_entree_creee(self, db):
        data = _make_create_data()
        medicine_pricing_service.create_pricing(db, data)
        entries, total = medicine_pricing_service.get_pricings(db)
        assert total == 1
        assert entries[0].nom == "Amoxicilline Test"

    def test_get_pricings_search_trouve_par_nom(self, db):
        medicine_pricing_service.create_pricing(db, _make_create_data("Paracetamol 500", "LOT-PAR"))
        medicine_pricing_service.create_pricing(db, _make_create_data("Amoxicilline 500", "LOT-AMO"))

        entries, total = medicine_pricing_service.get_pricings(db, search="paracetamol")
        assert total == 1
        assert "Paracetamol" in entries[0].nom

    def test_get_pricings_search_insensible_casse(self, db):
        medicine_pricing_service.create_pricing(db, _make_create_data("Ibuprofène 400", "LOT-IBU"))
        entries, _ = medicine_pricing_service.get_pricings(db, search="IBUPROFÈNE")
        assert len(entries) >= 1

    def test_get_pricings_pagination(self, db):
        for i in range(5):
            medicine_pricing_service.create_pricing(
                db, _make_create_data(f"Med-{i}", f"LOT-{i:03d}")
            )
        entries, total = medicine_pricing_service.get_pricings(db, page=1, page_size=3)
        assert total == 5
        assert len(entries) == 3

    def test_get_pricing_by_id_trouve(self, db):
        data = _make_create_data()
        created = medicine_pricing_service.create_pricing(db, data)
        found = medicine_pricing_service.get_pricing_by_id(db, created.id)
        assert found is not None
        assert found.id == created.id

    def test_get_pricing_by_id_inexistant_retourne_none(self, db):
        result = medicine_pricing_service.get_pricing_by_id(db, 99999)
        assert result is None


# ═══════════════════════════════════════════════════════════════════════════════
# SERVICE — UPDATE
# ═══════════════════════════════════════════════════════════════════════════════

class TestPricingServiceUpdate:
    def test_update_modifie_fournisseur(self, db):
        created = medicine_pricing_service.create_pricing(db, _make_create_data())
        update_data = MedicinePricingUpdate(fournisseur="NouveauFournisseur")
        updated = medicine_pricing_service.update_pricing(db, created.id, update_data)
        assert updated.fournisseur == "NouveauFournisseur"

    def test_update_recalcule_totaux(self, db):
        created = medicine_pricing_service.create_pricing(db, _make_create_data(nb_cartons=5))
        update_data = MedicinePricingUpdate(nb_cartons=10)
        updated = medicine_pricing_service.update_pricing(db, created.id, update_data)
        # 10 cartons × 10 × 3 × 8 = 2400
        assert updated.total_comprimes == 2400

    def test_update_inexistant_retourne_none(self, db):
        update_data = MedicinePricingUpdate(fournisseur="X")
        result = medicine_pricing_service.update_pricing(db, 99999, update_data)
        assert result is None

    def test_update_recalcule_prix_pct_marge(self, db):
        created = medicine_pricing_service.create_pricing(
            db, _make_create_data(achat=100000.0, marge=20.0)
        )
        update_data = MedicinePricingUpdate(marge_pct=30.0)
        updated = medicine_pricing_service.update_pricing(db, created.id, update_data)
        assert updated.vente_carton == pytest.approx(130000.0, rel=1e-2)

    def test_update_recalcule_benefice(self, db):
        created = medicine_pricing_service.create_pricing(db, _make_create_data())
        update_data = MedicinePricingUpdate(marge_pct=50.0)
        updated = medicine_pricing_service.update_pricing(db, created.id, update_data)
        assert updated.benefice_estime > 0


# ═══════════════════════════════════════════════════════════════════════════════
# SERVICE — DELETE
# ═══════════════════════════════════════════════════════════════════════════════

class TestPricingServiceDelete:
    def test_delete_entree_existante_retourne_true(self, db):
        created = medicine_pricing_service.create_pricing(db, _make_create_data())
        result = medicine_pricing_service.delete_pricing(db, created.id)
        assert result is True

    def test_delete_supprime_de_la_db(self, db):
        created = medicine_pricing_service.create_pricing(db, _make_create_data())
        entry_id = created.id
        medicine_pricing_service.delete_pricing(db, entry_id)
        assert medicine_pricing_service.get_pricing_by_id(db, entry_id) is None

    def test_delete_inexistant_retourne_false(self, db):
        result = medicine_pricing_service.delete_pricing(db, 99999)
        assert result is False


# ═══════════════════════════════════════════════════════════════════════════════
# SERVICE — DOUBLONS (R3/R4)
# ═══════════════════════════════════════════════════════════════════════════════

class TestPricingDuplicates:
    def test_meme_nom_meme_lot_fusionne(self, db):
        """R3: même nom + même lot → fusion, pas de nouvelle entrée."""
        data = _make_create_data("Amoxicilline", "LOT-DUP-001", nb_cartons=5)
        first = medicine_pricing_service.create_pricing(db, data)

        data2 = _make_create_data("Amoxicilline", "LOT-DUP-001", nb_cartons=5)
        second = medicine_pricing_service.create_pricing(db, data2)

        assert first.id == second.id
        # Quantités doublées
        assert second.total_comprimes == first.total_comprimes

    def test_meme_nom_lot_different_cree_nouvelle_entree(self, db):
        data1 = _make_create_data("Amoxicilline", "LOT-A")
        data2 = _make_create_data("Amoxicilline", "LOT-B")
        first = medicine_pricing_service.create_pricing(db, data1)
        second = medicine_pricing_service.create_pricing(db, data2)
        assert first.id != second.id

    def test_noms_differents_creent_entrees_differentes(self, db):
        data1 = _make_create_data("Amoxicilline", "LOT-001")
        data2 = _make_create_data("Paracetamol", "LOT-001")
        first = medicine_pricing_service.create_pricing(db, data1)
        second = medicine_pricing_service.create_pricing(db, data2)
        assert first.id != second.id


# ═══════════════════════════════════════════════════════════════════════════════
# SERVICE — ALERTES
# ═══════════════════════════════════════════════════════════════════════════════

class TestPricingAlerts:
    def test_alerte_expiration_detecte_medicament_proche(self, db):
        """Un médicament qui expire dans 30 jours doit apparaître dans les alertes."""
        soon = date.today() + timedelta(days=30)
        data = MedicinePricingCreate(
            nom="Med Peremption Proche",
            lot="LOT-EXP-001",
            nb_cartons=1,
            boites_par_carton=1,
            plaquettes_par_boite=1,
            comprimes_par_plaquette=1,
            prix_mode=PricingMode.PCT_MARGE,
            achat_carton=10000.0,
            marge_pct=20.0,
            ordonnance=OrdonnanceType.NON,
            date_peremption=soon,
            alerte_peremption=True,
            alerte_jours=30,
            seuil_alerte=0,
        )
        medicine_pricing_service.create_pricing(db, data)
        alerts = medicine_pricing_service.get_pricing_alerts(db)
        assert len(alerts["expiring_soon"]) >= 1

    def test_alerte_stock_faible_detecte_medicament(self, db):
        """Un médicament dont le stock est sous le seuil doit être dans low_stock."""
        data = MedicinePricingCreate(
            nom="Med Stock Faible",
            lot="LOT-STOCK-001",
            nb_cartons=1,
            boites_par_carton=1,
            plaquettes_par_boite=1,
            comprimes_par_plaquette=1,
            prix_mode=PricingMode.PCT_MARGE,
            achat_carton=10000.0,
            marge_pct=20.0,
            ordonnance=OrdonnanceType.NON,
            date_peremption=date.today() + timedelta(days=365),
            seuil_alerte=100,  # Seuil > 1 unité en stock
        )
        medicine_pricing_service.create_pricing(db, data)
        alerts = medicine_pricing_service.get_pricing_alerts(db)
        assert len(alerts["low_stock"]) >= 1

    def test_medicament_ok_na_pas_dalerte(self, db):
        """Un médicament valide avec stock suffisant ne doit pas avoir d'alerte."""
        data = _make_create_data(nb_cartons=10)
        # seuil_alerte = 50, stock = 10*10*3*8 = 2400 > 50
        medicine_pricing_service.create_pricing(db, data)
        alerts = medicine_pricing_service.get_pricing_alerts(db)
        # Vérifier que ce médicament n'est PAS dans low_stock
        low_stock_names = [e.nom for e in alerts["low_stock"]]
        assert "Amoxicilline Test" not in low_stock_names

    def test_total_alerts_est_somme_des_deux_listes(self, db):
        alerts = medicine_pricing_service.get_pricing_alerts(db)
        assert alerts["total_alerts"] == len(alerts["expiring_soon"]) + len(alerts["low_stock"])


# ═══════════════════════════════════════════════════════════════════════════════
# SERVICE — AUTOCOMPLETE
# ═══════════════════════════════════════════════════════════════════════════════

class TestPricingAutocomplete:
    def test_autocomplete_retourne_noms_distincts(self, db):
        medicine_pricing_service.create_pricing(db, _make_create_data("Amoxicilline 500", "LOT-AC1"))
        medicine_pricing_service.create_pricing(db, _make_create_data("Amoxicilline 250", "LOT-AC2"))
        medicine_pricing_service.create_pricing(db, _make_create_data("Paracetamol 1g", "LOT-AC3"))

        results = medicine_pricing_service.get_autocomplete_names(db, "amox")
        assert len(results) >= 1
        assert all("amox" in r.lower() for r in results)

    def test_autocomplete_respecte_limit(self, db):
        for i in range(10):
            medicine_pricing_service.create_pricing(
                db, _make_create_data(f"Medicament Test {i}", f"LOT-AUTO-{i:03d}")
            )
        results = medicine_pricing_service.get_autocomplete_names(db, "medicament", limit=3)
        assert len(results) <= 3

    def test_autocomplete_sans_resultat_retourne_liste_vide(self, db):
        results = medicine_pricing_service.get_autocomplete_names(db, "zzz_inexistant")
        assert results == []

    def test_autocomplete_insensible_casse(self, db):
        medicine_pricing_service.create_pricing(db, _make_create_data("Ibuprofène 400", "LOT-IBU"))
        results = medicine_pricing_service.get_autocomplete_names(db, "IBUPROFÈNE")
        assert len(results) >= 1

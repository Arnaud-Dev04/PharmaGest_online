"""
conftest.py — Fixtures partagées pour tous les tests PharmaGestion.

Fournit :
  - Base de données SQLite en mémoire (isolation totale entre tests)
  - Client HTTP TestClient FastAPI
  - Utilisateurs admin/pharmacien pré-créés avec tokens JWT valides
  - Données de test réutilisables (médicament, lot, pricing)
"""

import pytest
import os

# ── Variables d'environnement AVANT tout import du projet ─────────────────────
os.environ.setdefault("SECRET_KEY", "test-secret-key-pharmagestion-32chars!!")
os.environ.setdefault("DB_URL_LOCAL", "sqlite:///:memory:")
os.environ.setdefault("DB_URL_REMOTE", "")
os.environ.setdefault("ACCESS_TOKEN_EXPIRE_MINUTES", "60")
os.environ.setdefault("ALGORITHM", "HS256")

from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.database.core import Base, get_local_db
from app.models.user import User, UserRole
from app.utils.security import hash_password, create_access_token
from datetime import timedelta

# ── Import du point d'entrée applicatif ─────────────────────────────────────
from render_main import app


# ═══════════════════════════════════════════════════════════════════════════════
# DATABASE FIXTURES
# ═══════════════════════════════════════════════════════════════════════════════

@pytest.fixture(scope="session")
def engine():
    """Crée un engine SQLite en mémoire pour toute la session de test."""
    _engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
    )
    Base.metadata.create_all(bind=_engine)
    yield _engine
    Base.metadata.drop_all(bind=_engine)
    _engine.dispose()


@pytest.fixture(scope="function")
def db(engine):
    """
    Session DB isolée par test (rollback automatique après chaque test).
    Garantit l'isolation totale entre les tests.
    """
    TestingSession = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    connection = engine.connect()
    transaction = connection.begin()
    session = TestingSession(bind=connection)

    yield session

    session.close()
    transaction.rollback()
    connection.close()


# ═══════════════════════════════════════════════════════════════════════════════
# CLIENT HTTP FIXTURE
# ═══════════════════════════════════════════════════════════════════════════════

@pytest.fixture(scope="function")
def client(db):
    """
    TestClient FastAPI avec override de la dépendance DB.
    Chaque test dispose de sa propre DB isolée.
    """
    def _override_get_local_db():
        try:
            yield db
        finally:
            pass

    app.dependency_overrides[get_local_db] = _override_get_local_db
    with TestClient(app, raise_server_exceptions=True) as c:
        yield c
    app.dependency_overrides.clear()


# ═══════════════════════════════════════════════════════════════════════════════
# USER FIXTURES
# ═══════════════════════════════════════════════════════════════════════════════

@pytest.fixture
def admin_user(db) -> User:
    """Crée un utilisateur SUPER_ADMIN dans la DB de test."""
    user = User(
        username="test_admin",
        password_hash=hash_password("Admin@123!"),
        role=UserRole.SUPER_ADMIN,
        is_active=True,
        must_change_password=False,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


@pytest.fixture
def pharmacist_user(db) -> User:
    """Crée un utilisateur PHARMACIEN dans la DB de test."""
    user = User(
        username="test_pharmacist",
        password_hash=hash_password("Pharma@123!"),
        role=UserRole.PHARMACIEN,
        is_active=True,
        must_change_password=False,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


@pytest.fixture
def admin_token(admin_user) -> str:
    """JWT Bearer token pour l'admin."""
    return create_access_token(
        data={"sub": admin_user.username},
        expires_delta=timedelta(minutes=60),
    )


@pytest.fixture
def pharmacist_token(pharmacist_user) -> str:
    """JWT Bearer token pour le pharmacien."""
    return create_access_token(
        data={"sub": pharmacist_user.username},
        expires_delta=timedelta(minutes=60),
    )


@pytest.fixture
def admin_headers(admin_token) -> dict:
    """Headers HTTP avec token admin."""
    return {"Authorization": f"Bearer {admin_token}"}


@pytest.fixture
def pharmacist_headers(pharmacist_token) -> dict:
    """Headers HTTP avec token pharmacien."""
    return {"Authorization": f"Bearer {pharmacist_token}"}


# ═══════════════════════════════════════════════════════════════════════════════
# DONNÉES DE TEST — MÉDICAMENT
# ═══════════════════════════════════════════════════════════════════════════════

@pytest.fixture
def pricing_payload_pct_marge() -> dict:
    """Payload valide pour créer une entrée de prix en mode % marge."""
    from datetime import date, timedelta
    future_date = (date.today() + timedelta(days=365)).isoformat()
    return {
        "nom": "Amoxicilline 500mg",
        "dci": "Amoxicilline",
        "forme": "Gélule",
        "dosage": "500mg",
        "lot": "LOT-TEST-001",
        "fournisseur": "PharmaCorp",
        "nb_cartons": 5,
        "boites_par_carton": 10,
        "plaquettes_par_boite": 3,
        "comprimes_par_plaquette": 8,
        "prix_mode": "pct_marge",
        "achat_carton": 120000.0,
        "marge_pct": 25.0,
        "seuil_alerte": 50,
        "alerte_peremption": True,
        "alerte_jours": 30,
        "ordonnance": "non",
        "date_peremption": future_date,
    }


@pytest.fixture
def pricing_payload_carton_fixe() -> dict:
    """Payload valide pour créer une entrée de prix en mode prix fixe carton."""
    from datetime import date, timedelta
    future_date = (date.today() + timedelta(days=400)).isoformat()
    return {
        "nom": "Paracétamol 1g",
        "dci": "Paracétamol",
        "forme": "Comprimé",
        "dosage": "1g",
        "lot": "LOT-PCT-002",
        "nb_cartons": 10,
        "boites_par_carton": 20,
        "plaquettes_par_boite": 2,
        "comprimes_par_plaquette": 10,
        "prix_mode": "carton_fixe",
        "achat_carton": 80000.0,
        "vente_carton": 100000.0,
        "seuil_alerte": 20,
        "alerte_peremption": False,
        "ordonnance": "non",
        "date_peremption": future_date,
    }

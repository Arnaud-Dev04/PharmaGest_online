"""
Database configuration module.
Manages database connections with dual-engine capability:
  - MySQL / MariaDB (cloud or local XAMPP) via PyMySQL
  - SQLite (local file / offline standalone)
"""

from sqlalchemy import create_engine, text, event, inspect
from sqlalchemy.orm import Session, sessionmaker, DeclarativeBase, with_loader_criteria
from fastapi import HTTPException, status
from sqlalchemy.pool import NullPool
from typing import Generator
import os
import sys
from dotenv import load_dotenv

# ============================================================
# DOTENV LOADING (Dev, CWD, Root, and Frozen-compatible)
# ============================================================

def _find_dotenv():
    """Trouve le fichier .env dans les emplacements possibles."""
    if getattr(sys, 'frozen', False):
        exe_dir = os.path.dirname(sys.executable)
        env_path = os.path.join(exe_dir, '.env')
        if os.path.exists(env_path):
            return env_path
        return None

    # Ordre de recherche en mode dev
    candidates = [
        # 1. backend/.env
        os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".env")),
        # 2. Racine projet .env
        os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "..", ".env")),
        # 3. .env dans le dossier de travail courant
        os.path.abspath(".env"),
        # 4. .venv/.env (si placé dans le virtualenv par erreur)
        os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "..", ".venv", ".env")),
        # 5. .venv/.env.example (fallback)
        os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "..", ".venv", ".env.example")),
        # 6. backend/.env.example (fallback)
        os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".env.example")),
    ]
    for path in candidates:
        if os.path.exists(path) and os.path.isfile(path):
            return path
    return None

_env_file = _find_dotenv()
if _env_file:
    load_dotenv(_env_file)
    print(f"[*] Fichier d'environnement charge depuis : {_env_file}")
else:
    load_dotenv()


# ============================================================
# DATABASE PATH (POUR MODE EXECUTABLE FROZEN)
# ============================================================

def get_database_path():
    """Retourne le chemin SQLite en mode executable frozen (APPDATA)."""
    appdata_dir = os.path.join(os.getenv('APPDATA', '.'), 'PharmaGestion')
    os.makedirs(appdata_dir, exist_ok=True)
    db_path = os.path.join(appdata_dir, 'pharmacy_local.db')

    exe_dir = os.path.dirname(sys.executable)
    source_db = os.path.join(exe_dir, 'pharmacy_local.db')

    if not os.path.exists(db_path):
        import shutil
        if os.path.exists(source_db):
            try:
                shutil.copy2(source_db, db_path)
                print(f"[OK] DB initiale copiee vers {db_path}")
            except Exception as e:
                print(f"[ERROR] Impossible de copier la DB vers APPDATA: {e}")
    else:
        print(f"[*] Base client existante detectee dans {db_path} - Conservee intacte")

    return f"sqlite:///{db_path}"


# ============================================================
# DATABASE URLS & NORMALISATION
# ============================================================

def _normalize_db_url(url: str) -> str:
    """Normalise les URLs MySQL pour utiliser le driver pymysql."""
    if not url:
        return ""
    url = url.strip()
    if url.startswith("mysql://") and "+pymysql" not in url:
        return url.replace("mysql://", "mysql+pymysql://", 1)
    return url

def _is_mysql_url(url: str) -> bool:
    """Retourne True si l'URL est MySQL/MariaDB."""
    return "mysql" in url.lower() if url else False


def resolve_local_database_url(env: dict[str, str], *, frozen: bool = False) -> str:
    """Resolve the application database without ever falling back to cloud DB URLs."""
    if frozen:
        return get_database_path()
    return _normalize_db_url(
        env.get("DB_URL_LOCAL", "").strip() or "sqlite:///./pharmacy_local.db"
    )


if getattr(sys, 'frozen', False):
    DATABASE_URL_LOCAL = resolve_local_database_url(os.environ, frozen=True)
else:
    # A missing local URL must stay local; remote credentials are never a fallback.
    DATABASE_URL_LOCAL = resolve_local_database_url(os.environ)

DATABASE_URL_LOCAL = _normalize_db_url(DATABASE_URL_LOCAL)
DATABASE_URL_REMOTE = _normalize_db_url(os.getenv("DB_URL_REMOTE", ""))

# Message informatif sur la base active
if _is_mysql_url(DATABASE_URL_LOCAL):
    print(f"[OK] Configuration DB active : MySQL / MariaDB -> {DATABASE_URL_LOCAL.split('@')[-1] if '@' in DATABASE_URL_LOCAL else DATABASE_URL_LOCAL}")
else:
    print(f"[OK] Configuration DB active : SQLite local -> {DATABASE_URL_LOCAL}")


# ============================================================
# ENGINES CREATION
# ============================================================

def _create_configured_engine(url: str, is_local: bool = True):
    """Cree un engine SQLAlchemy adapte au type de base (MySQL ou SQLite)."""
    if _is_mysql_url(url):
        connect_args = {
            "connect_timeout": 15,
            "charset": "utf8mb4",
        }
        # Détection SSL automatique pour Aiven Cloud ou paramètres ssl
        if "aivencloud" in url.lower() or "ssl" in url.lower():
            import ssl
            ssl_ctx = ssl.create_default_context()
            ssl_ctx.check_hostname = False
            ssl_ctx.verify_mode = ssl.CERT_NONE
            connect_args["ssl"] = ssl_ctx

        return create_engine(
            url,
            pool_pre_ping=True,         # Reconnexion automatique si la connexion tombe
            pool_recycle=1800,          # Recycle les connexions toutes les 30 min (evite timeout MySQL)
            pool_size=5,
            max_overflow=10,
            connect_args=connect_args,
            echo=False
        )
    else:
        # SQLite
        engine = create_engine(
            url,
            connect_args={
                "check_same_thread": False,
                "timeout": 30,
            },
            poolclass=NullPool,
            echo=False
        )
        @event.listens_for(engine, "connect")
        def _set_sqlite_pragma(dbapi_connection, connection_record):
            try:
                cursor = dbapi_connection.cursor()
                cursor.execute("PRAGMA journal_mode = WAL")
                cursor.execute("PRAGMA synchronous = NORMAL")
                cursor.execute("PRAGMA busy_timeout = 10000")
                cursor.close()
            except Exception:
                pass
        return engine


engine_local = _create_configured_engine(DATABASE_URL_LOCAL, is_local=True)

if DATABASE_URL_REMOTE and DATABASE_URL_REMOTE != DATABASE_URL_LOCAL:
    engine_remote = _create_configured_engine(DATABASE_URL_REMOTE, is_local=False)
else:
    engine_remote = engine_local


# ============================================================
# SESSION FACTORIES
# ============================================================

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine_local)
SessionRemote = sessionmaker(autocommit=False, autoflush=False, bind=engine_remote)


# ============================================================
# DECLARATIVE BASE
# ============================================================

class Base(DeclarativeBase):
    pass


@event.listens_for(Session, "do_orm_execute")
def _apply_pharmacy_query_scope(execute_state):
    """Apply tenant criteria to ORM reads and bulk writes for scoped sessions."""
    session_info = execute_state.session.info
    if not session_info.get("pharmacy_scope_enabled"):
        return
    if session_info.get("is_platform_admin"):
        return

    pharmacy_id = session_info.get("pharmacy_id")
    if pharmacy_id is None:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="A pharmacy context is required for this operation",
        )

    if execute_state.is_select or execute_state.is_update or execute_state.is_delete:
        from app.models.base import PharmacyScopedMixin

        execute_state.statement = execute_state.statement.options(
            with_loader_criteria(
                PharmacyScopedMixin,
                lambda model: model.pharmacy_id == pharmacy_id,
                include_aliases=True,
            )
        )


@event.listens_for(Session, "before_flush")
def _assign_and_validate_pharmacy_on_flush(session, flush_context, instances):
    """Assign new scoped records to the session tenant and reject cross-tenant writes."""
    session_info = session.info
    if not session_info.get("pharmacy_scope_enabled") or session_info.get("is_platform_admin"):
        return

    pharmacy_id = session_info.get("pharmacy_id")
    if pharmacy_id is None:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="A pharmacy context is required for this operation",
        )

    from app.models.base import PharmacyScopedMixin
    scoped_tables = {
        mapper.local_table: mapper.local_table.c.pharmacy_id
        for mapper in Base.registry.mappers
        if issubclass(mapper.class_, PharmacyScopedMixin)
    }

    for record in session.new:
        if isinstance(record, PharmacyScopedMixin):
            record_pharmacy_id = getattr(record, "pharmacy_id", None)
            if record_pharmacy_id not in (None, pharmacy_id):
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail="Cannot create a record for another pharmacy",
                )
            record.pharmacy_id = pharmacy_id

    for record in session.new.union(session.dirty):
        if not isinstance(record, PharmacyScopedMixin):
            continue

        for relationship in record.__mapper__.relationships:
            if not issubclass(relationship.mapper.class_, PharmacyScopedMixin):
                continue
            if relationship.key not in record.__dict__:
                continue
            related = record.__dict__[relationship.key]
            if isinstance(related, bool):
                continue
            # A dynamic relationship stores an AppenderQuery, not related ORM
            # records; its foreign keys are validated in the column loop below.
            if hasattr(related, "session") and hasattr(related, "statement"):
                continue
            related_records = related if relationship.uselist else [related]
            for related_record in related_records:
                if related_record is None:
                    continue
                if isinstance(related_record, bool):
                    continue
                if related_record.pharmacy_id not in (None, pharmacy_id):
                    raise HTTPException(
                        status_code=status.HTTP_404_NOT_FOUND,
                        detail="Cannot link records from different pharmacies",
                    )
                if related_record in session.new:
                    related_record.pharmacy_id = pharmacy_id

        for column in record.__mapper__.columns:
            for foreign_key in column.foreign_keys:
                target_table = foreign_key.column.table
                target_pharmacy_column = scoped_tables.get(target_table)
                target_id = getattr(record, column.key, None)
                if target_pharmacy_column is None or target_id is None:
                    continue

                pending_target = next(
                    (
                        candidate for candidate in session.new
                        if candidate.__table__ is target_table
                        and getattr(candidate, foreign_key.column.name, None) == target_id
                    ),
                    None,
                )
                if pending_target is not None:
                    if pending_target.pharmacy_id not in (None, pharmacy_id):
                        raise HTTPException(
                            status_code=status.HTTP_404_NOT_FOUND,
                            detail="Cannot link records from different pharmacies",
                        )
                    pending_target.pharmacy_id = pharmacy_id
                    continue

                target_exists = session.connection().execute(
                    target_table.select()
                    .with_only_columns(target_table.c[foreign_key.column.name])
                    .where(
                        target_table.c[foreign_key.column.name] == target_id,
                        target_pharmacy_column == pharmacy_id,
                    )
                ).first()
                if target_exists is None:
                    raise HTTPException(
                        status_code=status.HTTP_404_NOT_FOUND,
                        detail="Referenced record is not available in this pharmacy",
                    )

    for record in session.dirty.union(session.deleted):
        if isinstance(record, PharmacyScopedMixin) and record.pharmacy_id != pharmacy_id:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Cannot modify a record owned by another pharmacy",
            )


# ============================================================
# FASTAPI DEPENDENCIES
# ============================================================

def get_local_db() -> Generator:
    """Session pour les operations de l'application."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def get_remote_db() -> Generator:
    """Session pour les operations distantes / synchronisation."""
    db = SessionRemote()
    try:
        yield db
    finally:
        db.close()


# ============================================================
# AUTO-MIGRATION / REPAIR SCHEMA
# ============================================================

def _auto_repair_schema(bind_engine):
    """
    Verifie et ajoute automatiquement toutes les colonnes manquantes
    dans les tables existantes, compatible SQLite et MySQL/MariaDB.
    """
    from sqlalchemy import inspect
    inspector = inspect(bind_engine)
    existing_tables = inspector.get_table_names()

    # Liste des colonnes additionnelles requises pour chaque table
    required_columns = {
        "users": [
            ("pharmacy_id", "INT NULL"),
        ],
        "medicines": [
            ("price_buy", "FLOAT NOT NULL DEFAULT 0.0"),
            ("price_sell", "FLOAT NOT NULL DEFAULT 0.0"),
            ("lot_fabricant", "VARCHAR(100) NULL"),
            ("date_entree_stock", "DATE NULL"),
            ("carton_type", "VARCHAR(50) DEFAULT 'Carton' NULL"),
            ("units_per_packaging", "INT DEFAULT 1 NULL"),
            ("packaging", "VARCHAR(50) NULL"),
            ("dosage_form", "VARCHAR(50) NULL"),
        ],
        "suppliers": [
            ("contact_name", "VARCHAR(100) NULL"),
        ],
        "sales": [
            ("code", "VARCHAR(50) NULL"),
            ("status", "VARCHAR(20) DEFAULT 'completed' NULL"),
            ("cancelled_at", "DATETIME NULL"),
            ("cancelled_by", "INT NULL"),
            ("insurance_provider", "VARCHAR(100) NULL"),
            ("insurance_card_id", "VARCHAR(50) NULL"),
            ("coverage_percent", "FLOAT DEFAULT 0.0 NULL"),
            ("sync_status", "VARCHAR(20) DEFAULT 'local_only' NULL"),
        ],
        "sale_items": [
            ("sale_type", "VARCHAR(20) DEFAULT 'packaging' NULL"),
            ("discount_percent", "FLOAT DEFAULT 0.0 NULL"),
        ],
        "stock_movements": [
            ("pricing_id", "INT NULL"),
        ],
        "medicine_pricing": [
            ("emplacement", "VARCHAR(100) NULL"),
        ],
        "pos_sales": [
            ("sale_uuid", "VARCHAR(36) NULL"),
            ("sync_status", "VARCHAR(20) NOT NULL DEFAULT 'local_only'"),
            ("synced_at", "DATETIME NULL"),
            ("customer_name", "VARCHAR(200) NULL"),
            ("customer_phone", "VARCHAR(30) NULL"),
            ("notes", "VARCHAR(500) NULL"),
            ("cancelled_at", "DATETIME NULL"),
            ("cancelled_by", "INT NULL"),
            ("insurance_provider", "VARCHAR(100) NULL"),
            ("insurance_card_id", "VARCHAR(50) NULL"),
            ("coverage_percent", "FLOAT DEFAULT 0.0 NULL"),
        ],
        "pos_sale_items": [
            ("sale_type", "VARCHAR(20) DEFAULT 'packaging' NULL"),
            ("discount_percent", "FLOAT DEFAULT 0.0 NULL"),
        ],
    }
    tenant_tables = (
        "deletion_logs", "batches", "customers", "medicine_pricing",
        "medicine_families", "medicine_types", "medicines", "pos_sales",
        "pos_sale_items", "restock_orders", "restock_items", "sales",
        "sale_items", "settings", "stock_movements", "suppliers",
        "sync_logs", "sync_queue", "users",
    )
    for table_name in tenant_tables:
        required_columns.setdefault(table_name, []).append(("pharmacy_id", "INT NULL"))

    with bind_engine.connect() as conn:
        for table, cols in required_columns.items():
            if table in existing_tables:
                existing_cols = {c['name'] for c in inspector.get_columns(table)}
                for col_name, col_def in cols:
                    if col_name not in existing_cols:
                        try:
                            conn.execute(text(f"ALTER TABLE {table} ADD COLUMN {col_name} {col_def}"))
                            conn.commit()
                            print(f"[AUTO-MIGRATE] Colonne '{col_name}' ajoutee a '{table}'")
                        except Exception as e:
                            # Ignorer si deja presente sous un autre nom/syntaxe
                            pass

        # Verification/mise a niveau contrainte composite multi-tenant sur 'users' (MySQL)
        if "users" in existing_tables and _is_mysql_url(str(bind_engine.url)):
            try:
                indexes = inspector.get_indexes("users")
                has_composite = any(
                    set(idx.get("column_names") or []) == {"pharmacy_id", "username"}
                    for idx in indexes
                )
                if not has_composite:
                    for idx in indexes:
                        if idx.get("column_names") == ["username"] and idx.get("unique") and idx.get("name"):
                            conn.execute(text(f"ALTER TABLE users DROP INDEX {idx['name']}"))
                            conn.commit()
                            break
                    conn.execute(text("ALTER TABLE users ADD CONSTRAINT uq_users_pharmacy_username UNIQUE (pharmacy_id, username)"))
                    conn.commit()
                    print("[AUTO-MIGRATE] Contrainte composite 'uq_users_pharmacy_username' ajoutee a 'users'")
            except Exception:
                pass


# ============================================================
# INIT LOCAL DB
# ============================================================

def init_local_db():
    """
    Initialise la base de donnees principale (MySQL ou SQLite).
    Cree les tables manquantes, repare le schema, et initialise les donnees requises.
    """
    from app.models import (
        User, Medicine, MedicineFamily, MedicineType,
        Supplier, Customer, Sale, SaleItem,
        RestockOrder, RestockItem, Settings, SyncLog,
        Batch, POSSale, POSSaleItem, StockMovement, Pharmacy,
        CashRegisterSession, CashRegisterMovement,
        DeletionLog
    )
    from app.models.medicine_pricing import MedicinePricing

    # 1. Creer les tables manquantes
    try:
        Base.metadata.create_all(bind=engine_local)
        db_type_str = "MySQL / MariaDB" if _is_mysql_url(DATABASE_URL_LOCAL) else "SQLite local"
        print(f"[OK] Tables verifiees/creees sur {db_type_str}")
    except Exception as e:
        print(f"[ERROR] Echec Base.metadata.create_all: {e}")
        raise

    # 2. Reparation automatique des colonnes manquantes
    try:
        _auto_repair_schema(engine_local)
    except Exception as e:
        print(f"[WARNING] Auto-repair schema: {e}")

    # 3. Super Admin & Utilisateur par defaut
    from sqlalchemy.orm import Session
    from app.models.user import User, UserRole
    from app.utils.security import hash_password
    from app.models.settings import Settings

    session = Session(bind=engine_local)
    try:
        initial_password = os.getenv("ADMIN_INITIAL_PASSWORD", "").strip()
        pharmacist_initial_password = os.getenv("PHARMACIST_INITIAL_PASSWORD", "").strip()

        default_pharmacy = session.query(Pharmacy).filter(
            Pharmacy.code == "LEGACY-DEFAULT"
        ).first()
        if not default_pharmacy:
            session.add(Pharmacy(
                name="Pharmacie principale",
                code="LEGACY-DEFAULT",
                is_active=True,
                plan="basic",
                max_users=3,
            ))
            session.commit()

        existing_tables = set(inspect(engine_local).get_table_names())
        tenant_tables = (
            "users", "deletion_logs", "batches", "customers", "medicine_pricing",
            "medicine_families", "medicine_types", "medicines", "pos_sales",
            "pos_sale_items", "restock_orders", "restock_items", "sales",
            "sale_items", "settings", "stock_movements", "suppliers",
            "sync_logs", "sync_queue",
        )
        for table_name in tenant_tables:
            if table_name not in existing_tables:
                continue
            columns = {column["name"] for column in inspect(engine_local).get_columns(table_name)}
            if "pharmacy_id" not in columns:
                continue
            user_filter = " AND role != 'platform_admin'" if table_name == "users" else ""
            session.execute(
                text(
                    f"UPDATE {table_name} SET pharmacy_id = :pharmacy_id "
                    f"WHERE pharmacy_id IS NULL{user_filter}"
                ),
                {"pharmacy_id": default_pharmacy.id},
            )
        session.commit()

        session.query(User).filter(
            User.pharmacy_id.is_(None),
            User.role != UserRole.PLATFORM_ADMIN,
        ).update(
            {User.pharmacy_id: default_pharmacy.id},
            synchronize_session=False,
        )
        session.commit()

        platform_username = os.getenv("PLATFORM_ADMIN_USERNAME", "").strip()
        platform_password = os.getenv("PLATFORM_ADMIN_PASSWORD", "")
        if platform_username and platform_password:
            platform_admin = session.query(User).filter(
                User.username == platform_username
            ).first()
            if platform_admin is None:
                session.add(User(
                    username=platform_username,
                    password_hash=hash_password(platform_password),
                    role=UserRole.PLATFORM_ADMIN,
                    is_active=True,
                    must_change_password=True,
                    pharmacy_id=None,
                ))
                session.commit()
                print("[OK] Platform administrator bootstrap account created")
            elif platform_admin.role != UserRole.PLATFORM_ADMIN:
                print("[WARNING] PLATFORM_ADMIN_USERNAME is already assigned to a non-platform user")

        # Super admin "arnaud"
        admin = session.query(User).filter(User.username == "arnaud").first()
        if not admin and initial_password:
            admin_user = User(
                username="arnaud",
                password_hash=hash_password(initial_password),
                role=UserRole.SUPER_ADMIN,
                is_active=True,
                must_change_password=True,
                pharmacy_id=default_pharmacy.id,
            )
            session.add(admin_user)
            session.commit()
            print("[OK] Pharmacy administrator bootstrap account created; password change required")

        # Optional pharmacist bootstrap; never create an account with a known default password.
        pharm = session.query(User).filter(User.username == "pharmacien").first()
        if not pharm and pharmacist_initial_password:
            pharm_user = User(
                username="pharmacien",
                password_hash=hash_password(pharmacist_initial_password),
                role=UserRole.PHARMACIST,
                is_active=True,
                must_change_password=True,
                pharmacy_id=default_pharmacy.id,
            )
            session.add(pharm_user)
            session.commit()
            print("[OK] Pharmacist bootstrap account created; password change required")

        # Parametre is_first_setup
        first_setup = session.query(Settings).filter(Settings.key == "is_first_setup").first()
        if not first_setup:
            session.add(Settings(key="is_first_setup", value="true"))
            session.commit()

    except Exception as e:
        print(f"[WARNING] Admin seeding skipped: {e}")
        session.rollback()
    finally:
        session.close()

    # 4. Auto-migration des lots par defaut si necessaire
    session = Session(bind=engine_local)
    try:
        from app.models.batch import Batch
        from app.models.medicine import Medicine
        from datetime import date, timedelta

        meds_no_batches = session.query(Medicine).filter(
            Medicine.is_active == True,
            Medicine.quantity > 0,
            ~Medicine.id.in_(session.query(Batch.medicine_id).distinct())
        ).all()

        if meds_no_batches:
            for med in meds_no_batches:
                default_expiry = med.expiry_date if med.expiry_date else (date.today() + timedelta(days=365))
                batch = Batch(
                    medicine_id=med.id,
                    batch_number=f"INIT-{med.code}",
                    expiration_date=default_expiry,
                    quantity=med.quantity,
                    purchase_price=getattr(med, "price_buy", 0.0) or 0.0,
                    is_active=True
                )
                session.add(batch)
            session.commit()
            print(f"[OK] {len(meds_no_batches)} lot(s) initial(aux) cree(s)")
    except Exception as e:
        print(f"[WARNING] Batch migration skipped: {e}")
        session.rollback()
    finally:
        session.close()

    # 5. Reconcilier MedicinePricing avec Batch
    session = Session(bind=engine_local)
    try:
        from app.services.pos_service import reconcile_pricing_stock
        synced_count = reconcile_pricing_stock(session)
        if synced_count > 0:
            print(f"[OK] {synced_count} entrees de stock reconciliees avec les lots")
    except Exception as e:
        print(f"[WARNING] Pricing reconciliation skipped: {e}")
        session.rollback()
    finally:
        session.close()


# ============================================================
# INIT REMOTE DB
# ============================================================

def init_remote_db():
    """Initialise la base distante si configuree."""
    if engine_remote is engine_local:
        return
    try:
        Base.metadata.create_all(bind=engine_remote)
        _auto_repair_schema(engine_remote)
        print("[OK] Remote database initialisee avec succes!")
    except Exception as e:
        print(f"[ERROR] Echec init remote database: {e}")


# ============================================================
# CHECK DATABASE CONNECTION
# ============================================================

def check_database_connection(use_remote: bool = False) -> bool:
    """Verifie si la base de donnees est joignable."""
    engine = engine_remote if use_remote else engine_local
    try:
        with engine.connect() as conn:
            conn.execute(text("SELECT 1"))
        return True
    except Exception:
        return False

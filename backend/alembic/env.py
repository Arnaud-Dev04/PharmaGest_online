"""
Alembic environment configuration.
Connects to the database via DB_URL_REMOTE (MySQL) or DB_URL_LOCAL (SQLite).

Usage:
  # Migrations sur la DB locale SQLite (dev)
  alembic upgrade head

  # Migrations sur la DB MySQL remote (production)
  DB_URL_REMOTE=mysql+pymysql://user:pass@host:3306/pharma_db alembic upgrade head
"""

import os
from logging.config import fileConfig

from sqlalchemy import engine_from_config, pool, create_engine
from alembic import context
from dotenv import load_dotenv

load_dotenv()

# Alembic Config object
config = context.config

# Interpret the config file for Python logging.
if config.config_file_name is not None:
    fileConfig(config.config_file_name)

# Import Base metadata for autogenerate support
from app.database.core import Base
from app.models import (
    User, Medicine, MedicineFamily, MedicineType,
    Supplier, Customer, Sale, SaleItem,
    RestockOrder, RestockItem, Settings, SyncLog,
    Batch, POSSale, POSSaleItem, StockMovement, Pharmacy,
    DeletionLog,
)
from app.models.medicine_pricing import MedicinePricing

target_metadata = Base.metadata


def get_url() -> str:
    """
    Resolve the migration target only from an explicit migration-specific URL.

    This deliberately never falls back to DB_URL_REMOTE: both .env files in this
    project may contain production credentials, so an implicit Alembic command
    must not be able to modify the cloud database.
    """
    url = os.getenv("PHARMAGEST_MIGRATION_DATABASE_URL", "").strip()
    if not url:
        raise RuntimeError(
            "Set PHARMAGEST_MIGRATION_DATABASE_URL explicitly before running Alembic; "
            "DB_URL_REMOTE is never selected implicitly."
        )
    if url.startswith("mysql://") and "+pymysql" not in url:
        url = url.replace("mysql://", "mysql+pymysql://", 1)
    return url


def run_migrations_offline() -> None:
    """Run migrations in 'offline' mode (generates SQL without connecting)."""
    url = get_url()
    context.configure(
        url=url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
        compare_type=True,
    )

    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online() -> None:
    """Run migrations in 'online' mode (connects to the database)."""
    url = get_url()

    connect_args = {}
    if "sqlite" in url:
        connect_args["check_same_thread"] = False
    elif "mysql" in url:
        connect_args["charset"] = "utf8mb4"

    connectable = create_engine(
        url,
        poolclass=pool.NullPool,
        connect_args=connect_args,
    )

    with connectable.connect() as connection:
        context.configure(
            connection=connection,
            target_metadata=target_metadata,
            compare_type=True,      # Detecte les changements de type de colonnes
            compare_server_default=True,
        )

        with context.begin_transaction():
            context.run_migrations()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()

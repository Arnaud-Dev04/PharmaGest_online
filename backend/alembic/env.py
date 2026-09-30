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
    Batch, POSSale, POSSaleItem, StockMovement,
    DeletionLog,
)
from app.models.medicine_pricing import MedicinePricing

target_metadata = Base.metadata


def get_url() -> str:
    """
    Determine quelle URL de DB utiliser pour les migrations.

    Priorite :
      1. DB_URL_REMOTE si definie (MySQL cloud)
      2. DB_URL_LOCAL  si definie (SQLite local)
      3. SQLite par defaut (./pharmacy_local.db)
    """
    remote = os.getenv("DB_URL_REMOTE", "")
    if remote:
        # Normaliser mysql:// -> mysql+pymysql://
        if remote.startswith("mysql://") and "+pymysql" not in remote:
            remote = remote.replace("mysql://", "mysql+pymysql://", 1)
        return remote
    return os.getenv("DB_URL_LOCAL", "sqlite:///./pharmacy_local.db")


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

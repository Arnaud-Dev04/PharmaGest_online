"""Create the pharmacy tenant registry.

Revision ID: 20261001_create_pharmacies
Revises: 20260515_pos_lot_pricing
Create Date: 2026-10-01
"""

from alembic import op
import sqlalchemy as sa


revision = "20261001_create_pharmacies"
down_revision = "20260515_pos_lot_pricing"
branch_labels = None
depends_on = None


def _table_exists(bind, table_name):
    return table_name in sa.inspect(bind).get_table_names()


def _index_exists(bind, table_name, index_name):
    indexes = sa.inspect(bind).get_indexes(table_name)
    return any(index["name"] == index_name for index in indexes)


def upgrade():
    bind = op.get_bind()

    if not _table_exists(bind, "pharmacies"):
        op.create_table(
            "pharmacies",
            sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
            sa.Column("created_at", sa.DateTime(), server_default=sa.func.now(), nullable=False),
            sa.Column("updated_at", sa.DateTime(), server_default=sa.func.now(), nullable=False),
            sa.Column("name", sa.String(length=200), nullable=False),
            sa.Column("code", sa.String(length=50), nullable=False),
            sa.Column("address", sa.String(length=500), nullable=True),
            sa.Column("phone", sa.String(length=50), nullable=True),
            sa.Column("email", sa.String(length=200), nullable=True),
            sa.Column("country", sa.String(length=100), nullable=True),
            sa.Column("city", sa.String(length=100), nullable=True),
            sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
            sa.Column("plan", sa.String(length=30), nullable=False, server_default="basic"),
            sa.Column("max_users", sa.Integer(), nullable=False, server_default="3"),
        )

    if not _index_exists(bind, "pharmacies", "ix_pharmacies_code"):
        op.create_index("ix_pharmacies_code", "pharmacies", ["code"], unique=True)

    pharmacies = sa.table(
        "pharmacies",
        sa.column("id", sa.Integer()),
        sa.column("name", sa.String(length=200)),
        sa.column("code", sa.String(length=50)),
        sa.column("is_active", sa.Boolean()),
        sa.column("plan", sa.String(length=30)),
        sa.column("max_users", sa.Integer()),
    )
    exists = bind.execute(
        sa.select(pharmacies.c.id).where(pharmacies.c.code == "LEGACY-DEFAULT")
    ).first()
    if not exists:
        bind.execute(pharmacies.insert().values(
            name="Pharmacie principale",
            code="LEGACY-DEFAULT",
            is_active=True,
            plan="basic",
            max_users=3,
        ))


def downgrade():
    # Keep tenant data intact; rollback is handled through a backup-aware procedure.
    pass
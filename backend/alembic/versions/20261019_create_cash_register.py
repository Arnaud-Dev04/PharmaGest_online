"""Create tenant-scoped cashier sessions and movements.

Revision ID: 20261019_create_cash_register
Revises: 20261001_scope_business_tables
Create Date: 2026-10-19
"""

from alembic import op
import sqlalchemy as sa


revision = "20261019_create_cash_register"
down_revision = "20261001_scope_business_tables"
branch_labels = None
depends_on = None


def upgrade():
    bind = op.get_bind()
    tables = set(sa.inspect(bind).get_table_names())

    if "cash_register_sessions" not in tables:
        op.create_table(
            "cash_register_sessions",
            sa.Column("cashier_id", sa.Integer(), nullable=False),
            sa.Column("opened_at", sa.DateTime(), nullable=False),
            sa.Column("opening_amount", sa.Float(), nullable=False, server_default="0"),
            sa.Column("closed_at", sa.DateTime(), nullable=True),
            sa.Column("closed_by_id", sa.Integer(), nullable=True),
            sa.Column("expected_amount", sa.Float(), nullable=True),
            sa.Column("counted_amount", sa.Float(), nullable=True),
            sa.Column("variance", sa.Float(), nullable=True),
            sa.Column("status", sa.String(length=20), nullable=False, server_default="open"),
            sa.Column("notes", sa.String(length=500), nullable=True),
            sa.Column("sync_status", sa.String(length=20), nullable=False, server_default="pending"),
            sa.Column("session_uuid", sa.String(length=36), nullable=False),
            sa.Column("active_key", sa.String(length=120), nullable=True),
            sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
            sa.Column("created_at", sa.DateTime(), nullable=False, server_default=sa.func.now()),
            sa.Column("updated_at", sa.DateTime(), nullable=False, server_default=sa.func.now()),
            sa.Column("pharmacy_id", sa.Integer(), nullable=True),
            sa.ForeignKeyConstraint(["cashier_id"], ["users.id"]),
            sa.ForeignKeyConstraint(["closed_by_id"], ["users.id"]),
            sa.ForeignKeyConstraint(["pharmacy_id"], ["pharmacies.id"]),
            sa.UniqueConstraint("session_uuid", name="uq_cash_register_session_uuid"),
            sa.UniqueConstraint("active_key", name="uq_cash_register_active_key"),
        )

    indexes = {idx["name"] for idx in sa.inspect(bind).get_indexes("cash_register_sessions")}
    if "ix_cash_register_sessions_pharmacy_id" not in indexes:
        op.create_index("ix_cash_register_sessions_pharmacy_id", "cash_register_sessions", ["pharmacy_id"])
    if "ix_cash_register_sessions_cashier_id" not in indexes:
        op.create_index("ix_cash_register_sessions_cashier_id", "cash_register_sessions", ["cashier_id"])
    if "ix_cash_register_sessions_status" not in indexes:
        op.create_index("ix_cash_register_sessions_status", "cash_register_sessions", ["status"])

    tables = set(sa.inspect(bind).get_table_names())
    if "cash_register_movements" not in tables:
        op.create_table(
            "cash_register_movements",
            sa.Column("movement_uuid", sa.String(length=36), nullable=False),
            sa.Column("session_uuid", sa.String(length=36), nullable=False),
            sa.Column("session_id", sa.Integer(), nullable=False),
            sa.Column("cashier_id", sa.Integer(), nullable=False),
            sa.Column("movement_type", sa.String(length=20), nullable=False),
            sa.Column("amount", sa.Float(), nullable=False),
            sa.Column("reason", sa.String(length=255), nullable=False),
            sa.Column("occurred_at", sa.DateTime(), nullable=False),
            sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
            sa.Column("created_at", sa.DateTime(), nullable=False, server_default=sa.func.now()),
            sa.Column("updated_at", sa.DateTime(), nullable=False, server_default=sa.func.now()),
            sa.Column("pharmacy_id", sa.Integer(), nullable=True),
            sa.ForeignKeyConstraint(["cashier_id"], ["users.id"]),
            sa.ForeignKeyConstraint(["pharmacy_id"], ["pharmacies.id"]),
            sa.ForeignKeyConstraint(["session_id"], ["cash_register_sessions.id"]),
            sa.UniqueConstraint("movement_uuid", name="uq_cash_register_movement_uuid"),
        )

    indexes = {idx["name"] for idx in sa.inspect(bind).get_indexes("cash_register_movements")}
    if "ix_cash_register_movements_pharmacy_id" not in indexes:
        op.create_index("ix_cash_register_movements_pharmacy_id", "cash_register_movements", ["pharmacy_id"])
    if "ix_cash_register_movements_session_id" not in indexes:
        op.create_index("ix_cash_register_movements_session_id", "cash_register_movements", ["session_id"])
    if "ix_cash_register_movements_cashier_id" not in indexes:
        op.create_index("ix_cash_register_movements_cashier_id", "cash_register_movements", ["cashier_id"])
    if "ix_cash_register_movements_session_uuid" not in indexes:
        op.create_index("ix_cash_register_movements_session_uuid", "cash_register_movements", ["session_uuid"])

    if "cash_session_uuid" not in {
        column["name"] for column in sa.inspect(bind).get_columns("pos_sales")
    }:
        with op.batch_alter_table("pos_sales") as batch_op:
            batch_op.add_column(sa.Column("cash_session_uuid", sa.String(length=36), nullable=True))

    pos_indexes = {idx["name"] for idx in sa.inspect(bind).get_indexes("pos_sales")}
    if "ix_pos_sales_cash_session_uuid" not in pos_indexes:
        op.create_index("ix_pos_sales_cash_session_uuid", "pos_sales", ["cash_session_uuid"])


def downgrade():
    # Financial records are intentionally preserved; rollback requires an explicit,
    # backup-aware operational procedure.
    pass
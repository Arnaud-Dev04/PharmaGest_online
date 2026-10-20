"""Add pharmacy ownership to business tables.

Revision ID: 20261001_scope_business_tables
Revises: 20261001_add_user_pharmacy_id
Create Date: 2026-10-01
"""

from alembic import op
import sqlalchemy as sa


revision = "20261001_scope_business_tables"
down_revision = "20261001_add_user_pharmacy_id"
branch_labels = None
depends_on = None


TENANT_TABLES = (
    "deletion_logs",
    "batches",
    "customers",
    "medicine_pricing",
    "medicine_families",
    "medicine_types",
    "medicines",
    "pos_sales",
    "pos_sale_items",
    "restock_orders",
    "restock_items",
    "sales",
    "sale_items",
    "settings",
    "stock_movements",
    "suppliers",
    "sync_logs",
    "sync_queue",
)

TENANT_UNIQUES = {
    "customers": ("phone", "uq_customers_pharmacy_phone"),
    "medicine_families": ("name", "uq_medicine_families_pharmacy_name"),
    "medicine_types": ("name", "uq_medicine_types_pharmacy_name"),
    "medicines": ("code", "uq_medicines_pharmacy_code"),
    "sales": ("code", "uq_sales_pharmacy_code"),
    "pos_sales": ("code", "uq_pos_sales_pharmacy_code"),
    "settings": ("key", "uq_settings_pharmacy_key"),
}


def _table_exists(bind, table_name):
    return table_name in sa.inspect(bind).get_table_names()


def _column_exists(bind, table_name, column_name):
    return any(
        column["name"] == column_name
        for column in sa.inspect(bind).get_columns(table_name)
    )


def _foreign_key_exists(bind, table_name):
    return any(
        key["referred_table"] == "pharmacies"
        and "pharmacy_id" in key["constrained_columns"]
        for key in sa.inspect(bind).get_foreign_keys(table_name)
    )


def _index_exists(bind, table_name, index_name):
    return any(
        index["name"] == index_name
        for index in sa.inspect(bind).get_indexes(table_name)
    )


def _unique_constraint_exists(bind, table_name, constraint_name):
    return any(
        constraint.get("name") == constraint_name
        for constraint in sa.inspect(bind).get_unique_constraints(table_name)
    )


def upgrade():
    bind = op.get_bind()
    pharmacies = sa.table(
        "pharmacies",
        sa.column("id", sa.Integer()),
        sa.column("code", sa.String(length=50)),
    )
    default_pharmacy_id = bind.execute(
        sa.select(pharmacies.c.id).where(pharmacies.c.code == "LEGACY-DEFAULT")
    ).scalar_one_or_none()
    if default_pharmacy_id is None:
        raise RuntimeError("LEGACY-DEFAULT pharmacy is required before tenant backfill")

    for table_name in TENANT_TABLES:
        if not _table_exists(bind, table_name):
            continue

        column_exists = _column_exists(bind, table_name, "pharmacy_id")
        foreign_key_exists = _foreign_key_exists(bind, table_name)
        if not column_exists or not foreign_key_exists:
            with op.batch_alter_table(table_name) as batch_op:
                if not column_exists:
                    batch_op.add_column(sa.Column("pharmacy_id", sa.Integer(), nullable=True))
                if not foreign_key_exists:
                    batch_op.create_foreign_key(
                        f"fk_{table_name}_pharmacy_id_pharmacies",
                        "pharmacies",
                        ["pharmacy_id"],
                        ["id"],
                    )

        index_name = f"ix_{table_name}_pharmacy_id"
        if not _index_exists(bind, table_name, index_name):
            op.create_index(index_name, table_name, ["pharmacy_id"])

        tenant_table = sa.table(
            table_name,
            sa.column("pharmacy_id", sa.Integer()),
        )
        bind.execute(
            tenant_table.update()
            .where(tenant_table.c.pharmacy_id.is_(None))
            .values(pharmacy_id=default_pharmacy_id)
        )

    for table_name, (legacy_column, constraint_name) in TENANT_UNIQUES.items():
        if not _table_exists(bind, table_name):
            continue

        inspector = sa.inspect(bind)
        legacy_indexes = [
            index for index in inspector.get_indexes(table_name)
            if index.get("unique") and index.get("column_names") == [legacy_column]
        ]
        for index in legacy_indexes:
            op.drop_index(index["name"], table_name=table_name)

        if _unique_constraint_exists(bind, table_name, constraint_name):
            continue

        legacy_constraints = [
            constraint for constraint in sa.inspect(bind).get_unique_constraints(table_name)
            if constraint.get("column_names") == [legacy_column]
        ]
        with op.batch_alter_table(table_name) as batch_op:
            for constraint in legacy_constraints:
                if constraint.get("name"):
                    batch_op.drop_constraint(constraint["name"], type_="unique")
            batch_op.create_unique_constraint(
                constraint_name,
                ["pharmacy_id", legacy_column],
            )


def downgrade():
    # Tenant assignments are data; rollback requires an explicit backup-aware procedure.
    pass
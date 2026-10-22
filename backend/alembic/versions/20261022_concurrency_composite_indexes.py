"""Add invoice_sequences table and tenant composite indexes for high concurrency.

Revision ID: 20261022_concurrency_composite_indexes
Revises: 20261021_composite_user_pharmacy
Create Date: 2026-10-22
"""

from alembic import op
import sqlalchemy as sa


revision = "20261022_concurrency_composite_indexes"
down_revision = "20261021_composite_user_pharmacy"
branch_labels = None
depends_on = None


def _table_exists(bind, table_name: str) -> bool:
    return table_name in sa.inspect(bind).get_table_names()


def _index_exists(bind, table_name: str, index_name: str) -> bool:
    if not _table_exists(bind, table_name):
        return False
    return any(
        idx.get("name") == index_name
        for idx in sa.inspect(bind).get_indexes(table_name)
    )


def upgrade():
    bind = op.get_bind()

    # 1. Create invoice_sequences table if missing
    if not _table_exists(bind, "invoice_sequences"):
        op.create_table(
            "invoice_sequences",
            sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
            sa.Column("pharmacy_id", sa.Integer(), sa.ForeignKey("pharmacies.id"), nullable=True, index=True),
            sa.Column("year", sa.Integer(), nullable=False, index=True),
            sa.Column("current_number", sa.Integer(), nullable=False, server_default="0"),
            sa.Column("created_at", sa.DateTime(timezone=False), server_default=sa.func.now(), nullable=False),
            sa.Column("updated_at", sa.DateTime(timezone=False), server_default=sa.func.now(), nullable=False),
            sa.UniqueConstraint("pharmacy_id", "year", name="uq_invoice_sequences_pharmacy_year"),
        )

    # 2. Composite indexes on medicines
    if _table_exists(bind, "medicines"):
        if not _index_exists(bind, "medicines", "ix_medicines_pharma_active_name"):
            op.create_index(
                "ix_medicines_pharma_active_name",
                "medicines",
                ["pharmacy_id", "is_active", "name"],
            )
        if not _index_exists(bind, "medicines", "ix_medicines_pharma_barcode"):
            op.create_index(
                "ix_medicines_pharma_barcode",
                "medicines",
                ["pharmacy_id", "code_barres"],
            )

    # 3. Composite indexes on batches
    if _table_exists(bind, "batches"):
        if not _index_exists(bind, "batches", "ix_batches_pharma_med_expiry"):
            op.create_index(
                "ix_batches_pharma_med_expiry",
                "batches",
                ["pharmacy_id", "medicine_id", "is_active", "expiration_date"],
            )

    # 4. Composite indexes on pos_sales
    if _table_exists(bind, "pos_sales"):
        if not _index_exists(bind, "pos_sales", "ix_pos_sales_pharma_date_status"):
            op.create_index(
                "ix_pos_sales_pharma_date_status",
                "pos_sales",
                ["pharmacy_id", "date", "status"],
            )

    # 5. Composite indexes on stock_movements
    if _table_exists(bind, "stock_movements"):
        if not _index_exists(bind, "stock_movements", "ix_stock_movements_pharma_med_date"):
            op.create_index(
                "ix_stock_movements_pharma_med_date",
                "stock_movements",
                ["pharmacy_id", "medicine_id", "created_at"],
            )

    # 6. Composite indexes on cash_register_sessions
    if _table_exists(bind, "cash_register_sessions"):
        if not _index_exists(bind, "cash_register_sessions", "ix_cash_register_pharma_user_status"):
            op.create_index(
                "ix_cash_register_pharma_user_status",
                "cash_register_sessions",
                ["pharmacy_id", "cashier_id", "status"],
            )


def downgrade():
    bind = op.get_bind()
    indexes = [
        ("medicines", "ix_medicines_pharma_active_name"),
        ("medicines", "ix_medicines_pharma_barcode"),
        ("batches", "ix_batches_pharma_med_expiry"),
        ("pos_sales", "ix_pos_sales_pharma_date_status"),
        ("stock_movements", "ix_stock_movements_pharma_med_date"),
        ("cash_register_sessions", "ix_cash_register_pharma_user_status"),
    ]
    for table_name, idx_name in indexes:
        if _index_exists(bind, table_name, idx_name):
            op.drop_index(idx_name, table_name=table_name)

    if _table_exists(bind, "invoice_sequences"):
        op.drop_table("invoice_sequences")

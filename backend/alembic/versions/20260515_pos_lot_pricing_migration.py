"""Add POS batch tracking and pricing compatibility columns.

Revision ID: 20260515_pos_lot_pricing
Revises:
Create Date: 2026-05-15
"""

from alembic import op
import sqlalchemy as sa


revision = "20260515_pos_lot_pricing"
down_revision = None
branch_labels = None
depends_on = None


def _table_names(bind):
    return set(sa.inspect(bind).get_table_names())


def _column_names(bind, table_name):
    if table_name not in _table_names(bind):
        return set()
    return {col["name"] for col in sa.inspect(bind).get_columns(table_name)}


def _add_column_if_missing(bind, table_name, column):
    if column.name not in _column_names(bind, table_name):
        op.add_column(table_name, column)


def upgrade():
    bind = op.get_bind()
    tables = _table_names(bind)

    if "batches" not in tables:
        op.create_table(
            "batches",
            sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
            sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
            sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
            sa.Column("batch_number", sa.String(length=100), nullable=False),
            sa.Column("medicine_id", sa.Integer(), sa.ForeignKey("medicines.id"), nullable=False),
            sa.Column("expiration_date", sa.Date(), nullable=False),
            sa.Column("quantity", sa.Float(), nullable=False, server_default="0"),
            sa.Column("purchase_price", sa.Float(), nullable=True),
            sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
        )
        op.create_index("ix_batches_batch_number", "batches", ["batch_number"])
        op.create_index("ix_batches_expiration_date", "batches", ["expiration_date"])

    if "pos_sales" not in tables:
        op.create_table(
            "pos_sales",
            sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
            sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
            sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
            sa.Column("uuid", sa.String(length=36), nullable=False),
            sa.Column("code", sa.String(length=50), nullable=False),
            sa.Column("total_amount", sa.Float(), nullable=False),
            sa.Column("payment_method", sa.String(length=20), nullable=False, server_default="cash"),
            sa.Column("date", sa.DateTime(), nullable=False),
            sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=False),
            sa.Column("customer_id", sa.Integer(), sa.ForeignKey("customers.id"), nullable=True),
            sa.Column("customer_name", sa.String(length=200), nullable=True),
            sa.Column("status", sa.String(length=20), nullable=False, server_default="completed"),
            sa.Column("cancelled_at", sa.DateTime(), nullable=True),
            sa.Column("cancelled_by", sa.Integer(), sa.ForeignKey("users.id"), nullable=True),
            sa.Column("insurance_provider", sa.String(length=100), nullable=True),
            sa.Column("insurance_card_id", sa.String(length=50), nullable=True),
            sa.Column("coverage_percent", sa.Float(), nullable=True, server_default="0"),
        )
        op.create_index("ix_pos_sales_uuid", "pos_sales", ["uuid"], unique=True)
        op.create_index("ix_pos_sales_code", "pos_sales", ["code"], unique=True)
        op.create_index("ix_pos_sales_date", "pos_sales", ["date"])

    if "pos_sale_items" not in tables:
        op.create_table(
            "pos_sale_items",
            sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
            sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
            sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
            sa.Column("sale_id", sa.Integer(), sa.ForeignKey("pos_sales.id", ondelete="CASCADE"), nullable=False),
            sa.Column("medicine_id", sa.Integer(), sa.ForeignKey("medicines.id"), nullable=False),
            sa.Column("batch_id", sa.Integer(), sa.ForeignKey("batches.id"), nullable=False),
            sa.Column("quantity", sa.Integer(), nullable=False),
            sa.Column("unit_price", sa.Float(), nullable=False),
            sa.Column("total_price", sa.Float(), nullable=False),
        )

    if "stock_movements" not in tables:
        op.create_table(
            "stock_movements",
            sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
            sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
            sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
            sa.Column("medicine_id", sa.Integer(), sa.ForeignKey("medicines.id"), nullable=False),
            sa.Column("batch_id", sa.Integer(), sa.ForeignKey("batches.id"), nullable=True),
            sa.Column("pricing_id", sa.Integer(), sa.ForeignKey("medicine_pricing.id"), nullable=True),
            sa.Column("type", sa.String(length=30), nullable=False),
            sa.Column("quantite", sa.Integer(), nullable=False),
            sa.Column("motif", sa.String(length=200), nullable=True),
            sa.Column("reference", sa.String(length=100), nullable=True),
            sa.Column("date_mouvement", sa.DateTime(), nullable=False),
        )
        op.create_index("ix_stock_movements_medicine_id", "stock_movements", ["medicine_id"])
        op.create_index("ix_stock_movements_type", "stock_movements", ["type"])
        op.create_index("ix_stock_movements_reference", "stock_movements", ["reference"])

    if "medicine_pricing" in _table_names(bind):
        _add_column_if_missing(bind, "medicine_pricing", sa.Column("achat_boite", sa.Float(), nullable=False, server_default="0"))
        _add_column_if_missing(bind, "medicine_pricing", sa.Column("achat_plaquette", sa.Float(), nullable=False, server_default="0"))
        _add_column_if_missing(bind, "medicine_pricing", sa.Column("achat_comprime", sa.Float(), nullable=False, server_default="0"))
        _add_column_if_missing(bind, "medicine_pricing", sa.Column("seuil_niveau", sa.String(length=20), nullable=False, server_default="comprimes"))
        _add_column_if_missing(bind, "medicine_pricing", sa.Column("alerte_jours", sa.Integer(), nullable=True, server_default="30"))

    if "pos_sales" in _table_names(bind):
        _add_column_if_missing(bind, "pos_sales", sa.Column("customer_name", sa.String(length=200), nullable=True))


def downgrade():
    # Non-destructive downgrade: installed pharmacies may already depend on
    # these tables. Rollback should be handled with a backup-specific script.
    pass

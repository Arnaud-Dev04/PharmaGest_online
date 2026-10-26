"""Add OBR EBMS fiscal and tax fields to medicines, customers, pharmacies, and sales.

Revision ID: 20261026_obr_ebms_fiscal_fields
Revises: 20261026_user_profile_and_pharmacy_license
Create Date: 2026-10-26
"""

from alembic import op
import sqlalchemy as sa


revision = "20261026_obr_ebms_fiscal_fields"
down_revision = "20261026_user_profile_and_pharmacy_license"
branch_labels = None
depends_on = None


def _table_exists(bind, table_name: str) -> bool:
    return table_name in sa.inspect(bind).get_table_names()


def _column_exists(bind, table_name: str, column_name: str) -> bool:
    if not _table_exists(bind, table_name):
        return False
    return any(
        col["name"] == column_name for col in sa.inspect(bind).get_columns(table_name)
    )


def upgrade():
    bind = op.get_bind()

    # 1. Medicines
    if _table_exists(bind, "medicines"):
        if not _column_exists(bind, "medicines", "tax_rate"):
            op.add_column("medicines", sa.Column("tax_rate", sa.Float(), nullable=False, server_default="0.0"))
        if not _column_exists(bind, "medicines", "tax_category"):
            op.add_column("medicines", sa.Column("tax_category", sa.String(20), nullable=False, server_default="exempt"))
        if not _column_exists(bind, "medicines", "item_ct"):
            op.add_column("medicines", sa.Column("item_ct", sa.Float(), nullable=False, server_default="0.0"))
        if not _column_exists(bind, "medicines", "item_tl"):
            op.add_column("medicines", sa.Column("item_tl", sa.Float(), nullable=False, server_default="0.0"))

    # 2. Customers
    if _table_exists(bind, "customers"):
        if not _column_exists(bind, "customers", "customer_nif"):
            op.add_column("customers", sa.Column("customer_nif", sa.String(50), nullable=True))
        if not _column_exists(bind, "customers", "customer_tax_center"):
            op.add_column("customers", sa.Column("customer_tax_center", sa.String(50), nullable=True))

    # 3. Pharmacies
    if _table_exists(bind, "pharmacies"):
        if not _column_exists(bind, "pharmacies", "nif"):
            op.add_column("pharmacies", sa.Column("nif", sa.String(50), nullable=True))
        if not _column_exists(bind, "pharmacies", "rc_number"):
            op.add_column("pharmacies", sa.Column("rc_number", sa.String(100), nullable=True))
        if not _column_exists(bind, "pharmacies", "tax_center"):
            op.add_column("pharmacies", sa.Column("tax_center", sa.String(50), nullable=True))
        if not _column_exists(bind, "pharmacies", "obr_enabled"):
            op.add_column("pharmacies", sa.Column("obr_enabled", sa.Boolean(), nullable=False, server_default="0"))
        if not _column_exists(bind, "pharmacies", "obr_environment"):
            op.add_column("pharmacies", sa.Column("obr_environment", sa.String(20), nullable=False, server_default="sandbox"))
        if not _column_exists(bind, "pharmacies", "obr_system_id"):
            op.add_column("pharmacies", sa.Column("obr_system_id", sa.String(100), nullable=True))
        if not _column_exists(bind, "pharmacies", "obr_api_username"):
            op.add_column("pharmacies", sa.Column("obr_api_username", sa.String(100), nullable=True))
        if not _column_exists(bind, "pharmacies", "obr_api_password"):
            op.add_column("pharmacies", sa.Column("obr_api_password", sa.String(255), nullable=True))

    # 4. Sales & POS Sales
    for table in ["sales", "pos_sales"]:
        if _table_exists(bind, table):
            if not _column_exists(bind, table, "obr_invoice_number"):
                op.add_column(table, sa.Column("obr_invoice_number", sa.String(100), nullable=True))
            if not _column_exists(bind, table, "obr_signature"):
                op.add_column(table, sa.Column("obr_signature", sa.String(255), nullable=True))
            if not _column_exists(bind, table, "obr_electronic_signature"):
                op.add_column(table, sa.Column("obr_electronic_signature", sa.String(500), nullable=True))
            if not _column_exists(bind, table, "obr_qr_code"):
                op.add_column(table, sa.Column("obr_qr_code", sa.String(500), nullable=True))
            if not _column_exists(bind, table, "obr_sync_status"):
                op.add_column(table, sa.Column("obr_sync_status", sa.String(20), nullable=False, server_default="local_only"))
            if not _column_exists(bind, table, "obr_synced_at"):
                op.add_column(table, sa.Column("obr_synced_at", sa.DateTime(), nullable=True))
            if not _column_exists(bind, table, "obr_error_message"):
                op.add_column(table, sa.Column("obr_error_message", sa.String(500), nullable=True))

    # 5. Sale Items & POS Sale Items
    for item_table in ["sale_items", "pos_sale_items"]:
        if _table_exists(bind, item_table):
            if not _column_exists(bind, item_table, "tax_rate"):
                op.add_column(item_table, sa.Column("tax_rate", sa.Float(), nullable=False, server_default="0.0"))
            if not _column_exists(bind, item_table, "tax_amount"):
                op.add_column(item_table, sa.Column("tax_amount", sa.Float(), nullable=False, server_default="0.0"))
            if not _column_exists(bind, item_table, "price_nvat"):
                op.add_column(item_table, sa.Column("price_nvat", sa.Float(), nullable=False, server_default="0.0"))
            if not _column_exists(bind, item_table, "price_wvat"):
                op.add_column(item_table, sa.Column("price_wvat", sa.Float(), nullable=False, server_default="0.0"))


def downgrade():
    pass

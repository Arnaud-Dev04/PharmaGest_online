"""Add user profile fields and pharmacy license fields.

Revision ID: 20261026_user_profile_and_pharmacy_license
Revises: 20261022_concurrency_composite_indexes
Create Date: 2026-10-26
"""

from alembic import op
import sqlalchemy as sa


revision = "20261026_user_profile_and_pharmacy_license"
down_revision = "20261022_concurrency_composite_indexes"
branch_labels = None
depends_on = None


def _table_exists(bind, table_name: str) -> bool:
    return table_name in sa.inspect(bind).get_table_names()


def _column_exists(bind, table_name: str, column_name: str) -> bool:
    if not _table_exists(bind, table_name):
        return False
    return any(
        column["name"] == column_name
        for column in sa.inspect(bind).get_columns(table_name)
    )


def upgrade():
    bind = op.get_bind()

    # 1. User profile fields
    if _table_exists(bind, "users"):
        with op.batch_alter_table("users") as batch_op:
            if not _column_exists(bind, "users", "first_name"):
                batch_op.add_column(sa.Column("first_name", sa.String(60), nullable=True))
            if not _column_exists(bind, "users", "last_name"):
                batch_op.add_column(sa.Column("last_name", sa.String(60), nullable=True))
            if not _column_exists(bind, "users", "email"):
                batch_op.add_column(sa.Column("email", sa.String(120), nullable=True))
            if not _column_exists(bind, "users", "phone"):
                batch_op.add_column(sa.Column("phone", sa.String(30), nullable=True))

    # 2. Pharmacy license and notes fields
    if _table_exists(bind, "pharmacies"):
        with op.batch_alter_table("pharmacies") as batch_op:
            if not _column_exists(bind, "pharmacies", "license_expires_at"):
                batch_op.add_column(sa.Column("license_expires_at", sa.Date(), nullable=True))
            if not _column_exists(bind, "pharmacies", "license_is_trial"):
                batch_op.add_column(sa.Column("license_is_trial", sa.Boolean(), server_default=sa.text("0"), nullable=False))
            if not _column_exists(bind, "pharmacies", "notes"):
                batch_op.add_column(sa.Column("notes", sa.String(500), nullable=True))


def downgrade():
    bind = op.get_bind()

    if _table_exists(bind, "users"):
        with op.batch_alter_table("users") as batch_op:
            for col in ["first_name", "last_name", "email", "phone"]:
                if _column_exists(bind, "users", col):
                    batch_op.drop_column(col)

    if _table_exists(bind, "pharmacies"):
        with op.batch_alter_table("pharmacies") as batch_op:
            for col in ["license_expires_at", "license_is_trial", "notes"]:
                if _column_exists(bind, "pharmacies", col):
                    batch_op.drop_column(col)

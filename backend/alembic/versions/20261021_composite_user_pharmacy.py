"""Make user username unique per pharmacy tenant.

Revision ID: 20261021_composite_user_pharmacy
Revises: 20261019_create_cash_register
Create Date: 2026-10-21
"""

from alembic import op
import sqlalchemy as sa


revision = "20261021_composite_user_pharmacy"
down_revision = "20261019_create_cash_register"
branch_labels = None
depends_on = None


def _table_exists(bind, table_name: str) -> bool:
    return table_name in sa.inspect(bind).get_table_names()


def upgrade():
    bind = op.get_bind()
    if not _table_exists(bind, "users"):
        return

    inspector = sa.inspect(bind)
    existing_uqs = inspector.get_unique_constraints("users")
    existing_indexes = inspector.get_indexes("users")

    # Drop existing unique constraint or index that is solely on 'username'
    uqs_to_drop = [
        uq["name"] for uq in existing_uqs
        if uq.get("column_names") == ["username"] and uq.get("name")
    ]
    indexes_to_drop = [
        idx["name"] for idx in existing_indexes
        if idx.get("column_names") == ["username"] and idx.get("unique") and idx.get("name")
    ]

    has_composite_uq = any(
        uq.get("name") == "uq_users_pharmacy_username" or
        set(uq.get("column_names") or []) == {"pharmacy_id", "username"}
        for uq in existing_uqs
    )

    with op.batch_alter_table("users") as batch_op:
        for uq_name in uqs_to_drop:
            batch_op.drop_constraint(uq_name, type_="unique")
        for idx_name in indexes_to_drop:
            batch_op.drop_index(idx_name)

        if not has_composite_uq:
            batch_op.create_unique_constraint(
                "uq_users_pharmacy_username",
                ["pharmacy_id", "username"]
            )


def downgrade():
    bind = op.get_bind()
    if not _table_exists(bind, "users"):
        return

    with op.batch_alter_table("users") as batch_op:
        try:
            batch_op.drop_constraint("uq_users_pharmacy_username", type_="unique")
        except Exception:
            pass
        batch_op.create_unique_constraint("uq_users_username", ["username"])

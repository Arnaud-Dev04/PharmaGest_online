"""Assign users to a pharmacy tenant.

Revision ID: 20261001_add_user_pharmacy_id
Revises: 20261001_create_pharmacies
Create Date: 2026-10-01
"""

from alembic import op
import sqlalchemy as sa


revision = "20261001_add_user_pharmacy_id"
down_revision = "20261001_create_pharmacies"
branch_labels = None
depends_on = None


def _table_exists(bind, table_name):
    return table_name in sa.inspect(bind).get_table_names()


def _column_exists(bind, table_name, column_name):
    return any(
        column["name"] == column_name
        for column in sa.inspect(bind).get_columns(table_name)
    )


def _index_exists(bind, table_name, index_name):
    return any(
        index["name"] == index_name
        for index in sa.inspect(bind).get_indexes(table_name)
    )


def _has_pharmacy_foreign_key(bind):
    return any(
        foreign_key["referred_table"] == "pharmacies"
        and "pharmacy_id" in foreign_key["constrained_columns"]
        for foreign_key in sa.inspect(bind).get_foreign_keys("users")
    )


def upgrade():
    bind = op.get_bind()
    if not _table_exists(bind, "users"):
        return

    if not _column_exists(bind, "users", "pharmacy_id"):
        with op.batch_alter_table("users") as batch_op:
            batch_op.add_column(sa.Column("pharmacy_id", sa.Integer(), nullable=True))
            batch_op.create_foreign_key(
                "fk_users_pharmacy_id_pharmacies",
                "pharmacies",
                ["pharmacy_id"],
                ["id"],
            )
    elif not _has_pharmacy_foreign_key(bind):
        with op.batch_alter_table("users") as batch_op:
            batch_op.create_foreign_key(
                "fk_users_pharmacy_id_pharmacies",
                "pharmacies",
                ["pharmacy_id"],
                ["id"],
            )

    if not _index_exists(bind, "users", "ix_users_pharmacy_id"):
        op.create_index("ix_users_pharmacy_id", "users", ["pharmacy_id"])

    pharmacies = sa.table(
        "pharmacies",
        sa.column("id", sa.Integer()),
        sa.column("code", sa.String(length=50)),
    )
    legacy_pharmacy_id = bind.execute(
        sa.select(pharmacies.c.id).where(pharmacies.c.code == "LEGACY-DEFAULT")
    ).scalar_one_or_none()

    if legacy_pharmacy_id is None:
        raise RuntimeError("LEGACY-DEFAULT pharmacy is required before assigning users")

    users = sa.table(
        "users",
        sa.column("pharmacy_id", sa.Integer()),
    )
    bind.execute(
        users.update()
        .where(users.c.pharmacy_id.is_(None))
        .values(pharmacy_id=legacy_pharmacy_id)
    )


def downgrade():
    # Keep user-to-pharmacy assignments intact; use a backup-aware rollback instead.
    pass
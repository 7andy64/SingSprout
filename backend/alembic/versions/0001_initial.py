"""initial: share_links + replies

Revision ID: 0001_initial
Revises:
Create Date: 2026-07-28

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = "0001_initial"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "share_links",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("card_id", sa.String(64), nullable=False),
        sa.Column("short_code", sa.String(16), nullable=False),
        sa.Column("device_id", sa.String(64), nullable=False),
        sa.Column("audio_oss_key", sa.String(256), nullable=False),
        sa.Column("cover_oss_key", sa.String(256), nullable=True),
        sa.Column("text_content", sa.Text(), nullable=True),
        sa.Column("share_url", sa.String(512), nullable=False),
        sa.Column("access_token", sa.String(512), nullable=False),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("view_count", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
    )
    op.create_index("ix_share_links_card_id", "share_links", ["card_id"], unique=True)
    op.create_index("ix_share_links_short_code", "share_links", ["short_code"], unique=True)
    op.create_index("ix_share_links_device_id", "share_links", ["device_id"])
    op.create_unique_constraint("uq_share_links_share_url", "share_links", ["share_url"])

    op.create_table(
        "replies",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("share_link_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("device_id", sa.String(64), nullable=False),
        sa.Column("reply_audio_oss_key", sa.String(256), nullable=True),
        sa.Column("reply_text", sa.Text(), nullable=True),
        sa.Column("reply_type", sa.String(16), nullable=False),
        sa.Column("status", sa.String(16), nullable=False, server_default="ready"),
        sa.Column("is_synced", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
    )
    op.create_index("ix_replies_share_link_id", "replies", ["share_link_id"])
    op.create_index("ix_replies_device_id", "replies", ["device_id"])
    op.create_index("ix_replies_status", "replies", ["status"])


def downgrade() -> None:
    op.drop_table("replies")
    op.drop_table("share_links")

"""add tts task fields to replies

Revision ID: 0002_tts_tasks
Revises: 0001_initial
Create Date: 2026-07-28

"""
from alembic import op
import sqlalchemy as sa

revision = "0002_tts_tasks"
down_revision = "0001_initial"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("replies", sa.Column("task_id", sa.String(32), nullable=True))
    op.add_column("replies", sa.Column("task_error", sa.Text(), nullable=True))
    op.create_index("ix_replies_task_id", "replies", ["task_id"], unique=True)


def downgrade() -> None:
    op.drop_index("ix_replies_task_id", "replies")
    op.drop_column("replies", "task_error")
    op.drop_column("replies", "task_id")

"""
SyncLog model for tracking synchronization events.
"""

from sqlalchemy import Column, String, Text, DateTime, Enum as SQLEnum
from app.database import Base
from app.models.base import BaseModelMixin
from datetime import datetime
import enum


class SyncLogStatus(str, enum.Enum):
    """Sync log status enumeration."""
    SUCCESS = "success"
    FAILURE = "failure"
    PENDING = "pending"


class SyncLog(Base, BaseModelMixin):
    """
    Sync log model for debugging synchronization.
    
    Tracks all sync attempts between local (SQLite) and remote (MySQL) databases.
    
    Attributes:
        timestamp: When the sync attempt occurred
        status: Sync result (success/failure/pending)
        message: Detailed message or error description
    """
    __tablename__ = "sync_logs"
    
    timestamp = Column(DateTime, default=datetime.utcnow, nullable=False, index=True)
    status = Column(SQLEnum(SyncLogStatus), nullable=False)
    message = Column(Text, nullable=True)
    
    def __repr__(self):
        return f"<SyncLog(id={self.id}, timestamp={self.timestamp}, status='{self.status}')>"

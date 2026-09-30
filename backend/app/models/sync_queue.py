"""
Sync Queue Model.
Stores actions performed offline for later synchronization.
"""

from sqlalchemy import Column, Integer, String, JSON, DateTime, Enum
from sqlalchemy.sql import func
import enum

from app.database import Base

class SyncAction(str, enum.Enum):
    CREATE = "CREATE"
    UPDATE = "UPDATE"
    DELETE = "DELETE"

class SyncStatus(str, enum.Enum):
    PENDING = "PENDING"
    DONE = "DONE"
    ERROR = "ERROR"

class SyncQueue(Base):
    __tablename__ = "sync_queue"

    id = Column(Integer, primary_key=True, index=True)
    action = Column(Enum(SyncAction), nullable=False)
    table_name = Column(String(50), nullable=False)
    data = Column(JSON, nullable=False) # Stores the payload (e.g., Sale data)
    
    status = Column(Enum(SyncStatus), default=SyncStatus.PENDING)
    error_message = Column(String(255), nullable=True)
    retry_count = Column(Integer, default=0)
    
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    def __repr__(self):
        return f"<SyncQueue(id={self.id}, action='{self.action}', table='{self.table_name}', status='{self.status}')>"

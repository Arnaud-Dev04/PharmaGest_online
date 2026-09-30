"""
Models package initialization.
Imports all models for easy access and ensures they are registered with SQLAlchemy Base.
"""

from app.models.base import BaseModelMixin, TimestampMixin
from app.models.user import User, UserRole
from app.models.medicine import Medicine, MedicineFamily, MedicineType
from app.models.supplier import Supplier
from app.models.customer import Customer
from app.models.sales import Sale, SaleItem, PaymentMethod, SyncStatus
from app.models.restock import RestockOrder, RestockItem, RestockStatus
from app.models.settings import Settings
from app.models.sync_log import SyncLog, SyncLogStatus
from app.models.sync_queue import SyncQueue
from app.models.batch import Batch
from app.models.pos_sale import POSSale, POSSaleItem
from app.models.stock_movement import StockMovement
from app.models.medicine_pricing import MedicinePricing
from app.models.audit_log import DeletionLog

__all__ = [
    # Audit
    "DeletionLog",
    # Base
    "BaseModelMixin",
    "TimestampMixin",
    
    # User
    "User",
    "UserRole",
    
    # Medicine
    "Medicine",
    "MedicineFamily",
    "MedicineType",
    
    # Supplier
    "Supplier",
    
    # Customer
    "Customer",
    
    # Sales
    "Sale",
    "SaleItem",
    "PaymentMethod",
    "SyncStatus",
    
    # Restock
    "RestockOrder",
    "RestockItem",
    "RestockStatus",
    
    # Settings
    "Settings",
    
    # Sync
    "SyncLog",
    "SyncLogStatus",
    "SyncQueue",
    
    # Batch / POS
    "Batch",
    "POSSale",
    "POSSaleItem",
    
    # Stock Movement
    "StockMovement",
    
    # Medicine Pricing
    "MedicinePricing",
]


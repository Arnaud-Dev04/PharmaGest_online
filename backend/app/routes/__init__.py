"""Routes package."""

from .auth import router as auth_router
from .stock import router as stock_router
from .config import router as config_router
from .suppliers import router as suppliers_router
from .sales import router as sales_router
from .dashboard import router as dashboard_router
from .reports import router as reports_router
from .settings import router as settings_router
from .admin import router as admin_router
from .maintenance import router as maintenance_router
from .users import router as users_router
from .customers import router as customers_router
from .license import router as license_router
from .medicine_pricing import router as medicine_pricing_router
from .pos import router as pos_router
from .sync import router as sync_router
from .platform_admin import router as platform_admin_router
from .cash_register import router as cash_register_router
from .customer_credits import router as customer_credits_router
from .search import router as search_router
from .accounting import router as accounting_router
from .restock import router as restock_router
from .obr import router as obr_router

__all__ = [
    "auth_router",
    "stock_router",
    "config_router",
    "suppliers_router",
    "sales_router",
    "dashboard_router",
    "reports_router",
    "settings_router",
    "admin_router",
    "maintenance_router",
    "users_router",
    "customers_router",
    "license_router",
    "medicine_pricing_router",
    "pos_router",
    "sync_router",
    "platform_admin_router",
    "cash_register_router",
    "customer_credits_router",
    "search_router",
    "accounting_router",
    "restock_router",
    "obr_router",
]

"""Schemas package."""

from .auth import (
    Token,
    TokenData,
    UserLogin,
    UserCreate,
    UserResponse
)
from .common import (
    PaginationParams,
    PaginatedResponse
)
from .medicine import (
    MedicineFamilyCreate,
    MedicineFamilyUpdate,
    MedicineFamilyResponse,
    MedicineTypeCreate,
    MedicineTypeUpdate,
    MedicineTypeResponse,
    MedicineCreate,
    MedicineUpdate,
    MedicineResponse,
    MedicineFilter,
    StockAlertsResponse
)
from .supplier import (
    SupplierCreate,
    SupplierUpdate,
    SupplierResponse
)
from .customer import (
    CustomerCreate,
    CustomerUpdate,
    CustomerResponse
)
from .sales import (
    SaleItemCreate,
    SaleItemResponse,
    SaleCreate,
    SaleResponse
)
from .dashboard import (
    DashboardStatsResponse,
    RevenueChartData,
    SalesHistoryFilter
)

__all__ = [
    # Auth
    "Token",
    "TokenData",
    "UserLogin",
    "UserCreate",
    "UserResponse",
    
    # Common
    "PaginationParams",
    "PaginatedResponse",
    
    # Medicine
    "MedicineFamilyCreate",
    "MedicineFamilyUpdate",
    "MedicineFamilyResponse",
    "MedicineTypeCreate",
    "MedicineTypeUpdate",
    "MedicineTypeResponse",
    "MedicineCreate",
    "MedicineUpdate",
    "MedicineResponse",
    "MedicineFilter",
    "StockAlertsResponse",
    
    # Supplier
    "SupplierCreate",
    "SupplierUpdate",
    "SupplierResponse",
    
    # Customer
    "CustomerCreate",
    "CustomerUpdate",
    "CustomerResponse",
    
    # Sales
    "SaleItemCreate",
    "SaleItemResponse",
    "SaleCreate",
    "SaleResponse",
    
    # Dashboard
    "DashboardStatsResponse",
    "RevenueChartData",
    "SalesHistoryFilter",
]

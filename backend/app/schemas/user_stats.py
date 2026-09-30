"""
User statistics schemas for performance tracking.
"""

from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime


class TopProductSold(BaseModel):
    """Top product sold by a user."""
    medicine_id: int
    medicine_name: str
    medicine_code: str
    quantity_sold: int
    revenue_generated: float


class UserSalesStats(BaseModel):
    """Sales statistics for a specific user."""
    user_id: int
    username: str
    total_sales: int
    total_revenue: float
    average_sale_amount: float
    customers_served: int
    top_products: List[TopProductSold]
    sales_by_date: List[dict]  # For chart data


class UserPerformance(BaseModel):
    """User performance comparison."""
    user_id: int
    username: str
    role: str
    is_active: bool
    total_sales: int
    total_revenue: float
    average_sale_amount: float
    rank: Optional[int] = None


class UserStatusUpdate(BaseModel):
    """Schema for updating user status."""
    is_active: bool


class SalesStatsFilter(BaseModel):
    """Filter for sales statistics queries."""
    start_date: Optional[datetime] = None
    end_date: Optional[datetime] = None

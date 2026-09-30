"""
Dashboard schemas - Data structures for dashboard statistics and charts.
"""

from pydantic import BaseModel, Field
from typing import List, Optional
from datetime import date


class RevenueChartData(BaseModel):
    """Schema for revenue chart data point."""
    date: str = Field(..., description="Date in YYYY-MM-DD format")
    amount: float = Field(..., description="Total revenue for this date")


class SalesByDay(BaseModel):
    """Schema for sales by day of week."""
    day: str = Field(..., description="Day name (e.g., Monday)")
    amount: float = Field(..., description="Total sales for this day")


class SalesByHour(BaseModel):
    """Schema for sales by hour of day."""
    hour: int = Field(..., description="Hour of day (0-23)")
    amount: float = Field(..., description="Total sales for this hour")


class DashboardStatsResponse(BaseModel):
    """
    Dashboard statistics response schema.
    """
    total_medicines: int
    total_sales_count: int = 0
    weekly_sales: float
    total_suppliers: int = 0
    total_revenue: float
    cancelled_sales: int = 0
    recent_sales: List[dict] = []
    expiring_soon: List[dict] = []
    expiring_soon_count: int = 0
    revenue_chart: List[RevenueChartData] = Field(..., description="Daily revenue for the last 7 days")
    sales_by_day: List[SalesByDay] = Field(default=[], description="Sales aggregated by day of week")
    sales_by_hour: List[SalesByHour] = Field(default=[], description="Sales aggregated by hour of day")
    expired_medicines: int = Field(..., description="Count of expired medicines")
    low_stock_medicines: int = Field(..., description="Count of medicines with low stock")
    low_stock_list: List[dict] = Field(default=[], description="Detailed list of low stock medicines")
    total_purchase_value: float = Field(0.0, description="Total purchase value of current inventory")
    total_sell_value: float = Field(0.0, description="Total sell value of current inventory")


class SalesHistoryFilter(BaseModel):
    """Schema for filtering sales history."""
    start_date: Optional[date] = None
    end_date: Optional[date] = None
    user_id: Optional[int] = None
    min_amount: Optional[float] = None
    max_amount: Optional[float] = None

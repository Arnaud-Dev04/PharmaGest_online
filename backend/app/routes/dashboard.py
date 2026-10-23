"""
Dashboard routes - Endpoints for system statistics and analytics.
"""

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.database import get_local_db
from app.models.user import User
from app.auth.dependencies import get_current_active_user
from app.core.license_guard import require_feature
from app.schemas.dashboard import DashboardStatsResponse
from app.services import dashboard_service

# Create router
router = APIRouter()


from app.core.distributed_cache import get_cache, set_cache, tenant_key

_STATS_CACHE_TTL = 30  # secondes


@router.get(
    "/stats",
    response_model=DashboardStatsResponse,
    summary="Get dashboard statistics"
)
def get_dashboard_stats(
    days: int = 7,
    start_date: str = None,
    end_date: str = None,
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_local_db)
):
    """
    Get key metrics for the dashboard.
    Mis en cache pendant 30s avec isolation tenant.
    """
    cache_k = tenant_key(current_user.pharmacy_id, "dashboard", f"stats_{days}_{start_date}_{end_date}")
    cached = get_cache(cache_k)
    if cached is not None:
        return cached

    stats = dashboard_service.get_stats(db, start_date=start_date, end_date=end_date)
    set_cache(cache_k, stats, ttl_seconds=_STATS_CACHE_TTL)
    return stats


@router.get(
    "/cancelled-sales",
    summary="Get detailed cancelled sales",
    dependencies=[Depends(require_feature("sales_reports"))],
)
def get_cancelled_sales(
    limit: int = 50,
    start_date: str = None,
    end_date: str = None,
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_local_db)
):
    """
    Get list of cancelled sales with user details (who cancelled it).
    """
    return dashboard_service.get_cancelled_sales_details(
        db, 
        limit=limit,
        start_date=start_date,
        end_date=end_date
    )


"""
Dashboard routes - Endpoints for system statistics and analytics.
"""

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.database import get_local_db
from app.models.user import User
from app.auth.dependencies import get_current_active_user
from app.schemas.dashboard import DashboardStatsResponse
from app.services import dashboard_service

# Create router
router = APIRouter()


import time

_stats_cache: dict = {}
_STATS_CACHE_TTL = 30  # secondes


@router.get(
    "/stats",
    response_model=DashboardStatsResponse,
    summary="Get dashboard statistics"
)
async def get_dashboard_stats(
    days: int = 7,
    start_date: str = None,
    end_date: str = None,
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_local_db)
):
    """
    Get key metrics for the dashboard.
    Mis en cache pendant 30s pour éviter de relancer 15+ requêtes Aiven
    à chaque clic d'onglet ou retour sur l'accueil.
    """
    cache_key = f"{days}_{start_date}_{end_date}"
    now = time.time()
    if cache_key in _stats_cache and (now - _stats_cache[cache_key]["ts"]) < _STATS_CACHE_TTL:
        return _stats_cache[cache_key]["data"]

    stats = dashboard_service.get_stats(db, start_date=start_date, end_date=end_date)
    _stats_cache[cache_key] = {"data": stats, "ts": now}
    return stats


@router.get(
    "/cancelled-sales",
    summary="Get detailed cancelled sales"
)
async def get_cancelled_sales(
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


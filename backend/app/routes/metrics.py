"""
Protected test route to verify authentication.
"""

from fastapi import APIRouter, Depends
from datetime import datetime

from app.models.user import User
from app.auth.dependencies import get_current_active_user

# Create router
router = APIRouter()


@router.get(
    "/metrics",
    summary="Protected test endpoint",
    description="Test endpoint to verify authentication is working correctly"
)
async def get_metrics(
    current_user: User = Depends(get_current_active_user)
):
    """
    Protected metrics endpoint - requires authentication.
    
    Returns basic information about the authenticated user and system status.
    
    Returns:
        dict: Metrics and user information
        
    Raises:
        HTTPException 401: If not authenticated
    """
    return {
        "message": "Access granted to protected route",
        "user": {
            "username": current_user.username,
            "role": current_user.role.value,
            "is_active": current_user.is_active
        },
        "timestamp": datetime.utcnow().isoformat(),
        "status": "authenticated"
    }

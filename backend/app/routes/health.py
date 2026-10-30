"""
Health check endpoint — vérifie l'état de l'instance et de la connexion DB.
"""
from fastapi import APIRouter
from app.database import check_database_connection
import os

router = APIRouter()

@router.get("/health", tags=["Health"])
def health_check():
    """Vérifie que l'instance API et la base de données sont opérationnelles."""
    db_ok = check_database_connection()
    return {
        "status": "ok" if db_ok else "degraded",
        "instance": os.getenv("INSTANCE_NAME", "unknown"),
        "db": "connected" if db_ok else "unreachable",
    }

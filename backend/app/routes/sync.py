"""
Routes de synchronisation cloud -- Local SQLite <-> MySQL (cloud).

Endpoints :
  POST /sync/push    -> Pousse les ventes locales vers la DB MySQL remote
  GET  /sync/pull    -> Recupere les mises a jour depuis la DB MySQL remote
  GET  /sync/status  -> Etat de la synchronisation (nb en attente)
"""

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
import logging

from app.database import get_local_db
from app.models.user import User
from app.auth.dependencies import get_current_active_user
from app.sync.sync_manager import SyncManager

router = APIRouter()
logger = logging.getLogger("sync_routes")


@router.post("/push", summary="Pousser les ventes locales vers la DB MySQL remote")
async def sync_push(
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_local_db),
):
    """
    Synchronise les ventes POS locales non-envoyees vers la DB MySQL remote.

    - Lit les POSSale avec sync_status = 'pending' ou 'local_only'
    - Les insere dans la DB remote (upsert par UUID)
    - Met a jour sync_status = 'synced' si succes

    Retourne un rapport : { synced, errors, online }
    """
    try:
        report = SyncManager.sync_up(local_db=db)
        return {
            "success": True,
            "message": f"{report['synced']} vente(s) synchronisee(s)",
            **report,
        }
    except Exception as e:
        logger.error(f"[/sync/push] Erreur: {e}")
        return {"success": False, "error": str(e), "synced": 0, "online": False}


@router.get("/pull", summary="Recuperer les mises a jour depuis la DB MySQL remote")
async def sync_pull(
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_local_db),
):
    """
    Recupere les parametres et medicaments depuis la DB MySQL remote vers la base locale.

    Utile apres une installation fraiche ou pour synchroniser les
    parametres de la pharmacie modifies depuis un autre poste.
    """
    try:
        report = SyncManager.sync_down(local_db=db)
        return {
            "success": True,
            "message": f"{report.get('settings_updated', 0)} parametre(s) mis a jour",
            **report,
        }
    except Exception as e:
        logger.error(f"[/sync/pull] Erreur: {e}")
        return {"success": False, "error": str(e), "online": False}


@router.get("/status", summary="Etat de la synchronisation")
async def sync_status(
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_local_db),
):
    """
    Retourne l'etat actuel de la synchronisation :
    - online : DB MySQL remote accessible ?
    - pending_count : ventes en attente d'envoi
    - error_count : ventes en erreur
    - synced_count : ventes deja synchronisees
    """
    try:
        return SyncManager.get_status(local_db=db)
    except Exception as e:
        logger.error(f"[/sync/status] Erreur: {e}")
        return {"online": False, "error": str(e)}

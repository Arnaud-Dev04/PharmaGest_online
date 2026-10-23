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
from app.core.license_guard import require_feature
from app.sync.sync_manager import SyncManager

router = APIRouter()
logger = logging.getLogger("sync_routes")


@router.post(
    "/push",
    summary="Pousser les ventes locales vers la DB MySQL remote",
    dependencies=[Depends(require_feature("cloud_sync"))],
)
def sync_push(
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


from app.schemas.sync import SyncBatchUpRequest, SyncBatchUpResponse

@router.post(
    "/batch-up",
    response_model=SyncBatchUpResponse,
    summary="Envoi groupé de ventes POS vers le cloud (batch upload)",
    dependencies=[Depends(require_feature("cloud_sync"))],
)
@router.post(
    "/batch-push",
    response_model=SyncBatchUpResponse,
    summary="Alias d'envoi groupé de ventes POS vers le cloud",
    dependencies=[Depends(require_feature("cloud_sync"))],
)
def batch_upload_sales(
    payload: SyncBatchUpRequest,
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_local_db),
):
    """
    Reçoit un lot de ventes POS (jusqu'à 100 ventes par requête).
    Traitement idempotent par sale_uuid :
    - Les ventes déjà existantes sont sautées sans erreur.
    - Les nouvelles ventes et leurs lignes sont insérées atomiquement.
    """
    return SyncManager.process_batch_upload(
        db=db,
        sales_payload=payload.sales,
        current_user=current_user,
    )


@router.get(
    "/pull",
    summary="Recuperer les mises a jour depuis la DB MySQL remote",
    dependencies=[Depends(require_feature("cloud_sync"))],
)
def sync_pull(
    force_full: bool = False,
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_local_db),
):
    """
    Recupere les parametres et medicaments depuis la DB MySQL remote vers la base locale.

    Par défaut incrémental (depuis le dernier timestamp de sync).
    Passer ?force_full=true pour forcer un rechargement complet.
    """
    try:
        report = SyncManager.sync_down(local_db=db, force_full=force_full)
        return {
            "success": True,
            "message": f"{report.get('settings_updated', 0)} parametre(s) mis a jour",
            **report,
        }
    except Exception as e:
        logger.error(f"[/sync/pull] Erreur: {e}")
        return {"success": False, "error": str(e), "online": False}


@router.get("/status", summary="Etat de la synchronisation")
def sync_status(
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

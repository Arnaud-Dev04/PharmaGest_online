"""
Sync Manager - Synchronisation offline-first SQLite <-> MySQL (cloud).

Logique :
  - sync_up()   : pousse les pos_sales locales non-synchronisees vers la DB MySQL remote
  - sync_down() : recupere les medicaments/parametres depuis la DB MySQL remote
  - Utilise les UUID des POSSale pour eviter les doublons
  - Resolution de conflits : Local wins (offline-first)
"""

from sqlalchemy.orm import Session
from sqlalchemy import text, func, case
import json
import logging
import time
from typing import Dict, Any, List
from datetime import datetime

from app.database import SessionRemote
from app.utils.network import is_online

logger = logging.getLogger(__name__)

# ── Cache pour _remote_available() et get_status() ───────────────────────────
# check_database_connection() ouvre une connexion TCP+SSL vers Aiven = 2-10s.
# On le cache 30s pour ne pas bloquer chaque requête.
_remote_cache: Dict[str, Any] = {}
_REMOTE_CACHE_TTL = 30        # secondes — vérification connectivité

_status_cache: Dict[str, Any] = {}
_STATUS_CACHE_TTL = 15        # secondes — statut complet (counts + online)


def _remote_available() -> bool:
    """Verifie si la DB MySQL remote est accessible — résultat caché 30s."""
    global _remote_cache
    now = time.time()
    if _remote_cache.get("ts") and now - _remote_cache["ts"] < _REMOTE_CACHE_TTL:
        return _remote_cache["result"]
    try:
        result = is_online(check_remote_db=True)
    except Exception:
        result = False
    _remote_cache = {"result": result, "ts": now}
    return result


class SyncManager:
    """
    Gere la synchronisation bidirectionnelle Local (SQLite) <-> Cloud (MySQL).
    """

    # ------------------------------------------------------------------
    # SYNC UP : Local -> MySQL remote
    # ------------------------------------------------------------------

    @staticmethod
    def sync_up(local_db: Session) -> Dict[str, Any]:
        """
        Pousse les ventes POS locales non-synchronisees vers la DB MySQL remote.
        Retourne un rapport avec le nombre de ventes synchronisees.
        """
        report = {"synced": 0, "errors": 0, "skipped": 0, "online": False}

        if not _remote_available():
            logger.warning("[SyncUp] DB MySQL remote non joignable -- skip.")
            return report

        report["online"] = True

        try:
            from app.models.pos_sale import POSSale, POSSaleItem
            from app.models.medicine import Medicine
            from app.models.user import User

            # Ventes locales non encore envoyees vers le cloud
            pending_sales = local_db.query(POSSale).filter(
                POSSale.sync_status.in_(["pending", "local_only"])
            ).order_by(POSSale.date.asc()).limit(100).all()

            if not pending_sales:
                logger.info("[SyncUp] Rien a synchroniser.")
                return report

            logger.info(f"[SyncUp] {len(pending_sales)} vente(s) a envoyer...")

            remote_db = SessionRemote()
            try:
                for sale in pending_sales:
                    try:
                        SyncManager._push_pos_sale(sale, remote_db)
                        # Marquer comme synchronisee
                        sale.sync_status = "synced"
                        sale.synced_at = datetime.utcnow()
                        local_db.commit()
                        report["synced"] += 1
                    except Exception as e:
                        logger.error(f"[SyncUp] Erreur vente {sale.sale_uuid}: {e}")
                        sale.sync_status = "error"
                        local_db.commit()
                        report["errors"] += 1
            finally:
                remote_db.close()

            # Invalider le cache de statut après une synchro
            global _status_cache
            _status_cache = {}

        except Exception as e:
            logger.error(f"[SyncUp] Erreur fatale: {e}")
            report["errors"] += 1

        logger.info(f"[SyncUp] Resultat: {report}")
        return report

    @staticmethod
    def _push_pos_sale(sale, remote_db: Session):
        """
        Insere ou met a jour une POSSale dans la DB MySQL remote (upsert par UUID).
        """
        from app.models.pos_sale import POSSale, POSSaleItem

        # Verifier si la vente existe deja dans la DB remote (par UUID)
        existing = remote_db.query(POSSale).filter(
            POSSale.sale_uuid == sale.sale_uuid
        ).first()

        if existing:
            logger.info(f"[SyncUp] Vente {sale.sale_uuid} deja presente en remote -- skip.")
            return

        # Creer la vente dans la DB remote
        remote_sale = POSSale(
            sale_uuid=sale.sale_uuid,
            code=sale.code,
            total_amount=sale.total_amount,
            status=sale.status,
            payment_method=sale.payment_method,
            date=sale.date,
            user_id=sale.user_id,
            customer_id=sale.customer_id,
            sync_status="synced",
            synced_at=datetime.utcnow(),
        )
        remote_db.add(remote_sale)
        remote_db.flush()

        # Creer les items associes
        for item in sale.items:
            remote_item = POSSaleItem(
                sale_id=remote_sale.id,
                medicine_id=item.medicine_id,
                quantity=item.quantity,
                unit_price=item.unit_price,
                total_price=item.total_price,
                sale_type=item.sale_type,
            )
            remote_db.add(remote_item)

        remote_db.commit()
        logger.info(f"[SyncUp] Vente {sale.sale_uuid} envoyee avec succes.")

    # ------------------------------------------------------------------
    # SYNC DOWN : MySQL remote -> Local
    # ------------------------------------------------------------------

    @staticmethod
    def sync_down(local_db: Session) -> Dict[str, Any]:
        """
        Recupere les parametres et medicaments depuis la DB MySQL remote vers la base locale.
        """
        report = {"online": False, "settings_updated": 0, "errors": 0}

        if not _remote_available():
            logger.warning("[SyncDown] DB MySQL remote non joignable -- skip.")
            return report

        report["online"] = True
        remote_db = SessionRemote()

        try:
            from app.models.settings import Settings

            # Recuperer les Settings depuis la DB remote
            remote_settings = remote_db.query(Settings).all()
            for rs in remote_settings:
                local_setting = local_db.query(Settings).filter(
                    Settings.key == rs.key
                ).first()
                if local_setting:
                    local_setting.value = rs.value
                else:
                    local_db.add(Settings(key=rs.key, value=rs.value))
            local_db.commit()
            report["settings_updated"] = len(remote_settings)

        except Exception as e:
            logger.warning(f"[SyncDown] Settings sync skipped: {e}")

        except Exception as e:
            logger.error(f"[SyncDown] Erreur fatale: {e}")
            report["errors"] += 1
        finally:
            remote_db.close()

        logger.info(f"[SyncDown] Resultat: {report}")
        return report

    # ------------------------------------------------------------------
    # STATUT — optimisé + cache
    # ------------------------------------------------------------------

    @staticmethod
    def get_status(local_db: Session) -> Dict[str, Any]:
        """
        Retourne l'etat de la synchronisation.

        Optimisations :
        - _remote_available() caché 30s (évite TCP+SSL vers Aiven à chaque appel)
        - Les 3 COUNT queries fusionnées en 1 seule query avec func.sum(case())
        - Résultat complet caché 15s
        """
        global _status_cache
        now = time.time()

        # Retourner le cache si encore valide
        if _status_cache.get("ts") and now - _status_cache["ts"] < _STATUS_CACHE_TTL:
            return _status_cache["data"]

        try:
            from app.models.pos_sale import POSSale

            # 1 seule query au lieu de 3 COUNT séparés
            row = local_db.query(
                func.sum(
                    case((POSSale.sync_status.in_(["pending", "local_only"]), 1), else_=0)
                ).label("pending"),
                func.sum(
                    case((POSSale.sync_status == "error", 1), else_=0)
                ).label("errored"),
                func.sum(
                    case((POSSale.sync_status == "synced", 1), else_=0)
                ).label("synced"),
            ).one()

            pending = int(row.pending or 0)
            errored = int(row.errored or 0)
            synced  = int(row.synced  or 0)

            # Vérif connectivité (cachée 30s dans _remote_available)
            online = _remote_available()

            result = {
                "online": online,
                "pending_count": pending,
                "error_count": errored,
                "synced_count": synced,
                "last_check": datetime.utcnow().isoformat(),
            }
        except Exception as e:
            result = {"online": False, "error": str(e)}

        _status_cache = {"data": result, "ts": now}
        return result

    # ------------------------------------------------------------------
    # QUEUE LEGACY (compatibilite avec l'ancien code)
    # ------------------------------------------------------------------

    @staticmethod
    def add_to_queue(db: Session, action, table_name: str, data: Dict[str, Any]):
        """Compatibilite legacy -- utiliser sync_up() a la place."""
        logger.info(f"[SyncQueue] Action {action} sur {table_name} -> sera traitee par sync_up()")

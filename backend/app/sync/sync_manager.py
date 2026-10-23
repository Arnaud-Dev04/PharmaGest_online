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
    def _configure_remote_scope(local_db: Session, remote_db: Session) -> int:
        """Map the local pharmacy to its remote row by stable pharmacy code."""
        from app.models.pharmacy import Pharmacy

        local_pharmacy_id = local_db.info.get("pharmacy_id")
        if (
            not local_db.info.get("pharmacy_scope_enabled")
            or local_db.info.get("is_platform_admin")
            or local_pharmacy_id is None
        ):
            raise ValueError("A pharmacy-scoped session is required for synchronization")

        local_pharmacy = local_db.query(Pharmacy).filter(
            Pharmacy.id == local_pharmacy_id
        ).first()
        if local_pharmacy is None or not local_pharmacy.is_active:
            raise ValueError("Local pharmacy is unavailable")

        remote_pharmacy = remote_db.query(Pharmacy).filter(
            Pharmacy.code == local_pharmacy.code
        ).first()
        if remote_pharmacy is None or not remote_pharmacy.is_active:
            raise ValueError("Matching active pharmacy is missing from the remote database")

        remote_db.info.update({
            "pharmacy_scope_enabled": True,
            "pharmacy_id": remote_pharmacy.id,
            "is_platform_admin": False,
        })
        return remote_pharmacy.id

    @staticmethod
    def _push_pos_sale(sale, remote_db: Session):
        """Insert a POS sale using remote IDs resolved inside its tenant."""
        from app.models.batch import Batch
        from app.models.cash_register import CashRegisterSession
        from app.models.customer import Customer
        from app.models.medicine import Medicine
        from app.models.pos_sale import POSSale, POSSaleItem
        from app.models.user import User

        remote_pharmacy_id = remote_db.info.get("pharmacy_id")
        if remote_pharmacy_id is None or not remote_db.info.get("pharmacy_scope_enabled"):
            raise ValueError("Remote pharmacy scope has not been configured")

        existing_pharmacy = remote_db.connection().execute(
            POSSale.__table__.select()
            .with_only_columns(POSSale.__table__.c.pharmacy_id)
            .where(POSSale.__table__.c.sale_uuid == sale.sale_uuid)
        ).scalar_one_or_none()
        if existing_pharmacy is not None:
            if existing_pharmacy != remote_pharmacy_id:
                raise ValueError("Sale UUID is already owned by another pharmacy")
            logger.info(f"[SyncUp] Vente {sale.sale_uuid} deja presente dans cette pharmacie.")
            return

        local_user = sale.user
        if local_user is None or local_user.pharmacy_id != sale.pharmacy_id:
            raise ValueError("Sale user is missing or belongs to another pharmacy")
        remote_user = remote_db.query(User).filter(
            User.username == local_user.username,
            User.pharmacy_id == remote_pharmacy_id,
        ).first()
        if remote_user is None:
            raise ValueError(f"Remote user '{local_user.username}' is missing")

        remote_cash_session_uuid = None
        if sale.payment_method == "cash" and sale.cash_session_uuid:
            remote_cash_session = remote_db.query(CashRegisterSession).filter(
                CashRegisterSession.session_uuid == sale.cash_session_uuid,
                CashRegisterSession.pharmacy_id == remote_pharmacy_id,
                CashRegisterSession.cashier_id == remote_user.id,
            ).first()
            if remote_cash_session is None or remote_cash_session.status != "open":
                raise ValueError("Open cashier session must sync before cash POS sales")
            remote_cash_session_uuid = remote_cash_session.session_uuid

        customer_id = None
        if sale.customer_id is not None:
            local_customer = sale.customer
            if local_customer is None or local_customer.pharmacy_id != sale.pharmacy_id:
                raise ValueError("Sale customer is missing or belongs to another pharmacy")
            remote_customer = remote_db.query(Customer).filter(
                Customer.phone == local_customer.phone,
                Customer.pharmacy_id == remote_pharmacy_id,
            ).first()
            if remote_customer is None:
                remote_customer = Customer(
                    first_name=local_customer.first_name,
                    last_name=local_customer.last_name,
                    phone=local_customer.phone,
                    total_points=local_customer.total_points,
                    pharmacy_id=remote_pharmacy_id,
                )
                remote_db.add(remote_customer)
                remote_db.flush()
            customer_id = remote_customer.id

        cancelled_by_id = None
        if sale.cancelled_by is not None:
            local_canceller = sale.cancelled_by_user
            if local_canceller is None or local_canceller.pharmacy_id != sale.pharmacy_id:
                raise ValueError("Sale cancellation user belongs to another pharmacy")
            remote_canceller = remote_db.query(User).filter(
                User.username == local_canceller.username,
                User.pharmacy_id == remote_pharmacy_id,
            ).first()
            if remote_canceller is None:
                raise ValueError(f"Remote user '{local_canceller.username}' is missing")
            cancelled_by_id = remote_canceller.id

        remote_items = []
        for item in sale.items:
            local_medicine = item.medicine
            if local_medicine is None or local_medicine.pharmacy_id != sale.pharmacy_id:
                raise ValueError("Sale medicine belongs to another pharmacy")
            remote_medicine = remote_db.query(Medicine).filter(
                Medicine.code == local_medicine.code,
                Medicine.pharmacy_id == remote_pharmacy_id,
            ).first()
            if remote_medicine is None:
                raise ValueError(f"Remote medicine '{local_medicine.code}' is missing")

            remote_batch_id = None
            if item.batch_id is not None:
                local_batch = item.batch
                if local_batch is None or local_batch.pharmacy_id != sale.pharmacy_id:
                    raise ValueError("Sale batch belongs to another pharmacy")
                remote_batch = remote_db.query(Batch).filter(
                    Batch.batch_number == local_batch.batch_number,
                    Batch.medicine_id == remote_medicine.id,
                    Batch.pharmacy_id == remote_pharmacy_id,
                ).first()
                if remote_batch is None:
                    raise ValueError(
                        f"Remote batch '{local_batch.batch_number}' is missing"
                    )
                remote_batch_id = remote_batch.id

            remote_items.append(POSSaleItem(
                pharmacy_id=remote_pharmacy_id,
                medicine_id=remote_medicine.id,
                batch_id=remote_batch_id,
                quantity=item.quantity,
                unit_price=item.unit_price,
                total_price=item.total_price,
                sale_type=item.sale_type,
                discount_percent=item.discount_percent,
            ))

        remote_sale = POSSale(
            sale_uuid=sale.sale_uuid,
            code=sale.code,
            pharmacy_id=remote_pharmacy_id,
            total_amount=sale.total_amount,
            status=sale.status,
            payment_method=sale.payment_method,
            date=sale.date,
            user_id=remote_user.id,
            customer_id=customer_id,
            customer_name=sale.customer_name,
            cash_session_uuid=remote_cash_session_uuid,
            customer_phone=sale.customer_phone,
            notes=sale.notes,
            cancelled_at=sale.cancelled_at,
            cancelled_by=cancelled_by_id,
            insurance_provider=sale.insurance_provider,
            insurance_card_id=sale.insurance_card_id,
            coverage_percent=sale.coverage_percent,
            sync_status="synced",
            synced_at=datetime.utcnow(),
            items=remote_items,
        )
        remote_db.add(remote_sale)
        remote_db.commit()
        logger.info(f"[SyncUp] Vente {sale.sale_uuid} envoyee avec succes.")

    @staticmethod
    def sync_up(local_db: Session) -> Dict[str, Any]:
        """
        Pousse les ventes POS locales non-synchronisees vers la DB MySQL remote.
        Retourne un rapport avec le nombre de ventes synchronisees.
        """
        report = {
            "synced": 0,
            "errors": 0,
            "skipped": 0,
            "online": False,
            "cash_sessions_synced": 0,
            "cash_movements_synced": 0,
        }

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
                POSSale.sync_status.in_(["pending", "local_only", "error"])
            ).order_by(POSSale.date.asc()).limit(100).all()

            if not pending_sales:
                logger.info("[SyncUp] Rien a synchroniser.")

            if pending_sales:
                logger.info(f"[SyncUp] {len(pending_sales)} vente(s) a envoyer...")

            remote_db = SessionRemote()
            try:
                SyncManager._configure_remote_scope(local_db, remote_db)
                cash_report = SyncManager._sync_cash_register(local_db, remote_db)
                report.update(cash_report)
                for sale in pending_sales:
                    try:
                        SyncManager._push_pos_sale(sale, remote_db)
                        # Marquer comme synchronisee
                        sale.sync_status = "synced"
                        sale.synced_at = datetime.utcnow()
                        local_db.commit()
                        report["synced"] += 1
                    except Exception as e:
                        remote_db.rollback()
                        logger.error(f"[SyncUp] Erreur vente {sale.sale_uuid}: {e}")
                        sale.sync_status = "error"
                        local_db.commit()
                        report["errors"] += 1
                # If a locally closed session had queued offline sales, retry its
                # final closure after the sale rows have been uploaded.
                cash_report = SyncManager._sync_cash_register(local_db, remote_db)
                report["cash_sessions_synced"] += cash_report["cash_sessions_synced"]
                report["cash_movements_synced"] += cash_report["cash_movements_synced"]
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

    # ------------------------------------------------------------------
    # SYNC DOWN : MySQL remote -> Local
    # ------------------------------------------------------------------

    @staticmethod
    def sync_down(local_db: Session, since: Any = None, force_full: bool = False) -> Dict[str, Any]:
        """
        Recupere les parametres, catalogue medicaments, lots, prix et clients
        depuis la DB MySQL remote vers la base locale.
        Supporte la synchronisation incrémentale par timestamp 'since'.
        """
        report = {
            "online": False,
            "settings_updated": 0,
            "medicines_synced": 0,
            "batches_synced": 0,
            "pricing_synced": 0,
            "customers_synced": 0,
            "errors": 0,
            "since": None,
        }

        if not _remote_available():
            logger.warning("[SyncDown] DB MySQL remote non joignable -- skip.")
            return report

        report["online"] = True
        remote_db = SessionRemote()

        try:
            SyncManager._configure_remote_scope(local_db, remote_db)

            from app.models.settings import Settings
            local_pharmacy_id = local_db.info.get("pharmacy_id")

            last_sync_setting = None
            if not force_full and since is None and local_pharmacy_id:
                last_sync_setting = local_db.query(Settings).filter(
                    Settings.pharmacy_id == local_pharmacy_id,
                    Settings.key == "last_sync_down_timestamp",
                ).first()
                if last_sync_setting and last_sync_setting.value:
                    try:
                        since = datetime.fromisoformat(last_sync_setting.value)
                    except Exception:
                        since = None

            try:
                report["settings_updated"] = SyncManager._sync_settings(local_db, remote_db)
            except Exception as e:
                logger.warning(f"[SyncDown] Settings sync skipped: {e}")
                report["errors"] += 1

            try:
                report["medicines_synced"] = SyncManager._sync_medicines(local_db, remote_db, since=since)
            except Exception as e:
                logger.warning(f"[SyncDown] Medicines sync skipped: {e}")
                report["errors"] += 1

            try:
                report["batches_synced"] = SyncManager._sync_batches(local_db, remote_db, since=since)
            except Exception as e:
                logger.warning(f"[SyncDown] Batches sync skipped: {e}")
                report["errors"] += 1

            try:
                report["pricing_synced"] = SyncManager._sync_pricing(local_db, remote_db, since=since)
            except Exception as e:
                logger.warning(f"[SyncDown] Pricing sync skipped: {e}")
                report["errors"] += 1

            try:
                report["customers_synced"] = SyncManager._sync_customers(local_db, remote_db, since=since)
            except Exception as e:
                logger.warning(f"[SyncDown] Customers sync skipped: {e}")
                report["errors"] += 1

            if local_pharmacy_id:
                now_iso = datetime.utcnow().isoformat()
                if last_sync_setting:
                    last_sync_setting.value = now_iso
                else:
                    local_db.add(Settings(
                        key="last_sync_down_timestamp",
                        value=now_iso,
                        pharmacy_id=local_pharmacy_id,
                    ))
                local_db.commit()

            report["since"] = since.isoformat() if isinstance(since, datetime) else (str(since) if since else None)

        except Exception as e:
            logger.error(f"[SyncDown] Remote scope configuration failed: {e}")
            report["errors"] += 1
        finally:
            remote_db.close()

        logger.info(f"[SyncDown] Resultat: {report}")
        return report

    @staticmethod
    def _sync_cash_register(local_db: Session, remote_db: Session) -> Dict[str, int]:
        """Idempotently copy this tenant's pending cashier sessions and movements first."""
        from app.models.cash_register import CashRegisterMovement, CashRegisterSession
        from app.models.pos_sale import POSSale
        from app.models.user import User

        local_pharmacy_id = local_db.info.get("pharmacy_id")
        remote_pharmacy_id = SyncManager._configure_remote_scope(local_db, remote_db)
        report = {"cash_sessions_synced": 0, "cash_movements_synced": 0}

        local_sessions = local_db.query(CashRegisterSession).filter(
            CashRegisterSession.pharmacy_id == local_pharmacy_id,
            CashRegisterSession.sync_status == "pending",
        ).order_by(CashRegisterSession.opened_at.asc()).all()

        pending_sale_counts = dict(
            local_db.query(
                POSSale.cash_session_uuid,
                func.count(POSSale.id),
            )
            .filter(
                POSSale.pharmacy_id == local_pharmacy_id,
                POSSale.payment_method == "cash",
                POSSale.sync_status.in_(["pending", "local_only", "error"]),
                POSSale.cash_session_uuid.is_not(None),
            )
            .group_by(POSSale.cash_session_uuid)
            .all()
        )
        pending_sale_counts = {session_uuid: count for session_uuid, count in pending_sale_counts.items()}

        for local_session in local_sessions:
            local_cashier = local_session.cashier
            if local_cashier is None or local_cashier.pharmacy_id != local_pharmacy_id:
                raise ValueError("Cash-session cashier is missing or belongs to another pharmacy")
            remote_cashier = remote_db.query(User).filter(
                User.username == local_cashier.username,
                User.pharmacy_id == remote_pharmacy_id,
            ).first()
            if remote_cashier is None:
                raise ValueError(f"Remote cashier '{local_cashier.username}' is missing")

            pending_count = pending_sale_counts.get(local_session.session_uuid, 0)
            remote_session = remote_db.query(CashRegisterSession).filter(
                CashRegisterSession.session_uuid == local_session.session_uuid,
                CashRegisterSession.pharmacy_id == remote_pharmacy_id,
            ).first()
            if remote_session is None:
                remote_session = CashRegisterSession(
                    session_uuid=local_session.session_uuid,
                    active_key=local_session.active_key,
                    pharmacy_id=remote_pharmacy_id,
                    cashier_id=remote_cashier.id,
                    opened_at=local_session.opened_at,
                    opening_amount=local_session.opening_amount,
                    closed_at=local_session.closed_at if pending_count == 0 else None,
                    expected_amount=local_session.expected_amount if pending_count == 0 else None,
                    counted_amount=local_session.counted_amount if pending_count == 0 else None,
                    variance=local_session.variance if pending_count == 0 else None,
                    status=local_session.status if pending_count == 0 else "open",
                    notes=local_session.notes,
                    sync_status="synced",
                )
                remote_db.add(remote_session)
                remote_db.flush()
            else:
                remote_session.active_key = local_session.active_key
                # Never close the remote drawer while any local cash sale is pending.
                if pending_count == 0:
                    remote_session.closed_at = local_session.closed_at
                    remote_session.expected_amount = local_session.expected_amount
                    remote_session.counted_amount = local_session.counted_amount
                    remote_session.variance = local_session.variance
                    remote_session.status = local_session.status
                remote_session.notes = local_session.notes
                remote_session.cashier_id = remote_cashier.id

            local_movements = local_db.query(CashRegisterMovement).filter(
                CashRegisterMovement.session_uuid == local_session.session_uuid,
                CashRegisterMovement.pharmacy_id == local_pharmacy_id,
            ).all()
            for local_movement in local_movements:
                exists = remote_db.query(CashRegisterMovement).filter(
                    CashRegisterMovement.movement_uuid == local_movement.movement_uuid,
                    CashRegisterMovement.pharmacy_id == remote_pharmacy_id,
                ).first()
                if exists:
                    continue
                remote_db.add(CashRegisterMovement(
                    movement_uuid=local_movement.movement_uuid,
                    session_uuid=remote_session.session_uuid,
                    session_id=remote_session.id,
                    pharmacy_id=remote_pharmacy_id,
                    cashier_id=remote_cashier.id,
                    movement_type=local_movement.movement_type,
                    amount=local_movement.amount,
                    reason=local_movement.reason,
                    occurred_at=local_movement.occurred_at,
                ))
                report["cash_movements_synced"] += 1

            remote_db.commit()
            local_session.sync_status = "synced" if pending_count == 0 else "pending"
            local_db.commit()
            report["cash_sessions_synced"] += 1

        return report

    @staticmethod
    def _sync_settings(local_db: Session, remote_db: Session) -> int:
        """Pull settings for the matching pharmacy only."""
        from app.models.settings import Settings

        local_pharmacy_id = local_db.info.get("pharmacy_id")
        SyncManager._configure_remote_scope(local_db, remote_db)
        remote_settings = remote_db.query(Settings).all()
        for remote_setting in remote_settings:
            local_setting = local_db.query(Settings).filter(
                Settings.key == remote_setting.key
            ).first()
            if local_setting:
                local_setting.value = remote_setting.value
            else:
                local_db.add(Settings(
                    key=remote_setting.key,
                    value=remote_setting.value,
                    pharmacy_id=local_pharmacy_id,
                ))
        local_db.commit()
        return len(remote_settings)

    @staticmethod
    def _sync_medicines(local_db: Session, remote_db: Session, since: Any = None) -> int:
        """Sync medicine catalog and classifications down from remote for this pharmacy."""
        from app.models.medicine import Medicine, MedicineFamily, MedicineType

        local_pharmacy_id = local_db.info.get("pharmacy_id")
        remote_pharmacy_id = remote_db.info.get("pharmacy_id")

        # 1. Sync Families
        remote_families = remote_db.query(MedicineFamily).filter(
            MedicineFamily.pharmacy_id == remote_pharmacy_id
        ).all()
        family_map = {}
        for rf in remote_families:
            lf = local_db.query(MedicineFamily).filter(
                MedicineFamily.pharmacy_id == local_pharmacy_id,
                MedicineFamily.name == rf.name,
            ).first()
            if not lf:
                lf = MedicineFamily(name=rf.name, pharmacy_id=local_pharmacy_id)
                local_db.add(lf)
                local_db.flush()
            family_map[rf.id] = lf.id

        # 2. Sync Types
        remote_types = remote_db.query(MedicineType).filter(
            MedicineType.pharmacy_id == remote_pharmacy_id
        ).all()
        type_map = {}
        for rt in remote_types:
            lt = local_db.query(MedicineType).filter(
                MedicineType.pharmacy_id == local_pharmacy_id,
                MedicineType.name == rt.name,
            ).first()
            if not lt:
                lt = MedicineType(name=rt.name, pharmacy_id=local_pharmacy_id)
                local_db.add(lt)
                local_db.flush()
            type_map[rt.id] = lt.id

        # 3. Sync Medicines (incrémental si since est défini)
        query = remote_db.query(Medicine).filter(
            Medicine.pharmacy_id == remote_pharmacy_id
        )
        if since:
            query = query.filter(Medicine.updated_at >= since)
        remote_medicines = query.all()

        synced_count = 0
        for rm in remote_medicines:
            lm = local_db.query(Medicine).filter(
                Medicine.pharmacy_id == local_pharmacy_id,
                Medicine.code == rm.code,
            ).first()

            local_fam_id = family_map.get(rm.family_id)
            local_type_id = type_map.get(rm.type_id)

            if not lm:
                lm = Medicine(
                    code=rm.code,
                    name=rm.name,
                    code_barres=rm.code_barres,
                    dci=rm.dci,
                    family_id=local_fam_id,
                    type_id=local_type_id,
                    forme_galenique=rm.forme_galenique,
                    dosage_form=rm.dosage_form,
                    packaging=rm.packaging,
                    quantity=rm.quantity,
                    min_stock_alert=rm.min_stock_alert,
                    expiry_alert_threshold=rm.expiry_alert_threshold,
                    is_active=rm.is_active,
                    lot_fabricant=rm.lot_fabricant,
                    date_entree_stock=rm.date_entree_stock,
                    expiry_date=rm.expiry_date,
                    fournisseur=rm.fournisseur,
                    boxes_per_carton=rm.boxes_per_carton,
                    blisters_per_box=rm.blisters_per_box,
                    units_per_blister=rm.units_per_blister,
                    carton_type=rm.carton_type,
                    units_per_packaging=rm.units_per_packaging,
                    price_buy=rm.price_buy,
                    price_sell=rm.price_sell,
                    prix_achat_unite=rm.prix_achat_unite,
                    prix_vente_unite=rm.prix_vente_unite,
                    prix_achat_boite=rm.prix_achat_boite,
                    prix_vente_boite=rm.prix_vente_boite,
                    prix_achat_carton=rm.prix_achat_carton,
                    prix_vente_carton=rm.prix_vente_carton,
                    prix_achat_plaquette=rm.prix_achat_plaquette,
                    prix_vente_plaquette=rm.prix_vente_plaquette,
                    pharmacy_id=local_pharmacy_id,
                )
                local_db.add(lm)
                synced_count += 1
            else:
                lm.name = rm.name
                lm.code_barres = rm.code_barres
                lm.dci = rm.dci
                lm.family_id = local_fam_id
                lm.type_id = local_type_id
                lm.forme_galenique = rm.forme_galenique
                lm.dosage_form = rm.dosage_form
                lm.packaging = rm.packaging
                lm.min_stock_alert = rm.min_stock_alert
                lm.expiry_alert_threshold = rm.expiry_alert_threshold
                lm.is_active = rm.is_active
                lm.boxes_per_carton = rm.boxes_per_carton
                lm.blisters_per_box = rm.blisters_per_box
                lm.units_per_blister = rm.units_per_blister
                lm.carton_type = rm.carton_type
                lm.units_per_packaging = rm.units_per_packaging
                lm.price_buy = rm.price_buy
                lm.price_sell = rm.price_sell
                lm.prix_achat_unite = rm.prix_achat_unite
                lm.prix_vente_unite = rm.prix_vente_unite
                lm.prix_achat_boite = rm.prix_achat_boite
                lm.prix_vente_boite = rm.prix_vente_boite
                lm.prix_achat_carton = rm.prix_achat_carton
                lm.prix_vente_carton = rm.prix_vente_carton
                lm.prix_achat_plaquette = rm.prix_achat_plaquette
                lm.prix_vente_plaquette = rm.prix_vente_plaquette
                synced_count += 1

        local_db.commit()
        return synced_count

    @staticmethod
    def _sync_batches(local_db: Session, remote_db: Session, since: Any = None) -> int:
        """Sync batches down from remote for this pharmacy."""
        from app.models.batch import Batch
        from app.models.medicine import Medicine

        local_pharmacy_id = local_db.info.get("pharmacy_id")
        remote_pharmacy_id = remote_db.info.get("pharmacy_id")

        query = remote_db.query(Batch).filter(
            Batch.pharmacy_id == remote_pharmacy_id
        )
        if since:
            query = query.filter(Batch.updated_at >= since)
        remote_batches = query.all()

        synced_count = 0
        for rb in remote_batches:
            if not rb.medicine:
                continue
            lm = local_db.query(Medicine).filter(
                Medicine.pharmacy_id == local_pharmacy_id,
                Medicine.code == rb.medicine.code,
            ).first()
            if not lm:
                continue

            lb = local_db.query(Batch).filter(
                Batch.pharmacy_id == local_pharmacy_id,
                Batch.medicine_id == lm.id,
                Batch.batch_number == rb.batch_number,
            ).first()

            if not lb:
                lb = Batch(
                    batch_number=rb.batch_number,
                    medicine_id=lm.id,
                    expiration_date=rb.expiration_date,
                    quantity=rb.quantity,
                    purchase_price=rb.purchase_price,
                    is_active=rb.is_active,
                    pharmacy_id=local_pharmacy_id,
                )
                local_db.add(lb)
                synced_count += 1
            else:
                lb.expiration_date = rb.expiration_date
                lb.purchase_price = rb.purchase_price
                lb.is_active = rb.is_active
                synced_count += 1

        local_db.commit()
        return synced_count

    @staticmethod
    def _sync_pricing(local_db: Session, remote_db: Session, since: Any = None) -> int:
        """Sync medicine pricing entries down from remote for this pharmacy."""
        from app.models.medicine_pricing import MedicinePricing
        from app.models.medicine import Medicine

        local_pharmacy_id = local_db.info.get("pharmacy_id")
        remote_pharmacy_id = remote_db.info.get("pharmacy_id")

        query = remote_db.query(MedicinePricing).filter(
            MedicinePricing.pharmacy_id == remote_pharmacy_id
        )
        if since:
            query = query.filter(MedicinePricing.updated_at >= since)
        remote_pricing = query.all()

        synced_count = 0
        for rp in remote_pricing:
            lp = local_db.query(MedicinePricing).filter(
                MedicinePricing.pharmacy_id == local_pharmacy_id,
                MedicinePricing.lot == rp.lot,
                MedicinePricing.nom == rp.nom,
            ).first()

            local_med_id = None
            if rp.medicine_id and rp.medicine:
                lm = local_db.query(Medicine).filter(
                    Medicine.pharmacy_id == local_pharmacy_id,
                    Medicine.code == rp.medicine.code,
                ).first()
                if lm:
                    local_med_id = lm.id

            if not lp:
                lp = MedicinePricing(
                    medicine_id=local_med_id,
                    nom=rp.nom,
                    dci=rp.dci,
                    forme=rp.forme,
                    dosage=rp.dosage,
                    lot=rp.lot,
                    fournisseur=rp.fournisseur,
                    bon_livraison=rp.bon_livraison,
                    date_reception=rp.date_reception,
                    date_peremption=rp.date_peremption,
                    nb_cartons=rp.nb_cartons,
                    boites_par_carton=rp.boites_par_carton,
                    plaquettes_par_boite=rp.plaquettes_par_boite,
                    comprimes_par_plaquette=rp.comprimes_par_plaquette,
                    total_boites=rp.total_boites,
                    total_plaquettes=rp.total_plaquettes,
                    total_comprimes=rp.total_comprimes,
                    prix_mode=rp.prix_mode,
                    achat_carton=rp.achat_carton,
                    achat_boite=rp.achat_boite,
                    achat_plaquette=rp.achat_plaquette,
                    achat_comprime=rp.achat_comprime,
                    vente_carton=rp.vente_carton,
                    vente_boite=rp.vente_boite,
                    vente_plaquette=rp.vente_plaquette,
                    vente_comprime=rp.vente_comprime,
                    marge_pct=rp.marge_pct,
                    benefice_estime=rp.benefice_estime,
                    seuil_alerte=rp.seuil_alerte,
                    pharmacy_id=local_pharmacy_id,
                )
                local_db.add(lp)
                synced_count += 1
            else:
                lp.medicine_id = local_med_id or lp.medicine_id
                lp.dci = rp.dci
                lp.forme = rp.forme
                lp.dosage = rp.dosage
                lp.fournisseur = rp.fournisseur
                lp.bon_livraison = rp.bon_livraison
                lp.date_reception = rp.date_reception
                lp.date_peremption = rp.date_peremption
                lp.nb_cartons = rp.nb_cartons
                lp.boites_par_carton = rp.boites_par_carton
                lp.plaquettes_par_boite = rp.plaquettes_par_boite
                lp.comprimes_par_plaquette = rp.comprimes_par_plaquette
                lp.total_boites = rp.total_boites
                lp.total_plaquettes = rp.total_plaquettes
                lp.total_comprimes = rp.total_comprimes
                lp.prix_mode = rp.prix_mode
                lp.achat_carton = rp.achat_carton
                lp.achat_boite = rp.achat_boite
                lp.achat_plaquette = rp.achat_plaquette
                lp.achat_comprime = rp.achat_comprime
                lp.vente_carton = rp.vente_carton
                lp.vente_boite = rp.vente_boite
                lp.vente_plaquette = rp.vente_plaquette
                lp.vente_comprime = rp.vente_comprime
                lp.marge_pct = rp.marge_pct
                lp.benefice_estime = rp.benefice_estime
                lp.seuil_alerte = rp.seuil_alerte
                synced_count += 1

        local_db.commit()
        return synced_count

    @staticmethod
    def _sync_customers(local_db: Session, remote_db: Session, since: Any = None) -> int:
        """Sync customers down from remote for this pharmacy."""
        from app.models.customer import Customer

        local_pharmacy_id = local_db.info.get("pharmacy_id")
        remote_pharmacy_id = remote_db.info.get("pharmacy_id")

        query = remote_db.query(Customer).filter(
            Customer.pharmacy_id == remote_pharmacy_id
        )
        if since:
            query = query.filter(Customer.updated_at >= since)
        remote_customers = query.all()

        synced_count = 0
        for rc in remote_customers:
            lc = local_db.query(Customer).filter(
                Customer.pharmacy_id == local_pharmacy_id,
                Customer.phone == rc.phone,
            ).first()

            if not lc:
                lc = Customer(
                    first_name=rc.first_name,
                    last_name=rc.last_name,
                    phone=rc.phone,
                    total_points=rc.total_points,
                    pharmacy_id=local_pharmacy_id,
                )
                local_db.add(lc)
                synced_count += 1
            else:
                lc.first_name = rc.first_name
                lc.last_name = rc.last_name
                lc.total_points = max(lc.total_points, rc.total_points)
                synced_count += 1

        local_db.commit()
        return synced_count

    @staticmethod
    def process_batch_upload(
        db: Session,
        sales_payload: List[Any],
        current_user: Any,
    ) -> Dict[str, Any]:
        """
        Traite un lot de ventes POS reçues (batch upload) de manière idempotente.
        """
        from app.models.pos_sale import POSSale, POSSaleItem
        from app.models.medicine import Medicine
        from app.models.batch import Batch
        from app.models.customer import Customer

        pharmacy_id = current_user.pharmacy_id
        results = {
            "total_received": len(sales_payload),
            "total_inserted": 0,
            "total_skipped": 0,
            "errors": [],
        }

        for item in sales_payload:
            sale_data = item if isinstance(item, dict) else item.model_dump()
            uuid = sale_data.get("sale_uuid")
            if not uuid:
                results["errors"].append({"error": "sale_uuid is required", "sale": sale_data.get("code")})
                continue

            existing = db.query(POSSale).filter(POSSale.sale_uuid == uuid).first()
            if existing:
                results["total_skipped"] += 1
                continue

            try:
                cust_id = None
                phone = sale_data.get("customer_phone")
                if phone:
                    cust = db.query(Customer).filter(Customer.phone == phone).first()
                    if cust:
                        cust_id = cust.id

                sale_date = sale_data.get("date") or datetime.utcnow()
                if isinstance(sale_date, str):
                    try:
                        sale_date = datetime.fromisoformat(sale_date)
                    except Exception:
                        sale_date = datetime.utcnow()

                pos_sale = POSSale(
                    sale_uuid=uuid,
                    code=sale_data.get("code", f"POS-{uuid[:8]}"),
                    total_amount=float(sale_data.get("total_amount", 0.0)),
                    payment_method=sale_data.get("payment_method", "cash"),
                    date=sale_date,
                    user_id=current_user.id,
                    customer_id=cust_id,
                    customer_name=sale_data.get("customer_name"),
                    customer_phone=phone,
                    cash_session_uuid=sale_data.get("cash_session_uuid"),
                    notes=sale_data.get("notes"),
                    status="completed",
                    sync_status="synced",
                    synced_at=datetime.utcnow(),
                    pharmacy_id=pharmacy_id,
                )
                db.add(pos_sale)
                db.flush()

                for raw_line in sale_data.get("items", []):
                    med_code = raw_line.get("medicine_code")
                    med = db.query(Medicine).filter(Medicine.code == med_code).first()
                    if not med:
                        continue

                    batch_id = None
                    batch_num = raw_line.get("batch_number")
                    if batch_num:
                        b = db.query(Batch).filter(Batch.batch_number == batch_num, Batch.medicine_id == med.id).first()
                        if b:
                            batch_id = b.id

                    sale_item = POSSaleItem(
                        sale_id=pos_sale.id,
                        medicine_id=med.id,
                        batch_id=batch_id,
                        quantity=int(raw_line.get("quantity", 1)),
                        unit_price=float(raw_line.get("unit_price", 0.0)),
                        total_price=float(raw_line.get("total_price", 0.0)),
                        pharmacy_id=pharmacy_id,
                    )
                    db.add(sale_item)

                db.commit()
                results["total_inserted"] += 1
            except Exception as e:
                db.rollback()
                results["errors"].append({"sale_uuid": uuid, "error": str(e)})

        return results

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
        cache_key = local_db.info.get("pharmacy_id")

        # Retourner le cache si encore valide
        cached_status = _status_cache.get(cache_key)
        if cached_status and now - cached_status["ts"] < _STATUS_CACHE_TTL:
            return cached_status["data"]

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

        _status_cache[cache_key] = {"data": result, "ts": now}
        return result

    # ------------------------------------------------------------------
    # QUEUE LEGACY (compatibilite avec l'ancien code)
    # ------------------------------------------------------------------

    @staticmethod
    def add_to_queue(db: Session, action, table_name: str, data: Dict[str, Any]):
        """Compatibilite legacy -- utiliser sync_up() a la place."""
        logger.info(f"[SyncQueue] Action {action} sur {table_name} -> sera traitee par sync_up()")

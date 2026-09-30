"""
Audit service for logging and retrieving deletion and cancellation events.
"""

import logging
from typing import Optional, List, Dict, Any
from sqlalchemy.orm import Session
from sqlalchemy import desc
from app.models.audit_log import DeletionLog
from app.models.user import User

logger = logging.getLogger("audit_service")


def _ensure_table(db: Session):
    try:
        DeletionLog.__table__.create(db.get_bind(), checkfirst=True)
    except Exception:
        pass


def log_deletion(
    db: Session,
    action: str,
    entity_type: str,
    entity_id: Optional[int],
    entity_name: str,
    user: Optional[User] = None,
    username: Optional[str] = None,
    user_role: Optional[str] = None,
    details: Optional[str] = None,
) -> DeletionLog:
    """
    Record a deletion or cancellation event in the audit log.
    """
    _ensure_table(db)
    try:
        final_username = username
        final_role = user_role
        final_user_id = None

        if user:
            final_user_id = getattr(user, 'id', None)
            final_username = getattr(user, 'username', 'Inconnu')
            final_role = getattr(user, 'role', 'pharmacist')

        if not final_username:
            final_username = "Système"

        log_entry = DeletionLog(
            action=action,
            entity_type=entity_type,
            entity_id=entity_id,
            entity_name=entity_name,
            user_id=final_user_id,
            username=final_username,
            user_role=str(final_role),
            details=details,
        )
        db.add(log_entry)
        db.commit()
        db.refresh(log_entry)
        logger.info(f"[AUDIT] {action} on {entity_type} '{entity_name}' by {final_username} ({final_role})")
        return log_entry
    except Exception as e:
        logger.error(f"[AUDIT ERROR] Failed to log deletion: {e}")
        db.rollback()
        # Non-blocking: we do not crash the main operation if audit logging fails
        return None


def get_deletion_logs(
    db: Session,
    entity_type: Optional[str] = None,
    action: Optional[str] = None,
    entity_id: Optional[int] = None,
    start_date: Optional[str] = None,
    end_date: Optional[str] = None,
    search: Optional[str] = None,
    limit: int = 100,
    offset: int = 0,
) -> Dict[str, Any]:
    """
    Retrieve audit logs with optional filtering by entity type, action, entity ID, date range, and text search.
    """
    from datetime import datetime, timedelta

    _ensure_table(db)
    query = db.query(DeletionLog)

    if entity_type and entity_type != "all":
        query = query.filter(DeletionLog.entity_type == entity_type)

    if action and action != "all":
        if action == "UPDATE":
            query = query.filter(DeletionLog.action.ilike("UPDATE%"))
        elif action == "DELETE":
            query = query.filter(DeletionLog.action.ilike("DELETE%"))
        else:
            query = query.filter(DeletionLog.action == action)

    if entity_id is not None:
        query = query.filter(DeletionLog.entity_id == entity_id)

    if start_date:
        try:
            s_dt = datetime.strptime(start_date, "%Y-%m-%d")
            query = query.filter(DeletionLog.created_at >= s_dt)
        except ValueError:
            pass

    if end_date:
        try:
            e_dt = datetime.strptime(end_date, "%Y-%m-%d") + timedelta(days=1)
            query = query.filter(DeletionLog.created_at < e_dt)
        except ValueError:
            pass

    if search:
        s = f"%{search}%"
        query = query.filter(
            (DeletionLog.entity_name.ilike(s)) |
            (DeletionLog.username.ilike(s)) |
            (DeletionLog.action.ilike(s)) |
            (DeletionLog.details.ilike(s))
        )

    total = query.count()
    logs = query.order_by(desc(DeletionLog.created_at)).offset(offset).limit(limit).all()
    return {
        "items": [log.to_dict() for log in logs],
        "total": total,
    }


def delete_audit_log(db: Session, log_id: int) -> bool:
    """Delete a single audit log entry by ID."""
    _ensure_table(db)
    log = db.query(DeletionLog).filter(DeletionLog.id == log_id).first()
    if not log:
        return False
    db.delete(log)
    db.commit()
    logger.info(f"[AUDIT] Deleted audit log #{log_id}")
    return True


def delete_audit_logs(db: Session, log_ids: List[int]) -> int:
    """Delete multiple audit log entries by their IDs. Returns count of deleted logs."""
    _ensure_table(db)
    if not log_ids:
        return 0
    deleted = db.query(DeletionLog).filter(DeletionLog.id.in_(log_ids)).delete(synchronize_session=False)
    db.commit()
    logger.info(f"[AUDIT] Bulk deleted {deleted} audit log(s)")
    return deleted



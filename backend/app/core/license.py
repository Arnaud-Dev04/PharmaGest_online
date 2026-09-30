from datetime import datetime
from .config import LICENSE_EXPIRATION_DATE, WARNING_DAYS_THRESHOLD

from sqlalchemy.orm import Session
from app.models.settings import Settings
import time

# ── Cache en mémoire pour éviter 3 queries Aiven par requête ─────────────────
# La licence ne change pas souvent : on garde le résultat 60 secondes.
_license_cache: dict = {}
_LICENSE_CACHE_TTL = 60  # secondes


class LicenseService:
    @staticmethod
    def get_license_status(db: Session = None):
        global _license_cache

        # Retourner le cache si encore valide
        now_ts = time.time()
        if _license_cache.get("ts") and now_ts - _license_cache["ts"] < _LICENSE_CACHE_TTL:
            return _license_cache["data"]

        expiration_date_str = LICENSE_EXPIRATION_DATE
        warning_days = WARNING_DAYS_THRESHOLD
        warning_msg = "Votre licence expire bientôt. Veuillez contacter le concepteur pour une mise à jour."

        # Try to get from DB if session is provided
        if db:
            try:
                # 1. Expiration Date
                setting = db.query(Settings).filter(Settings.key == "license_expiry_date").first()
                if setting and setting.value:
                    expiration_date_str = setting.value

                # 2. Warning Days Threshold
                setting = db.query(Settings).filter(Settings.key == "license_warning_bdays").first()
                if setting and setting.value:
                    try:
                        warning_days = int(setting.value)
                    except Exception:
                        pass

                # 3. Warning Message
                setting = db.query(Settings).filter(Settings.key == "license_warning_message").first()
                if setting and setting.value:
                    warning_msg = setting.value

            except Exception:
                pass  # Fallback to config

        try:
            expiration_date = datetime.strptime(expiration_date_str, "%Y-%m-%d")
            today = datetime.now()

            delta = expiration_date - today
            days_remaining = delta.days + 1  # Include today

            if days_remaining < 0:
                result = {
                    "status": "expired",
                    "days_remaining": 0,
                    "expiration_date": expiration_date_str,
                    "message": warning_msg,
                }
            elif days_remaining <= warning_days:
                result = {
                    "status": "warning",
                    "days_remaining": days_remaining,
                    "expiration_date": expiration_date_str,
                    "message": warning_msg,
                }
            else:
                result = {
                    "status": "valid",
                    "days_remaining": days_remaining,
                    "expiration_date": expiration_date_str,
                    "message": "Licence valide.",
                }
        except Exception as e:
            result = {
                "status": "error",
                "message": f"Erreur de vérification de licence: {str(e)}",
            }

        # Stocker dans le cache (même les erreurs, pour ne pas bombarder Aiven)
        _license_cache = {"ts": time.time(), "data": result}
        return result

    @staticmethod
    def invalidate_cache():
        """Appeler après modification de la licence pour forcer le rechargement."""
        global _license_cache
        _license_cache = {}

    @staticmethod
    def check_license_validity(db: Session = None) -> bool:
        """Returns True if license is valid, False otherwise."""
        status = LicenseService.get_license_status(db)
        return status["status"] != "expired"


license_service = LicenseService()

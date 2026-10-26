from datetime import datetime
from .config import LICENSE_EXPIRATION_DATE, WARNING_DAYS_THRESHOLD

from sqlalchemy.orm import Session
from app.models.settings import Settings
import time

from app.core.distributed_cache import get_cache, set_cache, delete_cache, tenant_key

_LICENSE_CACHE_TTL = 60  # secondes


class LicenseService:
    @staticmethod
    def get_license_status(db: Session = None):
        pharmacy_id = db.info.get("pharmacy_id") if db else None
        cache_k = tenant_key(pharmacy_id, "license", "status")

        cached = get_cache(cache_k)
        if cached is not None:
            return cached

        expiration_date_str = LICENSE_EXPIRATION_DATE
        warning_days = WARNING_DAYS_THRESHOLD
        warning_msg = "Votre licence expire bientôt. Veuillez contacter le concepteur pour une mise à jour."

        # Try to get from DB if session is provided
        if db:
            try:
                pharmacy = None
                if pharmacy_id:
                    from app.models.pharmacy import Pharmacy
                    pharmacy = db.query(Pharmacy).filter(Pharmacy.id == pharmacy_id).first()

                if pharmacy and pharmacy.license_expires_at:
                    expiration_date_str = pharmacy.license_expires_at.strftime("%Y-%m-%d")
                    if pharmacy.license_is_trial:
                        warning_msg = "Votre période d'essai expire bientôt. Veuillez souscrire à un abonnement."
                else:
                    # 1. Expiration Date from Settings fallback
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

        set_cache(cache_k, result, ttl_seconds=_LICENSE_CACHE_TTL)
        return result

    @staticmethod
    def invalidate_cache(pharmacy_id: int = None):
        """Appeler après modification de la licence pour forcer le rechargement."""
        if pharmacy_id is None:
            from app.core.distributed_cache import invalidate_tenant_namespace
            invalidate_tenant_namespace(None, "license")
        else:
            cache_k = tenant_key(pharmacy_id, "license", "status")
            delete_cache(cache_k)

    @staticmethod
    def check_license_validity(db: Session = None) -> bool:
        """Returns True if license is valid, False otherwise."""
        status = LicenseService.get_license_status(db)
        return status["status"] != "expired"


license_service = LicenseService()

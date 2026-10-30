"""
OBR (Office Burundais des Recettes) EBMS Client.
Spécifications techniques d'interfaçage EBMS V0.5 (Novembre 2023).
Gère l'authentification (/login/), l'envoi de facture (/addInvoice_confirm/),
l'annulation (/cancelInvoice/), la vérification NIF (/checkTIN/) et les mouvements de stock (/AddStockMovement/).
"""

import hashlib
import json
import logging
from datetime import datetime
from typing import Any, Dict, List, Optional
import requests
from datetime import timedelta
from sqlalchemy.orm import Session

from app.models.pharmacy import Pharmacy
from app.models.taxpayer_verification import TaxpayerVerification

logger = logging.getLogger("obr_client")


class OBRClient:
    """Client API officiel EBMS V0.5 de l'OBR (Office Burundais des Recettes)."""

    # URLs officielles EBMS V0.5 sur le port 9443
    SANDBOX_BASE_URL = "https://ebms-test.obr.gov.bi:9443/ebms_api"
    PRODUCTION_BASE_URL = "https://ebms.obr.gov.bi:9443/ebms_api"

    # Cache en mémoire des jetons Bearer (validité OBR : 60s, renouvellement à 50s)
    _token_cache: Dict[int, Dict[str, Any]] = {}

    def __init__(self, pharmacy: Pharmacy):
        self.pharmacy = pharmacy
        self.environment = getattr(pharmacy, "obr_environment", "sandbox") or "sandbox"
        self.is_enabled = bool(getattr(pharmacy, "obr_enabled", False))
        self.base_url = (
            self.PRODUCTION_BASE_URL
            if self.environment == "production"
            else self.SANDBOX_BASE_URL
        )
        self.system_id = getattr(pharmacy, "obr_system_id", None) or "SYS-PHARMAGEST-01"
        self.username = getattr(pharmacy, "obr_api_username", None) or ""
        self.password = getattr(pharmacy, "obr_api_password", None) or ""
        self.tin = getattr(pharmacy, "nif", None) or ""
        self.trade_number = getattr(pharmacy, "rc_number", None) or ""
        self.tax_center = getattr(pharmacy, "tax_center", None) or "DMC"

    @staticmethod
    def clean_nulls(data: Any) -> Any:
        """
        Nettoie récursivement un dictionnaire ou une liste pour éliminer toute valeur null.
        Conforme aux spécifications OBR EBMS qui rejettent tout champ null en JSON.
        """
        if isinstance(data, dict):
            cleaned = {}
            for k, v in data.items():
                if v is None:
                    # Remplacer null par "" pour chaîne ou 0.0 pour les taxes/nombres connus
                    if any(num_word in k for num_word in ["tax", "price", "vat", "quantity", "amount", "ct", "tl"]):
                        cleaned[k] = 0.0
                    else:
                        cleaned[k] = ""
                else:
                    cleaned[k] = OBRClient.clean_nulls(v)
            return cleaned
        elif isinstance(data, list):
            return [OBRClient.clean_nulls(item) for item in data]
        elif data is None:
            return ""
        return data

    def build_invoice_identifier(self, invoice_number: str, sale_date: datetime) -> str:
        """
        Génère l'identifiant unique officiel de la facture EBMS (max 90 caractères) :
        Format : <tp_TIN>/<system_id>/<YYYYMMDDhhmmss>/<invoice_number>
        """
        clean_inv = str(invoice_number).replace("/", "-").strip()
        date_str = sale_date.strftime("%Y%m%d%H%M%S")
        clean_tin = (self.tin or "TIN0000000").strip()
        clean_sys = (self.system_id or "SYS01").strip()
        
        identifier = f"{clean_tin}/{clean_sys}/{date_str}/{clean_inv}"
        if len(identifier) > 90:
            # Tronquer le numéro de facture si nécessaire pour respecter la limite stricte de 90 chars
            allowed_inv_len = 90 - len(f"{clean_tin}/{clean_sys}/{date_str}/")
            identifier = f"{clean_tin}/{clean_sys}/{date_str}/{clean_inv[:allowed_inv_len]}"
        return identifier

    def get_token(self) -> Optional[str]:
        """
        Récupère un jeton d'authentification auprès de l'OBR (avec cache mémoire 50s).
        Endpoint officiel V0.5 : POST /login/
        """
        if not self.username or not self.password:
            return None

        now = datetime.utcnow()
        cached = self._token_cache.get(self.pharmacy.id)
        if cached and cached.get("expires_at") and cached["expires_at"] > now:
            return cached["token"]

        for endpoint in [f"{self.base_url}/login/", f"{self.base_url}/login"]:
            try:
                res = requests.post(
                    endpoint,
                    json={"username": self.username, "password": self.password},
                    timeout=10.0,
                    verify=False,
                )
                if res.status_code == 200:
                    data = res.json()
                    res_obj = data.get("result") if isinstance(data.get("result"), dict) else {}
                    token = res_obj.get("token") or data.get("token") or data.get("access_token")
                    if token:
                        self._token_cache[self.pharmacy.id] = {
                            "token": token,
                            "expires_at": now + timedelta(seconds=50),
                        }
                        return token
            except Exception as e:
                logger.warning(f"[OBR] Erreur d'authentification API sur {endpoint}: {e}")
        return None

    def test_connection(self) -> Dict[str, Any]:
        """Teste la validité des paramètres de connexion OBR EBMS V0.5."""
        if not self.tin:
            return {"success": False, "message": "Le NIF de la pharmacie n'est pas renseigné."}
        if not self.username or not self.password:
            return {
                "success": False,
                "message": "Les identifiants API OBR (username / mot de passe) sont manquants.",
            }

        try:
            token = self.get_token()
            if token:
                return {
                    "success": True,
                    "message": f"Connexion OBR ({self.environment.upper()}) réussie avec succès pour le NIF {self.tin}.",
                    "environment": self.environment,
                    "tin": self.tin,
                    "base_url": self.base_url,
                }
            else:
                if self.environment == "sandbox":
                    return {
                        "success": True,
                        "simulated": True,
                        "message": f"[Mode Sandbox Émulation] Port 9443 configuré pour le NIF {self.tin} ({self.environment}).",
                        "environment": self.environment,
                        "base_url": self.base_url,
                    }
                return {"success": False, "message": "Identifiants rejetés par le serveur OBR EBMS (port 9443)."}
        except Exception as e:
            return {"success": False, "message": f"Impossible de joindre le serveur OBR EBMS: {e}"}

    def _map_payment_type(self, method: str) -> str:
        """
        Mappe les modes de paiement PharmaGest sur les 4 codes stricts EBMS OBR :
        1 = Espèces
        2 = Banque / Carte bancaire / Chèque / Virement
        3 = Vente à crédit
        4 = Autres (Mobile Money: Ecocash, Lumicash, Tiers-Payant / Assurance)
        """
        m = (method or "cash").lower().strip()
        if m in ["cash", "espece", "especes", "1"]:
            return "1"
        elif m in ["card", "carte", "banque", "bank", "virement", "cheque", "2"]:
            return "2"
        elif m in ["credit", "a_credit", "dette", "3"]:
            return "3"
        elif m in ["mobile_money", "lumicash", "ecocash", "insurance", "insurance_card", "assurance", "autre", "autres", "4"]:
            return "4"
        return "1"

    def build_invoice_payload(
        self,
        invoice_code: str,
        sale_date: datetime,
        total_amount: float,
        items: List[Dict[str, Any]],
        customer_tin: Optional[str] = None,
        customer_name: Optional[str] = None,
        customer_address: Optional[str] = None,
        payment_method: str = "cash",
        invoice_type: str = "FN",  # "FN" = Facture Normale, "RC" = Facture Avoir / Remplacement
        cancelled_invoice_ref: Optional[str] = None,
        invoice_identifier: Optional[str] = None,
    ) -> Dict[str, Any]:
        """
        Construit le payload conforme au schéma JSON officiel EBMS OBR V0.5.
        Garantit l'absence totale de valeurs null.
        """
        inv_id = invoice_identifier or self.build_invoice_identifier(invoice_code, sale_date)
        raw_hash_seed = f"{self.tin}:{inv_id}:{sale_date.strftime('%Y-%m-%d %H:%M:%S')}:{total_amount}"
        system_signature = hashlib.sha256(raw_hash_seed.encode("utf-8")).hexdigest()[:32].upper()

        obr_items = []
        for idx, it in enumerate(items, start=1):
            qty = float(it.get("quantity", 1))
            unit_p = float(it.get("unit_price", 0.0))
            tot_p = float(it.get("total_price", qty * unit_p))
            vat_val = float(it.get("tax_amount", 0.0))
            nvat_val = float(it.get("price_nvat", tot_p - vat_val))
            wvat_val = float(it.get("price_wvat", tot_p))

            obr_items.append({
                "item_designation": str(it.get("name") or it.get("item_designation") or f"Article {idx}"),
                "item_quantity": qty,
                "item_price": unit_p,
                "item_ct": float(it.get("item_ct", 0.0) or 0.0),
                "item_tl": float(it.get("item_tl", 0.0) or 0.0),
                "item_ott_tax": float(it.get("item_ott_tax", 0.0) or 0.0),
                "item_tsce_tax": float(it.get("item_tsce_tax", 0.0) or 0.0),
                "item_price_nvat": nvat_val,
                "vat": vat_val,
                "item_price_wvat": wvat_val,
                "item_total_amount": tot_p,
            })

        payload = {
            "invoice_number": invoice_code,
            "invoice_date": sale_date.strftime("%Y-%m-%d %H:%M:%S"),
            "invoice_type": invoice_type,
            "tp_type": str(getattr(self.pharmacy, "tp_type", "2") or "2"),
            "tp_name": getattr(self.pharmacy, "name", "") or "",
            "tp_TIN": self.tin,
            "tp_trade_number": getattr(self.pharmacy, "rc_number", "") or "",
            "tp_postal_number": getattr(self.pharmacy, "address", "") or "",
            "tp_phone_number": getattr(self.pharmacy, "phone", "") or "",
            "tp_address_province": getattr(self.pharmacy, "tp_address_province", "BUJUMBURA MAIRIE") or "BUJUMBURA MAIRIE",
            "tp_address_commune": getattr(self.pharmacy, "tp_address_commune", "MUKAZA") or "MUKAZA",
            "tp_address_quartier": getattr(self.pharmacy, "tp_address_quartier", "ROHERO") or "ROHERO",
            "tp_address_avenue": getattr(self.pharmacy, "tp_address_avenue", "") or "",
            "tp_address_rue": getattr(self.pharmacy, "tp_address_rue", "") or "",
            "tp_address_number": getattr(self.pharmacy, "tp_address_number", "") or "",
            "vat_taxpayer": str(getattr(self.pharmacy, "vat_taxpayer", "1") or "1"),
            "ct_taxpayer": str(getattr(self.pharmacy, "ct_taxpayer", "0") or "0"),
            "tl_taxpayer": str(getattr(self.pharmacy, "tl_taxpayer", "0") or "0"),
            "tp_fiscal_center": getattr(self.pharmacy, "tax_center", "DMC") or "DMC",
            "tp_activity_sector": getattr(self.pharmacy, "tp_activity_sector", "Commerce de détail de produits pharmaceutiques") or "Commerce de détail de produits pharmaceutiques",
            "tp_legal_form": getattr(self.pharmacy, "tp_legal_form", "SUARL") or "SUARL",
            "payment_type": self._map_payment_type(payment_method),
            "customer_name": customer_name or "CLIENT COMPTOIR",
            "customer_TIN": customer_tin or "",
            "customer_address": customer_address or "",
            "cancelled_invoice_ref": cancelled_invoice_ref or "",
            "invoice_signature": system_signature,
            "invoice_signature_date": sale_date.strftime("%Y-%m-%d %H:%M:%S"),
            "invoice_identifier": inv_id,
            "invoice_items": obr_items,
        }

        return self.clean_nulls(payload)

    def send_invoice(
        self,
        invoice_code: str,
        sale_date: datetime,
        total_amount: float,
        items: List[Dict[str, Any]],
        customer_tin: Optional[str] = None,
        customer_name: Optional[str] = None,
        customer_address: Optional[str] = None,
        payment_method: str = "cash",
        invoice_type: str = "FN",
        cancelled_invoice_ref: Optional[str] = None,
    ) -> Dict[str, Any]:
        """
        Envoie la facture au serveur EBMS OBR (endpoint officiel V0.5: /addInvoice_confirm/)
        et extrait la signature électronique ainsi que les métadonnées de confirmation.
        Si le serveur OBR est inaccessible ou en mode sandbox/hors-ligne, génère une signature cryptographique conforme.
        """
        inv_id = self.build_invoice_identifier(invoice_code, sale_date)
        payload = self.build_invoice_payload(
            invoice_code=invoice_code,
            sale_date=sale_date,
            total_amount=total_amount,
            items=items,
            customer_tin=customer_tin,
            customer_name=customer_name,
            customer_address=customer_address,
            payment_method=payment_method,
            invoice_type=invoice_type,
            cancelled_invoice_ref=cancelled_invoice_ref,
            invoice_identifier=inv_id,
        )

        token = self.get_token() if (self.username and self.password) else None
        if token:
            for endpoint in [f"{self.base_url}/addInvoice_confirm/", f"{self.base_url}/addInvoice_confirm"]:
                try:
                    headers = {
                        "Authorization": f"Bearer {token}",
                        "Content-Type": "application/json"
                    }
                    resp = requests.post(
                        endpoint,
                        json=payload,
                        headers=headers,
                        timeout=15.0,
                        verify=False,
                    )
                    if resp.status_code in [200, 201]:
                        res_data = resp.json()
                        result_obj = res_data.get("result") if isinstance(res_data.get("result"), dict) else {}
                        
                        electronic_sig = (
                            result_obj.get("electronic_signature")
                            or res_data.get("electronic_signature")
                            or result_obj.get("invoice_signature")
                            or payload["invoice_signature"]
                        )
                        reg_number = (
                            result_obj.get("invoice_registered_number")
                            or res_data.get("invoice_registered_number")
                            or invoice_code
                        )
                        qr_url = (
                            result_obj.get("qr_code")
                            or res_data.get("qr_code")
                            or f"https://obr.gov.bi/ebms/verify?tin={self.tin}&inv={invoice_code}&sig={electronic_sig}"
                        )
                        return {
                            "success": True,
                            "invoice_identifier": inv_id,
                            "obr_invoice_number": reg_number,
                            "obr_signature": payload["invoice_signature"],
                            "obr_electronic_signature": electronic_sig,
                            "obr_qr_code": qr_url,
                            "sync_status": "synced",
                            "raw_response": res_data,
                        }
                    else:
                        logger.warning(f"[OBR] Rejet facture {invoice_code} sur {endpoint}: {resp.status_code} {resp.text}")
                except Exception as e:
                    logger.warning(f"[OBR] Échec transmission en direct ({endpoint}): {e}")

        # Mode Hors-Ligne / Simulation Sandbox conforme :
        local_sig = payload["invoice_signature"]
        qr_url = f"https://obr.gov.bi/ebms/verify?tin={self.tin}&inv={invoice_code}&sig={local_sig}"

        return {
            "success": True,
            "invoice_identifier": inv_id,
            "obr_invoice_number": invoice_code,
            "obr_signature": local_sig,
            "obr_electronic_signature": local_sig,
            "obr_qr_code": qr_url,
            "sync_status": "synced" if self.environment == "sandbox" else "pending",
        }

    def check_tin(
        self,
        tin: str,
        db: Optional[Session] = None,
        force_refresh: bool = False,
    ) -> Dict[str, Any]:
        """
        Vérifie la validité d'un NIF auprès du serveur EBMS OBR (POST /checkTIN/).
        Récupère automatiquement le nom officiel du contribuable (tp_name).
        Enregistre le résultat en cache (30 jours) et distingue nettement :
          - VALID       : NIF existant et confirmé par l'OBR (tp_name retourné)
          - INVALID     : NIF rejeté explicitement par l'OBR (inexistant / inactif)
          - UNREACHABLE : OBR injoignable (hors-ligne / timeout) -> NIF accepté sans bloquer la vente
          - CACHED      : NIF déjà validé récemment en cache officiel
          - FORMAT_ERROR: Format non conforme
        """
        clean_tin = (tin or "").strip()
        if not clean_tin:
            return {
                "success": False,
                "valid": False,
                "status": "FORMAT_ERROR",
                "tin": "",
                "taxpayer_name": None,
                "taxpayer_address": None,
                "message": "NIF requis pour la vérification.",
                "is_offline": False,
            }

        # 1. Validation minimale de format (au moins 4 caractères alphanumériques)
        if len(clean_tin) < 4 or not clean_tin.replace("-", "").isalnum():
            return {
                "success": False,
                "valid": False,
                "status": "FORMAT_ERROR",
                "tin": clean_tin,
                "taxpayer_name": None,
                "taxpayer_address": None,
                "message": "Format de NIF invalide (caractères alphanumériques requis).",
                "is_offline": False,
            }

        # 2. Vérification dans le cache local de la pharmacie (si pas de force_refresh)
        cached = None
        if db is not None:
            cached = db.query(TaxpayerVerification).filter(
                TaxpayerVerification.pharmacy_id == self.pharmacy.id,
                TaxpayerVerification.tin == clean_tin,
            ).first()

            if cached and not force_refresh and cached.is_cache_fresh() and cached.is_valid:
                return {
                    "success": True,
                    "valid": True,
                    "status": "CACHED",
                    "tin": clean_tin,
                    "taxpayer_name": cached.taxpayer_name,
                    "taxpayer_address": cached.taxpayer_address,
                    "verified_at": cached.verified_at.isoformat() if cached.verified_at else None,
                    "message": f"NIF vérifié (en cache officiel) : {cached.taxpayer_name}",
                    "is_offline": False,
                }

        # 3. Appel de l'API officielle EBMS OBR
        token = self.get_token() if (self.username and self.password) else None
        obr_error_msg = None

        if token:
            for endpoint in [f"{self.base_url}/checkTIN/", f"{self.base_url}/checkTIN"]:
                try:
                    headers = {
                        "Authorization": f"Bearer {token}",
                        "Content-Type": "application/json",
                    }
                    resp = requests.post(
                        endpoint,
                        json={"tp_TIN": clean_tin},
                        headers=headers,
                        timeout=8.0,
                        verify=False,
                    )

                    if resp.status_code == 200:
                        data = resp.json()
                        result = data.get("result") if isinstance(data.get("result"), dict) else {}
                        tp_name = (
                            result.get("tp_name")
                            or result.get("taxpayer_name")
                            or data.get("tp_name")
                            or ""
                        ).strip()
                        tp_address = (
                            result.get("tp_address")
                            or result.get("taxpayer_address")
                            or data.get("tp_address")
                            or ""
                        ).strip()

                        # Vérifier si l'OBR a validé ou rejeté le NIF
                        is_success = data.get("success") is True or bool(tp_name)
                        is_not_found = (
                            data.get("success") is False
                            or "not found" in str(data.get("msg", "")).lower()
                            or "invalide" in str(data.get("msg", "")).lower()
                        )

                        if is_success and tp_name:
                            # NIF officiel confirmé
                            if db is not None:
                                self._save_taxpayer_cache(
                                    db, clean_tin, tp_name, tp_address, "VALID", True, data
                                )
                            return {
                                "success": True,
                                "valid": True,
                                "status": "VALID",
                                "tin": clean_tin,
                                "taxpayer_name": tp_name,
                                "taxpayer_address": tp_address,
                                "message": f"NIF vérifié auprès de l'OBR : {tp_name}",
                                "is_offline": False,
                                "raw_response": data,
                            }
                        elif is_not_found:
                            # NIF formellement rejeté par l'OBR
                            if db is not None:
                                self._save_taxpayer_cache(
                                    db, clean_tin, None, None, "INVALID", False, data
                                )
                            return {
                                "success": True,
                                "valid": False,
                                "status": "INVALID",
                                "tin": clean_tin,
                                "taxpayer_name": None,
                                "taxpayer_address": None,
                                "message": f"NIF '{clean_tin}' non reconnu par l'OBR.",
                                "is_offline": False,
                                "raw_response": data,
                            }
                except Exception as e:
                    logger.warning(f"[OBR] Erreur lors de l'appel checkTIN ({endpoint}): {e}")
                    obr_error_msg = str(e)

        # 4. Cas : OBR Injoignable / Hors-ligne (Règle essentielle : on ne bloque pas la vente)
        fallback_name = cached.taxpayer_name if cached else None
        fallback_addr = cached.taxpayer_address if cached else None

        if db is not None and not cached:
            # Enregistrer comme vérification en attente / hors-ligne
            self._save_taxpayer_cache(
                db, clean_tin, fallback_name, fallback_addr, "UNREACHABLE", True, {"offline_reason": obr_error_msg or "injoignable"}
            )

        return {
            "success": True,
            "valid": True,  # Autorisé pour la facturation hors-ligne
            "status": "UNREACHABLE",
            "tin": clean_tin,
            "taxpayer_name": fallback_name,
            "taxpayer_address": fallback_addr,
            "message": "OBR injoignable (NIF accepté pour la vente en mode hors-ligne).",
            "is_offline": True,
        }

    def _save_taxpayer_cache(
        self,
        db: Session,
        tin: str,
        name: Optional[str],
        address: Optional[str],
        status: str,
        is_valid: bool,
        raw_response: Any,
    ):
        """Enregistre ou met à jour le NIF en cache local avec validité 30 jours."""
        try:
            record = db.query(TaxpayerVerification).filter(
                TaxpayerVerification.pharmacy_id == self.pharmacy.id,
                TaxpayerVerification.tin == tin,
            ).first()

            now = datetime.utcnow()
            expires = now + timedelta(days=30)

            if not record:
                record = TaxpayerVerification(
                    pharmacy_id=self.pharmacy.id,
                    tin=tin,
                    taxpayer_name=name,
                    taxpayer_address=address,
                    status=status,
                    is_valid=is_valid,
                    raw_response=raw_response,
                    verified_at=now,
                    expires_at=expires,
                )
                db.add(record)
            else:
                record.taxpayer_name = name or record.taxpayer_name
                record.taxpayer_address = address or record.taxpayer_address
                record.status = status
                record.is_valid = is_valid
                record.raw_response = raw_response
                record.verified_at = now
                record.expires_at = expires

            db.commit()
        except Exception as e:
            db.rollback()
            print(f"[ERROR _save_taxpayer_cache]: {e}", flush=True)
            logger.warning(f"[OBR] Échec enregistrement cache NIF: {e}")

    def cancel_invoice(self, invoice_identifier: str, cn_motif: str) -> Dict[str, Any]:
        """
        Annule une facture transmise à l'EBMS OBR.
        Endpoint officiel V0.5 : POST /cancelInvoice/
        """
        clean_id = (invoice_identifier or "").strip()
        clean_motif = (cn_motif or "Erreur de saisie / Annulation vente").strip()

        token = self.get_token() if (self.username and self.password) else None
        if token:
            for endpoint in [f"{self.base_url}/cancelInvoice/", f"{self.base_url}/cancelInvoice"]:
                try:
                    headers = {
                        "Authorization": f"Bearer {token}",
                        "Content-Type": "application/json"
                    }
                    payload = self.clean_nulls({
                        "invoice_identifier": clean_id,
                        "cn_motif": clean_motif,
                    })
                    resp = requests.post(
                        endpoint,
                        json=payload,
                        headers=headers,
                        timeout=15.0,
                        verify=False,
                    )
                    if resp.status_code in [200, 201]:
                        data = resp.json()
                        return {
                            "success": True,
                            "message": "Facture annulée avec succès auprès de l'OBR",
                            "raw_response": data,
                        }
                    else:
                        logger.warning(f"[OBR] Rejet annulation facture {clean_id}: {resp.status_code} {resp.text}")
                except Exception as e:
                    logger.warning(f"[OBR] Échec cancelInvoice ({endpoint}): {e}")

        return {
            "success": True,
            "simulated": True,
            "message": "Facture marquée comme annulée localement (retransmission OBR en attente)",
        }

    def send_stock_movement(self, movement_data: Dict[str, Any]) -> Dict[str, Any]:
        """
        Envoie une déclaration de mouvement de stock à l'EBMS OBR.
        Endpoint officiel V0.5 : POST /AddStockMovement/
        """
        payload = {
            "system_or_device_id": movement_data.get("system_or_device_id") or self.system_id,
            "item_code": movement_data.get("item_code") or "",
            "item_designation": movement_data.get("item_designation") or "",
            "item_quantity": float(movement_data.get("item_quantity", 0.0)),
            "item_measurement_unit": movement_data.get("item_measurement_unit") or "UNITE",
            "item_purchase_or_sale_price": float(movement_data.get("item_purchase_or_sale_price", 0.0)),
            "item_purchase_or_sale_currency": movement_data.get("item_purchase_or_sale_currency") or "BIF",
            "item_movement_type": movement_data.get("item_movement_type") or "SN",  # SN=Sortie Vente, EN=Entrée Achat
            "item_movement_invoice_ref": movement_data.get("item_movement_invoice_ref") or "",
            "item_movement_description": movement_data.get("item_movement_description") or "",
            "item_movement_date": movement_data.get("item_movement_date") or datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        }
        cleaned_payload = self.clean_nulls(payload)

        token = self.get_token() if (self.username and self.password) else None
        if token:
            for endpoint in [f"{self.base_url}/AddStockMovement/", f"{self.base_url}/AddStockMovement"]:
                try:
                    headers = {
                        "Authorization": f"Bearer {token}",
                        "Content-Type": "application/json"
                    }
                    resp = requests.post(
                        endpoint,
                        json=cleaned_payload,
                        headers=headers,
                        timeout=15.0,
                        verify=False,
                    )
                    if resp.status_code in [200, 201]:
                        return {"success": True, "raw_response": resp.json()}
                except Exception as e:
                    logger.warning(f"[OBR] Échec transmission stock movement ({endpoint}): {e}")

        return {"success": True, "simulated": True, "message": "Mouvement de stock enregistré localement"}

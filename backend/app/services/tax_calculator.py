"""
Tax and Fiscal Calculation Engine conforming to OBR (Office Burundais des Recettes) rules.
"""

from typing import List, Dict, Any


class TaxCalculator:
    """Calculateur fiscal pour les ventes de pharmacie conformément à l'EBMS de l'OBR."""

    @staticmethod
    def compute_item_tax(
        unit_price: float,
        quantity: float,
        tax_rate: float = 0.0,
        discount_percent: float = 0.0,
        item_ct: float = 0.0,
        item_tl: float = 0.0,
    ) -> Dict[str, float]:
        """
        Calcule les montants HT, TVA et TTC pour une ligne d'article.
        
        Args:
            unit_price: Prix unitaire de vente (TTC ou net selon saisie comptoir)
            quantity: Quantité vendue
            tax_rate: Taux de TVA (0.0 pour exonéré, 18.0 pour taux standard)
            discount_percent: Remise accordée en % (0 à 100)
            item_ct: Taxe de consommation
            item_tl: Taxe de loterie / prélèvement
            
        Returns:
            Dict avec item_price_nvat, vat_amount, item_price_wvat, item_total_amount
        """
        raw_total = unit_price * quantity
        if discount_percent > 0:
            discount_amount = raw_total * (discount_percent / 100.0)
            net_after_discount = max(0.0, raw_total - discount_amount)
        else:
            net_after_discount = raw_total

        # Si le prix catalogue en pharmacie est généralement TTC :
        # Pour les médicaments (Taux 0%), HT = TTC.
        # Pour la parapharmacie (Taux 18%), HT = TTC / 1.18, TVA = TTC - HT.
        if tax_rate > 0.0:
            price_nvat = round(net_after_discount / (1.0 + (tax_rate / 100.0)), 2)
            vat_amount = round(net_after_discount - price_nvat, 2)
            price_wvat = round(net_after_discount, 2)
        else:
            price_nvat = round(net_after_discount, 2)
            vat_amount = 0.0
            price_wvat = round(net_after_discount, 2)

        total_amount = round(price_wvat + item_ct + item_tl, 2)

        return {
            "item_price_nvat": price_nvat,
            "vat_amount": vat_amount,
            "item_price_wvat": price_wvat,
            "item_total_amount": total_amount,
            "tax_rate": tax_rate,
        }

    @staticmethod
    def compute_sale_tax_summary(items_tax_data: List[Dict[str, Any]]) -> Dict[str, float]:
        """
        Agrège la ventilation fiscale pour l'ensemble d'une facture.
        
        Returns:
            total_nvat: Total Hors TVA
            total_exempt: Base exonérée (TVA 0%)
            total_taxable_18: Base taxable à 18%
            total_vat_18: Montant total de la TVA 18%
            total_ct: Total taxes de consommation
            total_tl: Total taxes de loterie
            total_wvat: Total TTC
        """
        total_nvat = 0.0
        total_exempt = 0.0
        total_taxable_18 = 0.0
        total_vat_18 = 0.0
        total_ct = 0.0
        total_tl = 0.0
        total_wvat = 0.0

        for item in items_tax_data:
            tax_rate = item.get("tax_rate", 0.0)
            nvat = item.get("item_price_nvat", 0.0)
            vat = item.get("vat_amount", 0.0)
            wvat = item.get("item_price_wvat", 0.0)
            ct = item.get("item_ct", 0.0)
            tl = item.get("item_tl", 0.0)

            total_nvat += nvat
            total_wvat += wvat
            total_ct += ct
            total_tl += tl

            if tax_rate == 0.0:
                total_exempt += nvat
            elif abs(tax_rate - 18.0) < 0.1:
                total_taxable_18 += nvat
                total_vat_18 += vat
            else:
                total_taxable_18 += nvat
                total_vat_18 += vat

        return {
            "total_nvat": round(total_nvat, 2),
            "total_exempt": round(total_exempt, 2),
            "total_taxable_18": round(total_taxable_18, 2),
            "total_vat_18": round(total_vat_18, 2),
            "total_ct": round(total_ct, 2),
            "total_tl": round(total_tl, 2),
            "total_wvat": round(total_wvat, 2),
        }

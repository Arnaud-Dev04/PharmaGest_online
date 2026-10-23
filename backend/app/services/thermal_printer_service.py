"""
Thermal Printer Service — ESC/POS & Text Receipt Generator (58mm / 80mm).
"""

from typing import Dict, Any, List
from datetime import datetime


def _line(char: str, width_chars: int) -> str:
    return char * width_chars + "\n"


def _format_row(left: str, right: str, width_chars: int) -> str:
    space = width_chars - len(left) - len(right)
    if space < 1:
        left = left[: width_chars - len(right) - 1]
        space = 1
    return f"{left}{' ' * space}{right}\n"


def generate_text_receipt(sale_data: Dict[str, Any], pharmacy_name: str = "Pharmacie", width_mm: int = 58) -> str:
    """
    Génère un ticket de caisse textuel aligné.
    58mm = 32 caractères par ligne standard.
    80mm = 42 caractères par ligne standard.
    """
    width = 32 if width_mm == 58 else 42
    out = []

    # En-tête centré
    out.append(pharmacy_name.center(width) + "\n")
    out.append("TICKET DE CAISSE".center(width) + "\n")
    out.append(_line("=", width))

    # Métadonnées
    code = sale_data.get("code", "")
    date_str = sale_data.get("date", datetime.utcnow().strftime("%Y-%m-%d %H:%M"))
    if isinstance(date_str, datetime):
        date_str = date_str.strftime("%Y-%m-%d %H:%M")
    out.append(_format_row("Facture:", code, width))
    out.append(_format_row("Date:", str(date_str)[:16], width))

    cust_name = sale_data.get("customer_name")
    if cust_name:
        out.append(_format_row("Client:", str(cust_name)[:width - 8], width))

    out.append(_line("-", width))
    out.append(_format_row("Article / Qte", "Total", width))
    out.append(_line("-", width))

    # Lignes d'articles
    items = sale_data.get("items", [])
    for it in items:
        nom = it.get("medicine_name") or it.get("name") or "Article"
        qty = it.get("quantity", 1)
        tot = it.get("total_price", 0.0)
        out.append(f"{nom[:width]}\n")
        out.append(_format_row(f"  {qty} x {it.get('unit_price', 0):.0f}", f"{tot:.0f} FBu", width))

    out.append(_line("=", width))
    total_amt = sale_data.get("total_amount", 0.0)
    out.append(_format_row("TOTAL:", f"{total_amt:.0f} FBu", width))
    pm = sale_data.get("payment_method", "cash").upper()
    out.append(_format_row("Mode règlement:", pm, width))
    out.append(_line("-", width))

    # Pied de page
    out.append("Merci pour votre confiance !".center(width) + "\n")
    out.append("Bonne guerison".center(width) + "\n\n\n")

    return "".join(out)


def generate_escpos_receipt(sale_data: Dict[str, Any], pharmacy_name: str = "Pharmacie", width_mm: int = 58) -> bytes:
    """
    Génère un flux d'octets ESC/POS binaire pour imprimante thermique.
    """
    text_content = generate_text_receipt(sale_data, pharmacy_name, width_mm)

    ESC = b"\x1b"
    GS = b"\x1d"

    buf = bytearray()
    # Initialisation imprimante
    buf.extend(ESC + b"@")
    # Code page standard CP437 ou UTF-8
    buf.extend(ESC + b"t\x00")
    # Corps du ticket encodé
    buf.extend(text_content.encode("latin-1", errors="replace"))
    # Saut de 3 lignes
    buf.extend(b"\n\n\n")
    # Coupure du papier (Cut full)
    buf.extend(GS + b"V\x42\x00")

    return bytes(buf)

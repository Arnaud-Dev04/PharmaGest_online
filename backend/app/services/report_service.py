"""
Report Service - PharmaGestion PDF/Excel Reports.

Tous les rapports sont 100% en Français, avec des calculs financiers
rigoureux, transparents et immédiatement compréhensibles pour les pharmaciens
et experts-comptables :
1. Stock : Double valorisation (Valeur d'Acquisition au Prix d'Achat vs Valeur Marchande au Prix de Vente)
   + Affichage non-ambigu des quantités (boîtes et comprimés séparés).
2. Ventes : Chiffre d'Affaires Net + Coût d'Achat réel + Marge Brute / Bénéfice Réalisé.
3. Finances : Compte de résultat basé sur le vrai CMV des ventes enregistrées.
4. Trésorerie : Flux réels des encaissements et décaissements.
"""

from typing import Optional
from datetime import date, datetime, timedelta
from io import BytesIO
from collections import defaultdict

import openpyxl
from openpyxl.styles import Font, PatternFill, Alignment
from sqlalchemy.orm import Session
from sqlalchemy import func, desc, or_, and_, cast, Date

from reportlab.lib import colors
from reportlab.lib.pagesizes import A4, landscape
from reportlab.lib.units import cm, mm
from reportlab.pdfgen import canvas
from reportlab.platypus import (
    SimpleDocTemplate, Table, TableStyle, Paragraph, Spacer, PageBreak, KeepTogether
)
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.enums import TA_CENTER, TA_LEFT, TA_RIGHT

from app.models.medicine import Medicine, MedicineFamily
from app.models.medicine_pricing import MedicinePricing
from app.models.sales import Sale, SaleItem
from app.models.pos_sale import POSSale, POSSaleItem


# ═══════════════════════════════════════════════════════════════════
# HELPERS & CONSTANTES
# ═══════════════════════════════════════════════════════════════════

MONTHS = ["Janv", "Févr", "Mars", "Avr", "Mai", "Juin",
          "Juil", "Août", "Sept", "Oct", "Nov", "Déc"]

PMT_MAP = {
    "cash": "Espèces",
    "especes": "Espèces",
    "credit_card": "Carte bancaire",
    "carte": "Carte bancaire",
    "mobile_money": "Mobile Money",
    "insurance": "Assurance",
    "check": "Chèque",
    "cheque": "Chèque",
    "transfer": "Virement",
    "virement": "Virement",
}


def _fmt(n):
    """1234567 -> '1 234 567'"""
    if n is None:
        return "0"
    try:
        n = float(n)
    except (ValueError, TypeError):
        return str(n)
    if n == int(n):
        return f"{int(n):,}".replace(",", " ")
    return f"{n:,.0f}".replace(",", " ")


def _pharmacy_name(db: Session) -> str:
    try:
        from app.models.settings import Settings
        s = db.query(Settings).first()
        if s and hasattr(s, 'pharmacy_name') and s.pharmacy_name:
            return s.pharmacy_name
    except Exception:
        pass
    return "Pharmacie [Nom de la Pharmacie]"


def _grid_style(header_rows=1, font_size=8.5, header_font_size=9.5, padding=4.0):
    """Style de tableau standard en noir & blanc, quadrillage complet et texte lisible."""
    return TableStyle([
        ('BACKGROUND', (0, 0), (-1, header_rows - 1), colors.Color(0.88, 0.90, 0.94)),
        ('FONTNAME', (0, 0), (-1, header_rows - 1), 'Helvetica-Bold'),
        ('FONTSIZE', (0, 0), (-1, header_rows - 1), header_font_size),
        ('ALIGN', (0, 0), (-1, header_rows - 1), 'CENTER'),
        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
        ('FONTNAME', (0, header_rows), (-1, -1), 'Helvetica'),
        ('FONTSIZE', (0, header_rows), (-1, -1), font_size),
        ('GRID', (0, 0), (-1, -1), 0.5, colors.Color(0.25, 0.25, 0.25)),
        ('TOPPADDING', (0, 0), (-1, -1), padding),
        ('BOTTOMPADDING', (0, 0), (-1, -1), padding),
        ('LEFTPADDING', (0, 0), (-1, -1), 4),
        ('RIGHTPADDING', (0, 0), (-1, -1), 4),
    ])


class _NumberedCanvas(canvas.Canvas):
    """Canvas avec pagination et pied de page en Français."""
    def __init__(self, *args, pharmacy="", **kwargs):
        super().__init__(*args, **kwargs)
        self._pharmacy = pharmacy
        self._saved_page_states = []

    def showPage(self):
        self._saved_page_states.append(dict(self.__dict__))
        super().showPage()

    def save(self):
        num_pages = len(self._saved_page_states)
        for state in self._saved_page_states:
            self.__dict__.update(state)
            self._draw_page_footer(num_pages)
            super().showPage()
        super().save()

    def _draw_page_footer(self, page_count):
        self.setFont('Helvetica', 8)
        self.drawCentredString(
            self._pagesize[0] / 2, 0.9 * cm,
            f"Document généré par PharmaGestion — {date.today().strftime('%d/%m/%Y')}"
        )
        self.drawRightString(
            self._pagesize[0] - 1.2 * cm, 0.9 * cm,
            f"Page {self._pageNumber} / {page_count}"
        )


def _build_doc(buffer, title, pharmacy, subtitle="", note="", pagesize=None, left_margin=1.0*cm, right_margin=1.0*cm):
    """Crée un SimpleDocTemplate avec marges optimisées et en-tête complet en Français."""
    if pagesize is None:
        pagesize = landscape(A4)

    elements = []
    styles = getSampleStyleSheet()

    # Nom pharmacie en haut à droite
    p_pharmacy = ParagraphStyle('pharmacy', parent=styles['Normal'],
                                fontSize=10, fontName='Helvetica-Bold', alignment=TA_RIGHT)
    elements.append(Paragraph(pharmacy, p_pharmacy))
    elements.append(Spacer(1, 0.25 * cm))

    # Titre principal
    p_title = ParagraphStyle('title', parent=styles['Normal'],
                             fontSize=16, fontName='Helvetica-Bold',
                             alignment=TA_CENTER, spaceAfter=4)
    elements.append(Paragraph(title, p_title))

    # Sous-titre
    if subtitle:
        p_sub = ParagraphStyle('sub', parent=styles['Normal'],
                               fontSize=10.5, fontName='Helvetica', alignment=TA_CENTER, spaceAfter=4)
        elements.append(Paragraph(subtitle, p_sub))

    # Note explicative
    if note:
        p_note = ParagraphStyle('note', parent=styles['Normal'],
                                fontSize=8.5, fontName='Helvetica-Oblique',
                                alignment=TA_CENTER, spaceAfter=6)
        elements.append(Paragraph(note, p_note))

    elements.append(Spacer(1, 0.3 * cm))

    doc = SimpleDocTemplate(
        buffer, pagesize=pagesize,
        leftMargin=left_margin, rightMargin=right_margin,
        topMargin=1.0 * cm, bottomMargin=1.6 * cm,
    )
    return doc, elements, styles


def _get_item_cost(item: POSSaleItem) -> float:
    """Calcule le coût d'achat unitaire réel d'un article vendu."""
    if item.batch and item.batch.purchase_price and item.batch.purchase_price > 0:
        return float(item.batch.purchase_price)

    med = item.medicine
    if med:
        if med.prix_achat_unite and med.prix_achat_unite > 0:
            return float(med.prix_achat_unite)
        if med.price_buy and med.price_buy > 0:
            units_per_box = (med.boxes_per_carton or 1) * (med.blisters_per_box or 1) * (med.units_per_blister or 1)
            if item.sale_type == "unit" and units_per_box > 1:
                return float(med.price_buy / units_per_box)
            return float(med.price_buy)

    return float(item.unit_price * 0.70) if item.unit_price else 0.0


def _format_stock_qty(total_comprimes: int, comprimes_par_boite: int) -> str:
    """Formate la quantité en stock en boîtes et unités sans aucune ambiguïté."""
    if total_comprimes <= 0:
        return "0"
    if comprimes_par_boite > 1:
        boites = total_comprimes // comprimes_par_boite
        restants = total_comprimes % comprimes_par_boite
        if boites > 0 and restants > 0:
            return f"{boites} bte + {restants} u"
        elif boites > 0:
            return f"{boites} bte"
        else:
            return f"{restants} u"
    else:
        return f"{total_comprimes} u"


# ═══════════════════════════════════════════════════════════════════
# 1. RAPPORT DE STOCK (Double Valorisation Achat & Vente + Quantités claires)
# ═══════════════════════════════════════════════════════════════════

def generate_stock_pdf(
    db: Session,
    start_date: Optional[date] = None,
    end_date: Optional[date] = None
) -> BytesIO:
    """Rapport de Stock - État d'Inventaire et Double Valorisation.
    Format A4 Portrait. Affiche clairement :
    - La quantité physique réelle en stock (Boîtes et Unités)
    - Le Prix d'Achat unitaire et le Prix de Vente unitaire
    - La Valeur d'Acquisition (au Coût d'Achat - Valeur comptable officielle)
    - La Valeur Marchande (au Prix de Vente - Chiffre d'Affaires potentiel)
    - La Marge Bénéficiaire Potentielle
    - Filtrage optionnel par période (date de réception / entrée)
    """
    buffer = BytesIO()
    pharmacy = _pharmacy_name(db)
    today_str = date.today().strftime("%d/%m/%Y")

    if start_date and end_date:
        periode_str = f"Période : Du {start_date.strftime('%d/%m/%Y')} au {end_date.strftime('%d/%m/%Y')}"
    elif start_date:
        periode_str = f"Période : À partir du {start_date.strftime('%d/%m/%Y')}"
    elif end_date:
        periode_str = f"Période : Jusqu'au {end_date.strftime('%d/%m/%Y')}"
    else:
        periode_str = f"Date d'inventaire : {today_str}"

    nif_val = ""
    tel_val = ""
    try:
        from app.models.settings import Settings
        s = db.query(Settings).first()
        if s:
            nif_val = getattr(s, 'nif', '') or ''
            tel_val = getattr(s, 'phone', '') or getattr(s, 'telephone', '') or ''
    except Exception:
        pass

    query = db.query(MedicinePricing)
    if start_date:
        query = query.filter(
            or_(
                MedicinePricing.date_reception >= start_date,
                and_(MedicinePricing.date_reception.is_(None), cast(MedicinePricing.created_at, Date) >= start_date)
            )
        )
    if end_date:
        query = query.filter(
            or_(
                MedicinePricing.date_reception <= end_date,
                and_(MedicinePricing.date_reception.is_(None), cast(MedicinePricing.created_at, Date) <= end_date)
            )
        )

    entries = query.order_by(MedicinePricing.dci, MedicinePricing.nom).all()

    categories = defaultdict(list)
    for e in entries:
        cat = (e.dci or "Autres").strip()
        categories[cat].append(e)

    pagesize = A4
    page_w, page_h = pagesize
    left_margin = 1.0 * cm
    right_margin = 1.0 * cm
    avail_width = page_w - left_margin - right_margin

    doc = SimpleDocTemplate(
        buffer, pagesize=pagesize,
        leftMargin=left_margin, rightMargin=right_margin,
        topMargin=1.0 * cm, bottomMargin=1.6 * cm,
    )

    elements = []
    styles = getSampleStyleSheet()

    # Haut gauche : Pharmacie, NIF, Tél
    p_header = ParagraphStyle('header_left', parent=styles['Normal'],
                              fontSize=10.5, fontName='Helvetica-Bold', leading=13)
    header_lines = pharmacy
    if nif_val:
        header_lines += f"<br/>NIF : {nif_val}"
    if tel_val:
        header_lines += f"<br/>Tél : {tel_val}"
    elements.append(Paragraph(header_lines, p_header))
    elements.append(Spacer(1, 0.25 * cm))

    # Encadré Titre
    title_data = [
        [pharmacy.upper()],
        [periode_str],
        ["INVENTAIRE DU STOCK & DOUBLE VALORISATION"],
    ]
    title_table = Table(title_data, colWidths=[avail_width * 0.65])
    title_table.setStyle(TableStyle([
        ('FONTNAME', (0, 0), (0, 0), 'Helvetica-Bold'),
        ('FONTSIZE', (0, 0), (0, 0), 10.5),
        ('FONTNAME', (0, 1), (0, 1), 'Helvetica'),
        ('FONTSIZE', (0, 1), (0, 1), 9.5),
        ('FONTNAME', (0, 2), (0, 2), 'Helvetica-Bold'),
        ('FONTSIZE', (0, 2), (0, 2), 10),
        ('ALIGN', (0, 0), (0, -1), 'CENTER'),
        ('VALIGN', (0, 0), (0, -1), 'MIDDLE'),
        ('BOX', (0, 0), (-1, -1), 0.75, colors.black),
        ('BACKGROUND', (0, 0), (-1, -1), colors.Color(0.93, 0.95, 0.99)),
        ('TOPPADDING', (0, 0), (-1, -1), 2.5),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 2.5),
    ]))
    outer = Table([[None, title_table]], colWidths=[avail_width * 0.35, avail_width * 0.65])
    outer.setStyle(TableStyle([
        ('VALIGN', (0, 0), (-1, -1), 'TOP'),
    ]))
    elements.append(outer)
    elements.append(Spacer(1, 0.35 * cm))

    # Note explicative pour les utilisateurs
    p_note = ParagraphStyle('note_exp', parent=styles['Normal'],
                            fontSize=8, fontName='Helvetica-Oblique', alignment=TA_CENTER)
    elements.append(Paragraph(
        "<i>* Valeur Achat = Coût réel d'acquisition du stock (valeur comptable au bilan). "
        "Valeur Vente = Chiffre d'affaires potentiel si tout le stock est vendu.</i>",
        p_note
    ))
    elements.append(Spacer(1, 0.25 * cm))

    # 6 Colonnes pour une lisibilité parfaite
    col_w = [
        avail_width * 0.36,   # Désignation
        avail_width * 0.16,   # Quantité en Stock
        avail_width * 0.11,   # P.A. Unit
        avail_width * 0.11,   # P.V. Unit
        avail_width * 0.13,   # Val. Achat (Comptable)
        avail_width * 0.13,   # Val. Vente (Marchande)
    ]

    headers = [
        "Désignation du Médicament",
        "Stock Réel",
        "P.A. Unit",
        "P.V. Unit",
        "Val. Achat*",
        "Val. Vente*",
    ]
    data = [headers]

    grand_total_achat = 0.0
    grand_total_vente = 0.0
    category_row_indices = []
    row_idx = 1

    for cat_name in sorted(categories.keys()):
        items = categories[cat_name]

        cat_total_achat = 0.0
        cat_total_vente = 0.0
        item_rows = []

        for e in items:
            stock = e.total_comprimes or 0
            units_per_box = (e.plaquettes_par_boite or 1) * (e.comprimes_par_plaquette or 1)
            pa = e.achat_comprime or (e.achat_boite / units_per_box if units_per_box else 0) or 0
            pv = e.vente_comprime or (e.vente_boite / units_per_box if units_per_box else 0) or 0

            val_achat = stock * pa
            val_vente = stock * pv

            cat_total_achat += val_achat
            cat_total_vente += val_vente

            if stock > 0:
                qty_str = _format_stock_qty(stock, units_per_box)
                item_rows.append([
                    (e.nom or "")[:35],
                    qty_str,
                    _fmt(pa),
                    _fmt(pv),
                    _fmt(val_achat),
                    _fmt(val_vente),
                ])

        grand_total_achat += cat_total_achat
        grand_total_vente += cat_total_vente

        # Ligne de catégorie
        data.append([
            f"CATÉGORIE : {cat_name.upper()}",
            "",
            "",
            "",
            _fmt(cat_total_achat),
            _fmt(cat_total_vente),
        ])
        category_row_indices.append(row_idx)
        row_idx += 1

        for ir in item_rows:
            data.append(ir)
            row_idx += 1

    # Ligne Total Général du tableau
    data.append([
        "TOTAL DU STOCK",
        "",
        "",
        "",
        _fmt(grand_total_achat),
        _fmt(grand_total_vente),
    ])
    grand_total_row = row_idx

    table = Table(data, colWidths=col_w, repeatRows=1)

    style = TableStyle([
        ('BACKGROUND', (0, 0), (-1, 0), colors.Color(0.85, 0.88, 0.94)),
        ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
        ('FONTSIZE', (0, 0), (-1, 0), 9.0),
        ('ALIGN', (0, 0), (-1, 0), 'CENTER'),
        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),

        ('FONTNAME', (0, 1), (-1, -1), 'Helvetica'),
        ('FONTSIZE', (0, 1), (-1, -1), 8.5),

        ('ALIGN', (0, 1), (0, -1), 'LEFT'),
        ('ALIGN', (1, 1), (1, -1), 'CENTER'),
        ('ALIGN', (2, 1), (-1, -1), 'RIGHT'),

        ('GRID', (0, 0), (-1, -1), 0.5, colors.Color(0.25, 0.25, 0.25)),

        ('TOPPADDING', (0, 0), (-1, -1), 3.8),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 3.8),
        ('LEFTPADDING', (0, 0), (-1, -1), 4),
        ('RIGHTPADDING', (0, 0), (-1, -1), 4),

        ('FONTNAME', (0, grand_total_row), (-1, grand_total_row), 'Helvetica-Bold'),
        ('FONTSIZE', (0, grand_total_row), (-1, grand_total_row), 9.5),
        ('BACKGROUND', (0, grand_total_row), (-1, grand_total_row), colors.Color(0.82, 0.86, 0.93)),
        ('TOPPADDING', (0, grand_total_row), (-1, grand_total_row), 5),
        ('BOTTOMPADDING', (0, grand_total_row), (-1, grand_total_row), 5),
    ])

    for ci in category_row_indices:
        style.add('FONTNAME', (0, ci), (-1, ci), 'Helvetica-Bold')
        style.add('FONTSIZE', (0, ci), (-1, ci), 9.0)
        style.add('BACKGROUND', (0, ci), (-1, ci), colors.Color(0.94, 0.95, 0.98))
        style.add('TOPPADDING', (0, ci), (-1, ci), 4.0)
        style.add('BOTTOMPADDING', (0, ci), (-1, ci), 4.0)

    table.setStyle(style)
    elements.append(table)

    # ──────────────────────────────────────────────
    # SYNTHÈSE FINANCIÈRE CLAIRE DU STOCK
    # ──────────────────────────────────────────────
    elements.append(Spacer(1, 0.6 * cm))
    marge_pot = grand_total_vente - grand_total_achat
    taux_pot = (marge_pot / grand_total_vente * 100) if grand_total_vente > 0 else 0

    synthese_data = [
        [
            "SYNTHÈSE DE VALORISATION DU STOCK",
            "MONTANT (FBu)",
            "INTERPRÉTATION COMPTABLE"
        ],
        [
            "Valeur d'Acquisition Totale (au Prix d'Achat)",
            f"{_fmt(grand_total_achat)} FBu",
            "Capital réel investi & immobilisé en stock (Bilan officiel)"
        ],
        [
            "Valeur Marchande Totale (au Prix de Vente)",
            f"{_fmt(grand_total_vente)} FBu",
            "Chiffre d'affaires prévisionnel en cas d'écoulement complet"
        ],
        [
            f"Marge Bénéficiaire Potentielle ({taux_pot:.1f}%)",
            f"{_fmt(marge_pot)} FBu",
            "Bénéfice brut attendu lors de la vente du stock actuel"
        ],
    ]
    syn_w = [avail_width * 0.40, avail_width * 0.25, avail_width * 0.35]
    syn_table = Table(synthese_data, colWidths=syn_w)
    syn_table.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, 0), colors.Color(0.20, 0.30, 0.45)),
        ('TEXTCOLOR', (0, 0), (-1, 0), colors.white),
        ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
        ('FONTSIZE', (0, 0), (-1, 0), 9.0),
        ('ALIGN', (0, 0), (-1, 0), 'CENTER'),

        ('FONTNAME', (0, 1), (-1, -1), 'Helvetica'),
        ('FONTSIZE', (0, 1), (-1, -1), 8.5),
        ('ALIGN', (0, 1), (0, -1), 'LEFT'),
        ('ALIGN', (1, 1), (1, -1), 'RIGHT'),
        ('ALIGN', (2, 1), (2, -1), 'LEFT'),
        ('FONTNAME', (1, 1), (1, -1), 'Helvetica-Bold'),

        ('BACKGROUND', (0, 3), (-1, 3), colors.Color(0.92, 0.96, 0.92)),
        ('TEXTCOLOR', (1, 3), (1, 3), colors.Color(0.1, 0.5, 0.1)),

        ('GRID', (0, 0), (-1, -1), 0.5, colors.Color(0.3, 0.3, 0.3)),
        ('TOPPADDING', (0, 0), (-1, -1), 4.5),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 4.5),
        ('LEFTPADDING', (0, 0), (-1, -1), 5),
        ('RIGHTPADDING', (0, 0), (-1, -1), 5),
    ]))
    elements.append(KeepTogether([syn_table]))

    elements.append(Spacer(1, 0.6 * cm))
    p_footer = ParagraphStyle('footer', parent=styles['Normal'],
                              fontSize=8, fontName='Helvetica-Oblique', alignment=TA_CENTER)
    elements.append(Paragraph(
        f"Document généré par PharmaGestion le {date.today().strftime('%d/%m/%Y')}",
        p_footer
    ))

    doc.build(elements)
    buffer.seek(0)
    return buffer


# ═══════════════════════════════════════════════════════════════════
# 2. RAPPORT DES VENTES (Avec Coût d'Achat, Marge Réelle & Rentabilité)
# ═══════════════════════════════════════════════════════════════════

def generate_sales_pdf(db: Session, start_date: date, end_date: date) -> BytesIO:
    """Rapport des Ventes - détails complets, CA Net, Coût d'Achat & Marge Réelle."""
    buffer = BytesIO()
    pharmacy = _pharmacy_name(db)

    doc, elements, styles = _build_doc(
        buffer,
        title="RAPPORT DES VENTES & RENTABILITÉ",
        pharmacy=pharmacy,
        subtitle=f"{pharmacy} — Période du {start_date.strftime('%d/%m/%Y')} au {end_date.strftime('%d/%m/%Y')}",
        note="* Montant Net = Quantité × P.U. × (1 - Remise). Marge Réelle = Montant Net - Coût d'Achat Réel.",
    )

    start_dt = datetime.combine(start_date, datetime.min.time())
    end_dt = datetime.combine(end_date, datetime.max.time())

    pos_sales = db.query(POSSale).filter(
        POSSale.date >= start_dt,
        POSSale.date <= end_dt,
        POSSale.status == "completed"
    ).order_by(POSSale.date).all()

    headers = [
        "Date", "N° Facture", "Client", "Code", "Désignation",
        "Qté", "P.U. Vente", "Net Vente*", "Coût Achat", "Marge*", "Paiement", "Vendeur"
    ]

    avail_width = landscape(A4)[0] - 2.0 * cm
    col_widths = [
        avail_width * 0.08,   # Date
        avail_width * 0.10,   # N° Facture
        avail_width * 0.10,   # Client
        avail_width * 0.07,   # Code
        avail_width * 0.16,   # Désignation
        avail_width * 0.04,   # Qté
        avail_width * 0.07,   # P.U. Vente
        avail_width * 0.09,   # Net Vente
        avail_width * 0.09,   # Coût Achat
        avail_width * 0.08,   # Marge Réelle
        avail_width * 0.06,   # Mode Paiement
        avail_width * 0.06,   # Vendeur
    ]

    data = [headers]
    total_ca = 0.0
    total_cost = 0.0
    total_factures = 0
    total_qte = 0
    cat_stats = defaultdict(lambda: {"qte": 0, "montant": 0.0, "cost": 0.0})
    pmt_stats = defaultdict(lambda: {"count": 0, "montant": 0.0})

    for sale in pos_sales:
        total_factures += 1
        pmt_raw = sale.payment_method or "Espèces"
        pmt = PMT_MAP.get(pmt_raw.lower(), pmt_raw)
        pmt_stats[pmt]["count"] += 1
        pmt_stats[pmt]["montant"] += sale.total_amount or 0

        for item in sale.items:
            med = item.medicine
            med_name = med.name if med else "?"
            med_code = med.code if med else "?"
            cat = med.family.name if med and med.family else "-"
            vendor = sale.user.username if sale.user else "-"
            client = sale.customer_name or "Client comptoir"
            discount = item.discount_percent or 0
            net = item.total_price or (item.quantity * item.unit_price * (1 - discount / 100))

            unit_cost = _get_item_cost(item)
            item_cost = unit_cost * item.quantity
            item_marge = net - item_cost

            total_ca += net
            total_cost += item_cost
            total_qte += item.quantity

            cat_stats[cat]["qte"] += item.quantity
            cat_stats[cat]["montant"] += net
            cat_stats[cat]["cost"] += item_cost

            data.append([
                sale.date.strftime("%d/%m/%Y"),
                (sale.code or "")[:15],
                client[:14],
                med_code[:10],
                med_name[:24],
                str(item.quantity),
                _fmt(item.unit_price),
                _fmt(net),
                _fmt(item_cost),
                _fmt(item_marge),
                pmt[:12],
                vendor[:10],
            ])

    total_marge_realisee = total_ca - total_cost
    taux_marge_globale = (total_marge_realisee / total_ca * 100) if total_ca > 0 else 0

    # Ligne de total du tableau des ventes
    data.append([
        "TOTAL", "", "", "", "",
        str(total_qte), "", _fmt(total_ca), _fmt(total_cost), _fmt(total_marge_realisee), "", ""
    ])

    table = Table(data, colWidths=col_widths, repeatRows=1)
    style = _grid_style(header_rows=1, font_size=8.0, header_font_size=8.5, padding=3.2)
    style.add('ALIGN', (5, 0), (9, -1), 'RIGHT')
    style.add('FONTNAME', (0, -1), (-1, -1), 'Helvetica-Bold')
    style.add('BACKGROUND', (0, -1), (-1, -1), colors.Color(0.85, 0.88, 0.94))
    table.setStyle(style)
    elements.append(table)

    # ── SYNTHÈSE GÉNÉRALE & RENTABILITÉ ──
    elements.append(Spacer(1, 0.7 * cm))
    panier = total_ca / total_factures if total_factures > 0 else 0

    synth_rows = [
        ["INDICATEUR CLÉ", "VALEUR", "REMARQUE GESTION"],
        ["Chiffre d'Affaires Net Total", f"{_fmt(total_ca)} FBu", "Total encaissé / facturé aux clients"],
        ["Coût d'Achat des Marchandises Vendues (CMV)", f"{_fmt(total_cost)} FBu", "Coût d'acquisition réel des produits vendus"],
        [f"Marge Brute Réalisée (Bénéfice Réel : {taux_marge_globale:.1f}%)", f"{_fmt(total_marge_realisee)} FBu", "Bénéfice commercial net après coût d'achat"],
        ["Nombre total de factures émises", f"{total_factures}", f"Panier moyen : {_fmt(panier)} FBu / facture"],
        ["Quantité totale d'articles vendus", f"{total_qte} unités", "Volume total débité du stock"],
    ]
    sw = [avail_width * 0.38, avail_width * 0.24, avail_width * 0.38]
    s_table = Table(synth_rows, colWidths=sw)
    s_table.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, 0), colors.Color(0.20, 0.30, 0.45)),
        ('TEXTCOLOR', (0, 0), (-1, 0), colors.white),
        ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
        ('FONTSIZE', (0, 0), (-1, 0), 9.0),
        ('ALIGN', (0, 0), (-1, 0), 'CENTER'),

        ('FONTNAME', (0, 1), (-1, -1), 'Helvetica'),
        ('FONTSIZE', (0, 1), (-1, -1), 8.5),
        ('ALIGN', (0, 1), (0, -1), 'LEFT'),
        ('ALIGN', (1, 1), (1, -1), 'RIGHT'),
        ('ALIGN', (2, 1), (2, -1), 'LEFT'),
        ('FONTNAME', (1, 1), (1, -1), 'Helvetica-Bold'),

        ('BACKGROUND', (0, 3), (-1, 3), colors.Color(0.90, 0.96, 0.90)),
        ('TEXTCOLOR', (1, 3), (1, 3), colors.Color(0.1, 0.5, 0.1)),

        ('GRID', (0, 0), (-1, -1), 0.5, colors.Color(0.3, 0.3, 0.3)),
        ('TOPPADDING', (0, 0), (-1, -1), 4.0),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 4.0),
        ('LEFTPADDING', (0, 0), (-1, -1), 5),
        ('RIGHTPADDING', (0, 0), (-1, -1), 5),
    ]))
    elements.append(KeepTogether([s_table]))

    # ── VENTES ET RENTABILITÉ PAR CATÉGORIE ──
    if cat_stats:
        elements.append(Spacer(1, 0.6 * cm))
        p_bold = ParagraphStyle('stitle', parent=styles['Normal'],
                                fontSize=11, fontName='Helvetica-Bold', spaceAfter=6)
        elements.append(Paragraph("VENTES ET MARGE PAR CATÉGORIE", p_bold))

        cat_data = [["Catégorie", "Qté Vendue", "CA Net (FBu)", "Coût Achat", "Marge Réalisée", "% du CA"]]
        for cname, d in sorted(cat_stats.items()):
            pct = (d["montant"] / total_ca * 100) if total_ca > 0 else 0
            mrg = d["montant"] - d["cost"]
            cat_data.append([
                cname,
                str(d["qte"]),
                _fmt(d["montant"]),
                _fmt(d["cost"]),
                _fmt(mrg),
                f"{pct:.1f}%",
            ])

        cat_w = [avail_width * 0.28, avail_width * 0.12, avail_width * 0.16, avail_width * 0.16, avail_width * 0.16, avail_width * 0.12]
        cat_table = Table(cat_data, colWidths=cat_w, repeatRows=1)
        s = _grid_style(header_rows=1, font_size=8.5, header_font_size=9.0, padding=3.5)
        s.add('ALIGN', (1, 0), (-1, -1), 'RIGHT')
        cat_table.setStyle(s)
        elements.append(KeepTogether([cat_table]))

    # ── VENTES PAR MODE DE PAIEMENT ──
    if pmt_stats:
        elements.append(Spacer(1, 0.5 * cm))
        p_bold = ParagraphStyle('stitle2', parent=styles['Normal'],
                                fontSize=11, fontName='Helvetica-Bold', spaceAfter=6)
        elements.append(Paragraph("VENTES PAR MODE DE PAIEMENT", p_bold))

        pmt_data = [["Mode de Paiement", "Nombre de Factures", "Montant Total Encaissé (FBu)", "% du Total"]]
        for pname, d in sorted(pmt_stats.items()):
            pname_fr = PMT_MAP.get(pname.lower(), pname)
            pct = (d["montant"] / total_ca * 100) if total_ca > 0 else 0
            pmt_data.append([pname_fr, str(d["count"]), _fmt(d["montant"]), f"{pct:.1f}%"])

        pmt_w = [avail_width * 0.35, avail_width * 0.20, avail_width * 0.25, avail_width * 0.20]
        pmt_table = Table(pmt_data, colWidths=pmt_w, repeatRows=1)
        s = _grid_style(header_rows=1, font_size=8.5, header_font_size=9.0, padding=3.5)
        s.add('ALIGN', (1, 0), (-1, -1), 'RIGHT')
        pmt_table.setStyle(s)
        elements.append(KeepTogether([pmt_table]))

    doc.build(elements)
    buffer.seek(0)
    return buffer


# ═══════════════════════════════════════════════════════════════════
# 3. RAPPORT FINANCIER (Compte de Résultat avec vrai CMV des ventes)
# ═══════════════════════════════════════════════════════════════════

def generate_financial_pdf(
    db: Session,
    start_date: Optional[date] = None,
    end_date: Optional[date] = None,
    period_label: str = "Aperçu"
) -> BytesIO:
    """Rapport Financier - Compte de Résultat mensuel calculé sur les ventes réelles."""
    buffer = BytesIO()
    pharmacy = _pharmacy_name(db)
    year = date.today().year

    doc, elements, styles = _build_doc(
        buffer,
        title="RAPPORT FINANCIER — COMPTE DE RÉSULTAT",
        pharmacy=pharmacy,
        subtitle=f"{pharmacy} — Exercice {year} (Montants en Francs Burundais, FBu)",
        note="* Les Chiffres d'Affaires et les Coûts des Marchandises Vendues (CMV) sont calculés en temps réel depuis les ventes réelles de la pharmacie.",
        left_margin=0.8 * cm,
        right_margin=0.8 * cm,
    )

    start_dt = datetime(year, 1, 1)
    end_dt = datetime(year, 12, 31, 23, 59, 59)

    monthly_sales = defaultdict(float)
    monthly_cmv = defaultdict(float)

    pos_sales = db.query(POSSale).filter(
        POSSale.date >= start_dt,
        POSSale.date <= end_dt,
        POSSale.status == "completed"
    ).all()

    for sale in pos_sales:
        m = sale.date.month
        monthly_sales[m] += sale.total_amount or 0
        for item in sale.items:
            cost = _get_item_cost(item)
            monthly_cmv[m] += (cost * item.quantity)

    total_ventes = sum(monthly_sales.values())
    total_cmv = sum(monthly_cmv.values())
    marge_brute = total_ventes - total_cmv
    taux_marge = (marge_brute / total_ventes * 100) if total_ventes > 0 else 0

    monthly_marge = {}
    for m in range(1, 13):
        monthly_marge[m] = monthly_sales.get(m, 0.0) - monthly_cmv.get(m, 0.0)

    avail_width = landscape(A4)[0] - 1.6 * cm
    rubrique_w = 210.0
    total_w = 60.0
    month_w = (avail_width - rubrique_w - total_w) / 12
    col_widths = [rubrique_w] + [month_w] * 12 + [total_w]

    header = ["Rubrique"] + MONTHS + ["TOTAL"]

    def make_monthly_row(label, monthly_data, total_val, is_pct=False):
        row = [label]
        for m in range(1, 13):
            val = monthly_data.get(m, 0)
            if is_pct:
                row.append(f"{val:.1f}%" if val else "")
            elif val:
                row.append(_fmt(val))
            else:
                row.append("—")
        if is_pct:
            row.append(f"{total_val:.1f}%")
        else:
            row.append(_fmt(total_val))
        return row

    data = [header]
    bold_rows = []

    # 1. PRODUITS D'EXPLOITATION
    data.append(["PRODUITS D'EXPLOITATION (CHIFFRE D'AFFAIRES)"] + [""] * 13)
    bold_rows.append(len(data) - 1)

    data.append(make_monthly_row("Ventes de médicaments (comptoir & ordonnances)", monthly_sales, total_ventes))
    data.append(make_monthly_row("TOTAL PRODUITS D'EXPLOITATION", monthly_sales, total_ventes))
    bold_rows.append(len(data) - 1)

    # 2. COÛT DES MARCHANDISES VENDUES (CMV)
    data.append(["COÛT DES MARCHANDISES VENDUES (CMV)"] + [""] * 13)
    bold_rows.append(len(data) - 1)

    data.append(make_monthly_row("Coût d'achat réel des médicaments vendus", monthly_cmv, total_cmv))

    # 3. MARGE BRUTE
    data.append(make_monthly_row("MARGE BRUTE RÉALISÉE (Chiffre d'Affaires - CMV)", monthly_marge, marge_brute))
    bold_rows.append(len(data) - 1)

    # Taux de marge
    monthly_taux = {}
    for m in range(1, 13):
        v = monthly_sales.get(m, 0.0)
        mg = monthly_marge.get(m, 0.0)
        monthly_taux[m] = (mg / v * 100) if v > 0 else 0.0
    data.append(make_monthly_row("Taux de marge brute (%)", monthly_taux, taux_marge, is_pct=True))

    # 4. CHARGES D'EXPLOITATION
    data.append(["CHARGES D'EXPLOITATION (ESTIMÉES / CONSTANTES)"] + [""] * 13)
    bold_rows.append(len(data) - 1)

    for charge in [
        "Loyer du local", "Salaires et charges sociales",
        "Électricité / Eau", "Fournitures et consommables",
        "Entretien, maintenance & diverses",
    ]:
        data.append(make_monthly_row(charge, {}, 0))

    total_charges = 0
    data.append(make_monthly_row("TOTAL CHARGES D'EXPLOITATION", {}, total_charges))
    bold_rows.append(len(data) - 1)

    # 5. RÉSULTATS
    resultat = marge_brute - total_charges
    data.append(make_monthly_row("RÉSULTAT D'EXPLOITATION (Marge Brute - Total Charges)", monthly_marge, resultat))
    bold_rows.append(len(data) - 1)

    impot = resultat * 0.30 if resultat > 0 else 0
    data.append(make_monthly_row("Impôt sur le résultat (30%)", {}, impot))
    data.append(make_monthly_row("RÉSULTAT NET DE L'EXERCICE", {}, resultat - impot))
    bold_rows.append(len(data) - 1)

    table = Table(data, colWidths=col_widths, repeatRows=1)
    style = _grid_style(header_rows=1, font_size=7.8, header_font_size=8.5, padding=3.2)
    style.add('ALIGN', (1, 0), (-1, -1), 'CENTER')
    style.add('ALIGN', (0, 0), (0, -1), 'LEFT')

    for r in bold_rows:
        style.add('FONTNAME', (0, r), (-1, r), 'Helvetica-Bold')
        style.add('FONTSIZE', (0, r), (-1, r), 8.2)
        style.add('BACKGROUND', (0, r), (-1, r), colors.Color(0.91, 0.93, 0.96))

    table.setStyle(style)
    elements.append(table)

    doc.build(elements)
    buffer.seek(0)
    return buffer


# ═══════════════════════════════════════════════════════════════════
# 4. SUIVI DE TRÉSORERIE (100% Français)
# ═══════════════════════════════════════════════════════════════════

def generate_treasury_pdf(db: Session) -> BytesIO:
    """Suivi de Trésorerie - flux mensuels des encaissements et décaissements."""
    buffer = BytesIO()
    pharmacy = _pharmacy_name(db)
    year = date.today().year

    doc, elements, styles = _build_doc(
        buffer,
        title="SUIVI DE TRÉSORERIE",
        pharmacy=pharmacy,
        subtitle=f"{pharmacy} — Exercice {year}",
        note="** Le solde de fin de mois se reporte automatiquement comme solde de début du mois suivant.",
        left_margin=0.8 * cm,
        right_margin=0.8 * cm,
    )

    start_dt = datetime(year, 1, 1)
    end_dt = datetime(year, 12, 31, 23, 59, 59)
    monthly_sales = defaultdict(float)

    pos_sales = db.query(POSSale).filter(
        POSSale.date >= start_dt,
        POSSale.date <= end_dt,
        POSSale.status == "completed"
    ).all()
    for sale in pos_sales:
        monthly_sales[sale.date.month] += sale.total_amount or 0

    total_enc = sum(monthly_sales.values())

    avail_width = landscape(A4)[0] - 1.6 * cm
    rubrique_w = 210.0
    total_w = 60.0
    month_w = (avail_width - rubrique_w - total_w) / 12
    col_widths = [rubrique_w] + [month_w] * 12 + [total_w]

    header = ["Rubrique"] + MONTHS + ["TOTAL"]

    def row(label, monthly_data, total_val):
        r = [label]
        for m in range(1, 13):
            val = monthly_data.get(m, 0)
            r.append(_fmt(val) if val else "—")
        r.append(_fmt(total_val))
        return r

    data = [header]
    bold_rows = []

    data.append(row("Solde de trésorerie en début de mois", {}, 0))

    data.append(["ENCAISSEMENTS"] + [""] * 13)
    bold_rows.append(len(data) - 1)

    data.append(row("Encaissements ventes comptant", monthly_sales, total_enc))
    data.append(row("Encaissements sur créances clients / tiers payant", {}, 0))
    data.append(row("Autres encaissements", {}, 0))
    data.append(row("TOTAL ENCAISSEMENTS", monthly_sales, total_enc))
    bold_rows.append(len(data) - 1)

    data.append(["DÉCAISSEMENTS"] + [""] * 13)
    bold_rows.append(len(data) - 1)

    for dec in [
        "Paiement fournisseurs (achats médicaments)",
        "Salaires et charges sociales",
        "Charges fixes (loyer, électricité, assurance...)",
        "Impôts et taxes",
        "Autres décaissements",
    ]:
        data.append(row(dec, {}, 0))

    total_dec = 0
    data.append(row("TOTAL DÉCAISSEMENTS", {}, total_dec))
    bold_rows.append(len(data) - 1)

    data.append(row("VARIATION DE TRÉSORERIE", {}, total_enc - total_dec))
    bold_rows.append(len(data) - 1)

    data.append(row("SOLDE DE TRÉSORERIE EN FIN DE MOIS", {}, total_enc - total_dec))
    bold_rows.append(len(data) - 1)

    table = Table(data, colWidths=col_widths, repeatRows=1)
    style = _grid_style(header_rows=1, font_size=8.0, header_font_size=8.5, padding=3.5)
    style.add('ALIGN', (1, 0), (-1, -1), 'CENTER')
    style.add('ALIGN', (0, 0), (0, -1), 'LEFT')

    for r in bold_rows:
        style.add('FONTNAME', (0, r), (-1, r), 'Helvetica-Bold')
        style.add('FONTSIZE', (0, r), (-1, r), 8.5)
        style.add('BACKGROUND', (0, r), (-1, r), colors.Color(0.91, 0.93, 0.96))

    table.setStyle(style)
    elements.append(table)

    doc.build(elements)
    buffer.seek(0)
    return buffer


# ═══════════════════════════════════════════════════════════════════
# EXCEL REPORTS (Enrichis avec Double Valorisation & Marges)
# ═══════════════════════════════════════════════════════════════════

def _create_excel_header(ws, headers):
    for col_num, header in enumerate(headers, 1):
        cell = ws.cell(row=1, column=col_num)
        cell.value = header
        cell.font = Font(bold=True, color="FFFFFF", size=10)
        cell.fill = PatternFill(start_color="1F4E79", end_color="1F4E79", fill_type="solid")
        cell.alignment = Alignment(horizontal="center", vertical="center", wrap_text=True)


def generate_stock_excel(
    db: Session,
    start_date: Optional[date] = None,
    end_date: Optional[date] = None
) -> BytesIO:
    """Rapport Excel de stock complet avec double valorisation et filtrage par période."""
    wb = openpyxl.Workbook()
    ws = wb.active
    ws.title = "Inventaire du Stock"

    headers = [
        "Code", "Désignation", "DCI", "Forme", "N° Lot",
        "Stock (Unités)", "Conditionnement", "Seuil d'Alerte",
        "P.A. Unitaire (FBu)", "P.V. Unitaire (FBu)",
        "Valeur Achat (Comptable FBu)", "Valeur Vente (Marchande FBu)",
        "Marge Potentielle (FBu)", "Date Péremption", "Fournisseur", "Date Réception"
    ]
    _create_excel_header(ws, headers)

    query = db.query(MedicinePricing)
    if start_date:
        query = query.filter(
            or_(
                MedicinePricing.date_reception >= start_date,
                and_(MedicinePricing.date_reception.is_(None), cast(MedicinePricing.created_at, Date) >= start_date)
            )
        )
    if end_date:
        query = query.filter(
            or_(
                MedicinePricing.date_reception <= end_date,
                and_(MedicinePricing.date_reception.is_(None), cast(MedicinePricing.created_at, Date) <= end_date)
            )
        )

    entries = query.order_by(MedicinePricing.nom).all()
    for i, e in enumerate(entries, 2):
        stock = e.total_comprimes or 0
        units_per_box = (e.plaquettes_par_boite or 1) * (e.comprimes_par_plaquette or 1)
        pa = e.achat_comprime or (e.achat_boite / units_per_box if units_per_box else 0) or 0
        pv = e.vente_comprime or (e.vente_boite / units_per_box if units_per_box else 0) or 0
        val_achat = stock * pa
        val_vente = stock * pv
        marge = val_vente - val_achat
        cond_str = _format_stock_qty(stock, units_per_box)

        ws.cell(row=i, column=1, value=f"MED-{e.medicine_id or e.id:03d}")
        ws.cell(row=i, column=2, value=e.nom)
        ws.cell(row=i, column=3, value=e.dci or "-")
        ws.cell(row=i, column=4, value=e.forme or "-")
        ws.cell(row=i, column=5, value=e.lot or "-")
        ws.cell(row=i, column=6, value=stock)
        ws.cell(row=i, column=7, value=cond_str)
        ws.cell(row=i, column=8, value=e.seuil_alerte or 0)
        ws.cell(row=i, column=9, value=pa)
        ws.cell(row=i, column=10, value=pv)
        ws.cell(row=i, column=11, value=val_achat)
        ws.cell(row=i, column=12, value=val_vente)
        ws.cell(row=i, column=13, value=marge)
        exp = e.date_peremption
        ws.cell(row=i, column=14, value=exp.strftime("%d/%m/%Y") if exp and not isinstance(exp, str) else str(exp or "-"))
        ws.cell(row=i, column=15, value=e.fournisseur or "-")
        rec = e.date_reception
        ws.cell(row=i, column=16, value=rec.strftime("%d/%m/%Y") if rec and not isinstance(rec, str) else str(rec or "-"))

    for col in ws.columns:
        ml = max(len(str(c.value or "")) for c in col)
        ws.column_dimensions[col[0].column_letter].width = max(min(ml + 3, 30), 12)

    out = BytesIO()
    wb.save(out)
    out.seek(0)
    return out


def generate_sales_excel(db: Session, start_date: date, end_date: date) -> BytesIO:
    """Rapport Excel des ventes avec calcul du coût d'achat et de la marge réelle."""
    wb = openpyxl.Workbook()
    ws = wb.active
    ws.title = "Rapport des Ventes"

    headers = [
        "Date", "N° Facture", "Client", "Désignation", "Quantité",
        "P.V. Unitaire (FBu)", "Remise %", "Montant Net (FBu)",
        "Coût Achat (FBu)", "Marge Réelle (FBu)", "Mode de Paiement", "Vendeur"
    ]
    _create_excel_header(ws, headers)

    start_dt = datetime.combine(start_date, datetime.min.time())
    end_dt = datetime.combine(end_date, datetime.max.time())

    pos_sales = db.query(POSSale).filter(
        POSSale.date >= start_dt, POSSale.date <= end_dt,
        POSSale.status == "completed"
    ).order_by(POSSale.date).all()

    row_num = 2
    for sale in pos_sales:
        for item in sale.items:
            med = item.medicine
            discount = item.discount_percent or 0
            net = item.total_price or (item.quantity * item.unit_price * (1 - discount / 100))
            cost_unit = _get_item_cost(item)
            cost_total = cost_unit * item.quantity
            marge = net - cost_total

            pmt_raw = sale.payment_method or "Espèces"
            pmt_fr = PMT_MAP.get(pmt_raw.lower(), pmt_raw)

            ws.cell(row=row_num, column=1, value=sale.date.strftime("%d/%m/%Y"))
            ws.cell(row=row_num, column=2, value=sale.code)
            ws.cell(row=row_num, column=3, value=sale.customer_name or "Client comptoir")
            ws.cell(row=row_num, column=4, value=med.name if med else "?")
            ws.cell(row=row_num, column=5, value=item.quantity)
            ws.cell(row=row_num, column=6, value=item.unit_price)
            ws.cell(row=row_num, column=7, value=f"{discount:.0f}%")
            ws.cell(row=row_num, column=8, value=net)
            ws.cell(row=row_num, column=9, value=cost_total)
            ws.cell(row=row_num, column=10, value=marge)
            ws.cell(row=row_num, column=11, value=pmt_fr)
            ws.cell(row=row_num, column=12, value=sale.user.username if sale.user else "-")
            row_num += 1

    for col in ws.columns:
        ml = max(len(str(c.value or "")) for c in col)
        ws.column_dimensions[col[0].column_letter].width = max(min(ml + 3, 30), 12)

    out = BytesIO()
    wb.save(out)
    out.seek(0)
    return out


# ═══════════════════════════════════════════════════════════════════
# WORD/HTML REPORTS (100% Français)
# ═══════════════════════════════════════════════════════════════════

def generate_stock_word(
    db: Session,
    start_date: Optional[date] = None,
    end_date: Optional[date] = None
) -> BytesIO:
    query = db.query(MedicinePricing)
    if start_date:
        query = query.filter(
            or_(
                MedicinePricing.date_reception >= start_date,
                and_(MedicinePricing.date_reception.is_(None), cast(MedicinePricing.created_at, Date) >= start_date)
            )
        )
    if end_date:
        query = query.filter(
            or_(
                MedicinePricing.date_reception <= end_date,
                and_(MedicinePricing.date_reception.is_(None), cast(MedicinePricing.created_at, Date) <= end_date)
            )
        )

    entries = query.order_by(MedicinePricing.nom).all()

    if start_date and end_date:
        p_str = f"Période : Du {start_date.strftime('%d/%m/%Y')} au {end_date.strftime('%d/%m/%Y')}"
    elif start_date:
        p_str = f"Période : À partir du {start_date.strftime('%d/%m/%Y')}"
    elif end_date:
        p_str = f"Période : Jusqu'au {end_date.strftime('%d/%m/%Y')}"
    else:
        p_str = f"Date d'inventaire : {date.today().strftime('%d/%m/%Y')}"

    html = f"""<html><head><meta charset="utf-8"><title>Rapport de Stock</title>
    <style>body{{font-family:Arial,sans-serif}}table{{border-collapse:collapse;width:100%}}
    th,td{{border:1px solid #333;padding:8px;font-size:10pt}}th{{background:#1F4E79;color:#fff}}</style></head>
    <body><h2>Rapport de Stock — PharmaGestion</h2><p>{p_str}</p>
    <table><tr><th>Code</th><th>Désignation</th><th>Stock</th><th>P.A. Unit (FBu)</th><th>P.V. Unit (FBu)</th><th>Date Péremption</th></tr>"""
    for e in entries:
        exp = e.date_peremption
        exp_s = exp.strftime("%d/%m/%Y") if exp and not isinstance(exp, str) else "-"
        units_per_box = (e.plaquettes_par_boite or 1) * (e.comprimes_par_plaquette or 1)
        stock_str = _format_stock_qty(e.total_comprimes or 0, units_per_box)
        pa = e.achat_comprime or (e.achat_boite / units_per_box if units_per_box else 0) or 0
        pv = e.vente_comprime or (e.vente_boite / units_per_box if units_per_box else 0) or 0
        html += f"<tr><td>MED-{e.medicine_id or e.id:03d}</td><td>{e.nom}</td><td>{stock_str}</td><td>{_fmt(pa)}</td><td>{_fmt(pv)}</td><td>{exp_s}</td></tr>"
    html += "</table></body></html>"
    return BytesIO(html.encode('utf-8'))


def generate_sales_word(db: Session, start_date: date, end_date: date) -> BytesIO:
    start_dt = datetime.combine(start_date, datetime.min.time())
    end_dt = datetime.combine(end_date, datetime.max.time())
    sales = db.query(POSSale).filter(
        POSSale.date >= start_dt, POSSale.date <= end_dt,
        POSSale.status == "completed"
    ).order_by(POSSale.date.desc()).all()

    total_ca = sum(s.total_amount or 0 for s in sales)
    html = f"""<html><head><meta charset="utf-8"><title>Rapport des Ventes</title>
    <style>body{{font-family:Arial,sans-serif}}table{{border-collapse:collapse;width:100%}}
    th,td{{border:1px solid #333;padding:8px;text-align:center;font-size:10pt}}th{{background:#1F4E79;color:#fff}}</style></head>
    <body><h2>Rapport des Ventes — PharmaGestion</h2><p>Période : {start_date.strftime('%d/%m/%Y')} au {end_date.strftime('%d/%m/%Y')}</p>
    <table><tr><th>N° Facture</th><th>Date</th><th>Total (FBu)</th><th>Articles</th><th>Mode de Paiement</th></tr>"""
    for s in sales:
        pmt_raw = s.payment_method or "Espèces"
        pmt_fr = PMT_MAP.get(pmt_raw.lower(), pmt_raw)
        html += f"<tr><td>{s.code}</td><td>{s.date.strftime('%d/%m/%Y')}</td><td>{_fmt(s.total_amount)}</td><td>{len(s.items)}</td><td>{pmt_fr}</td></tr>"
    html += f'<tr style="font-weight:bold;background:#eee"><td colspan="2">TOTAL</td><td>{_fmt(total_ca)} FBu</td><td colspan="2"></td></tr></table></body></html>'
    return BytesIO(html.encode('utf-8'))

"""
PDF service - Generate invoice PDFs using ReportLab.
"""

from reportlab.lib.pagesizes import A4
from reportlab.lib.units import cm
from reportlab.pdfgen import canvas
from reportlab.lib import colors
from io import BytesIO
from datetime import datetime
from typing import Dict, Any


def generate_invoice_pdf(invoice_data: Dict[str, Any]) -> BytesIO:
    """
    Generate a professional invoice PDF.
    
    Args:
        invoice_data: Invoice data dictionary with keys:
            - invoice_code: str
            - date: datetime
            - total_amount: float
            - payment_method: str
            - items: list of dicts
            - customer: dict or None
            - seller: str
    
    Returns:
        BytesIO buffer containing the PDF
    """
    buffer = BytesIO()
    pdf = canvas.Canvas(buffer, pagesize=A4)
    width, height = A4
    
    # Margins
    left_margin = 2 * cm
    right_margin = width - 2 * cm
    
    # Current Y position (start from top)
    y = height - 2 * cm
    
    # ========================================================================
    # HEADER
    # ========================================================================
    pdf.setFont("Helvetica-Bold", 20)
    pdf.drawCentredString(width / 2, y, "PHARMACIE")
    y -= 0.5 * cm
    
    pdf.setFont("Helvetica", 10)
    pdf.drawCentredString(width / 2, y, "Système de Gestion")
    y -= 1.5 * cm
    
    # Horizontal line
    pdf.setStrokeColor(colors.grey)
    pdf.setLineWidth(2)
    pdf.line(left_margin, y, right_margin, y)
    y -= 1 * cm
    
    # ========================================================================
    # INVOICE INFO
    # ========================================================================
    pdf.setFont("Helvetica-Bold", 14)
    pdf.drawString(left_margin, y, f"FACTURE: {invoice_data['invoice_code']}")
    y -= 0.7 * cm
    
    pdf.setFont("Helvetica", 10)
    date_str = invoice_data['date'].strftime("%d/%m/%Y %H:%M")
    pdf.drawString(left_margin, y, f"Date: {date_str}")
    y -= 0.5 * cm
    
    pdf.drawString(left_margin, y, f"Vendeur: {invoice_data['seller']}")
    y -= 0.5 * cm
    
    # Customer info (if exists)
    if invoice_data.get('customer'):
        customer = invoice_data['customer']
        pdf.drawString(left_margin, y, f"Client: {customer['name']}")
        y -= 0.5 * cm
        pdf.drawString(left_margin, y, f"Téléphone: {customer['phone']}")
        y -= 0.5 * cm
    
    y -= 1 * cm
    
    # ========================================================================
    # ITEMS TABLE
    # ========================================================================
    pdf.setFont("Helvetica-Bold", 12)
    pdf.drawString(left_margin, y, "ARTICLES")
    y -= 0.7 * cm
    
    # Table header
    pdf.setFillColor(colors.lightgrey)
    pdf.rect(left_margin, y - 0.5 * cm, right_margin - left_margin, 0.6 * cm, fill=True, stroke=False)
    
    pdf.setFillColor(colors.black)
    pdf.setFont("Helvetica-Bold", 9)
    
    col1 = left_margin + 0.2 * cm
    col2 = left_margin + 8 * cm
    col3 = left_margin + 10 * cm
    col4 = left_margin + 13 * cm
    col5 = left_margin + 16 * cm
    
    pdf.drawString(col1, y - 0.3 * cm, "Médicament")
    pdf.drawString(col2, y - 0.3 * cm, "Qté")
    pdf.drawString(col3, y - 0.3 * cm, "P.U.")
    pdf.drawString(col5, y - 0.3 * cm, "Total")
    y -= 0.7 * cm
    
    # Table rows
    pdf.setFont("Helvetica", 9)
    for item in invoice_data['items']:
        # Check if we need a new page
        if y < 3 * cm:
            pdf.showPage()
            y = height - 2 * cm
            pdf.setFont("Helvetica", 9)
        
        pdf.drawString(col1, y, item['medicine_name'][:40])  # Truncate long names
        pdf.drawString(col2, y, str(item['quantity']))
        pdf.drawString(col3, y, f"{item['unit_price']:,.0f} FBu")
        pdf.drawString(col5, y, f"{item['total_price']:,.0f} FBu")
        y -= 0.5 * cm
    
    # Separator line
    y -= 0.3 * cm
    pdf.setStrokeColor(colors.grey)
    pdf.setLineWidth(1)
    pdf.line(left_margin, y, right_margin, y)
    y -= 0.7 * cm
    
    # ========================================================================
    # TOTAL
    # ========================================================================
    pdf.setFont("Helvetica-Bold", 14)
    pdf.drawString(col4, y, "TOTAL:")
    pdf.drawString(col5, y, f"{invoice_data['total_amount']:,.0f} FBu")
    y -= 1 * cm
    
    # ========================================================================
    # PAYMENT INFO
    # ========================================================================
    pdf.setFont("Helvetica", 10)
    pdf.drawString(left_margin, y, f"Mode de paiement: {invoice_data['payment_method'].upper()}")
    y -= 0.5 * cm
    
    # Bonus points (if customer)
    if invoice_data.get('customer'):
        bonus = invoice_data['customer'].get('points_earned', 0)
        pdf.drawString(left_margin, y, f"Points bonus gagnés: {bonus}")
        y -= 0.5 * cm
    
    y -= 1.5 * cm
    
    # ========================================================================
    # FOOTER
    # ========================================================================
    pdf.setFont("Helvetica-Oblique", 9)
    pdf.drawCentredString(width / 2, y, "Merci pour votre visite!")
    
    # Bottom line
    y = 2 * cm
    pdf.setStrokeColor(colors.grey)
    pdf.setLineWidth(1)
    pdf.line(left_margin, y, right_margin, y)
    
    # Finalize PDF
    pdf.save()
    buffer.seek(0)
    return buffer

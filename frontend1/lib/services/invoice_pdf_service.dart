// Service de génération de facture PDF côté Flutter.
//
// Utilise les packages `pdf` et `printing` pour créer un document PDF
// professionnel et l'afficher dans un dialogue d'impression natif.
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

import 'package:frontend1/models/sale.dart';
import 'package:frontend1/models/app_settings.dart';

class InvoicePdfService {
  // ──────────────────────────── PALETTE ────────────────────────────
  static const _primaryColor = PdfColor.fromInt(0xFF1A5276);    // Bleu pharma
  static const _accentColor = PdfColor.fromInt(0xFF2E86C1);     // Bleu clair
  static const _successColor = PdfColor.fromInt(0xFF27AE60);    // Vert
  static const _lightBg = PdfColor.fromInt(0xFFF4F6F9);         // Gris très clair
  static const _borderColor = PdfColor.fromInt(0xFFD5DBDB);     // Gris bordure
  static const _textDark = PdfColor.fromInt(0xFF2C3E50);        // Texte principal
  static const _textMuted = PdfColor.fromInt(0xFF7F8C8D);       // Texte secondaire

  /// Génère les bytes du PDF de facture.
  static Future<Uint8List> generateInvoicePdf({
    required Sale sale,
    required AppSettings settings,
    required String sellerName,
  }) async {
    final pdf = pw.Document(
      title: 'Facture ${sale.code}',
      author: settings.pharmacyName,
    );

    final dateFormat = DateFormat('dd/MM/yyyy HH:mm:ss');
    final dateOnly = DateFormat('dd/MM/yyyy');
    final currency = settings.currency.isNotEmpty ? settings.currency : 'FBu';
    final pharmacyName = settings.pharmacyName.isNotEmpty
        ? settings.pharmacyName
        : 'PHARMACIE';

    // Calculs
    final int totalItems = sale.items.fold(0, (sum, i) => sum + i.quantity);
    final int lineCount = sale.items.length;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 28),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // ══════════════════════════════════════════════════════════
              // HEADER — Bandeau pharmacie
              // ══════════════════════════════════════════════════════════
              _buildHeader(settings, pharmacyName),
              pw.SizedBox(height: 16),

              // ══════════════════════════════════════════════════════════
              // BANDEAU FACTURE N° + DATE
              // ══════════════════════════════════════════════════════════
              _buildInvoiceBanner(sale, dateFormat, sellerName),
              pw.SizedBox(height: 16),

              // ══════════════════════════════════════════════════════════
              // INFO CLIENT (si présent)
              // ══════════════════════════════════════════════════════════
              if ((sale.customerName != null && sale.customerName!.isNotEmpty) ||
                  (sale.customerPhone != null && sale.customerPhone!.isNotEmpty))
                _buildClientBox(sale),
              if ((sale.customerName != null && sale.customerName!.isNotEmpty) ||
                  (sale.customerPhone != null && sale.customerPhone!.isNotEmpty))
                pw.SizedBox(height: 12),

              // ══════════════════════════════════════════════════════════
              // TABLEAU DES ARTICLES
              // ══════════════════════════════════════════════════════════
              _buildSectionTitle('DÉTAIL DES ARTICLES'),
              pw.SizedBox(height: 6),
              _buildItemsTable(sale.items, currency),
              pw.SizedBox(height: 4),

              // Résumé articles
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.Text(
                      '$lineCount article(s)  •  $totalItems unité(s)',
                      style: pw.TextStyle(
                        fontSize: 8,
                        color: _textMuted,
                        fontStyle: pw.FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 8),

              // ══════════════════════════════════════════════════════════
              // BLOC TOTAL + PAIEMENT
              // ══════════════════════════════════════════════════════════
              _buildTotalBlock(sale, currency),
              pw.SizedBox(height: 12),

              // ══════════════════════════════════════════════════════════
              // ASSURANCE (si applicable)
              // ══════════════════════════════════════════════════════════
              if (sale.paymentMethod == 'insurance' ||
                  sale.paymentMethod == 'insurance_card')
                _buildInsuranceBlock(sale),

              pw.Spacer(),

              // ══════════════════════════════════════════════════════════
              // FOOTER
              // ══════════════════════════════════════════════════════════
              _buildFooter(settings, pharmacyName, dateOnly),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Affiche le dialogue natif d'impression/preview/sauvegarde PDF.
  static Future<void> printInvoice({
    required Sale sale,
    required AppSettings settings,
    required String sellerName,
  }) async {
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async {
        return generateInvoicePdf(
          sale: sale,
          settings: settings,
          sellerName: sellerName,
        );
      },
      name: 'Facture_${sale.code}',
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // COMPOSANTS PDF
  // ════════════════════════════════════════════════════════════════════

  /// En-tête avec nom, adresse, téléphone, NIF
  static pw.Widget _buildHeader(AppSettings settings, String name) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: _primaryColor,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          // Icône RX
          pw.Container(
            width: 48,
            height: 48,
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              borderRadius: pw.BorderRadius.circular(24),
            ),
            alignment: pw.Alignment.center,
            child: pw.Text(
              'Rx',
              style: pw.TextStyle(
                fontSize: 22,
                fontWeight: pw.FontWeight.bold,
                color: _primaryColor,
              ),
            ),
          ),
          pw.SizedBox(width: 16),
          // Infos pharmacie
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  name.toUpperCase(),
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                    letterSpacing: 1.2,
                  ),
                ),
                if (settings.pharmacyAddress.isNotEmpty)
                  pw.Text(
                    settings.pharmacyAddress,
                    style: const pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.white,
                    ),
                  ),
                pw.SizedBox(height: 2),
                pw.Row(
                  children: [
                    if (settings.pharmacyPhone.isNotEmpty)
                      pw.Text(
                        'Tél: ${settings.pharmacyPhone}',
                        style: pw.TextStyle(
                          fontSize: 9,
                          color: PdfColors.grey300,
                        ),
                      ),
                    if (settings.pharmacyPhone.isNotEmpty &&
                        settings.pharmacyNif.isNotEmpty)
                      pw.Text(
                        '   |   ',
                        style: pw.TextStyle(
                          fontSize: 9,
                          color: PdfColors.grey500,
                        ),
                      ),
                    if (settings.pharmacyNif.isNotEmpty)
                      pw.Text(
                        'NIF: ${settings.pharmacyNif}',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey300,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Bandeau FACTURE N° + Date + Vendeur
  static pw.Widget _buildInvoiceBanner(
      Sale sale, DateFormat dateFormat, String sellerName) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: pw.BoxDecoration(
        color: _lightBg,
        border: pw.Border.all(color: _borderColor),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'FACTURE',
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: _textMuted,
                  letterSpacing: 2,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                sale.code,
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: _primaryColor,
                ),
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              _buildInfoChip('DATE', dateFormat.format(sale.date)),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              _buildInfoChip('VENDEUR', sellerName),
            ],
          ),
        ],
      ),
    );
  }

  /// Petit bloc label + valeur
  static pw.Widget _buildInfoChip(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 7,
            fontWeight: pw.FontWeight.bold,
            color: _textMuted,
            letterSpacing: 1.5,
          ),
        ),
        pw.SizedBox(height: 1),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: _textDark,
          ),
        ),
      ],
    );
  }

  /// Bloc client
  static pw.Widget _buildClientBox(Sale sale) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          left: pw.BorderSide(color: _accentColor, width: 3),
        ),
        color: const PdfColor.fromInt(0xFFEBF5FB),
      ),
      child: pw.Row(
        children: [
          pw.Text(
            'CLIENT  ',
            style: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              color: _accentColor,
              letterSpacing: 1.5,
            ),
          ),
          pw.Text(
                  [
                    if (sale.customerName != null && sale.customerName!.isNotEmpty)
                      sale.customerName!,
                    if (sale.customerPhone != null && sale.customerPhone!.isNotEmpty)
                      'Tél: ${sale.customerPhone}',
                  ].join('  |  '),
                  style: const pw.TextStyle(fontSize: 10),
                ),
        ],
      ),
    );
  }

  /// Titre de section
  static pw.Widget _buildSectionTitle(String title) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 4),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: _primaryColor, width: 1.5),
        ),
      ),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
          color: _primaryColor,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  /// Tableau des articles avec design amélioré
  static pw.Widget _buildItemsTable(List<SaleItem> items, String currency) {
    final headers = ['#', 'Désignation', 'Code', 'Qté', 'P.U.', 'Total'];

    final data = <List<String>>[];
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      data.add([
        '${i + 1}',
        item.medicineName,
        item.medicineCode,
        '${item.quantity}',
        '${_formatNumber(item.unitPrice)} $currency',
        '${_formatNumber(item.totalPrice)} $currency',
      ]);
    }

    return pw.TableHelper.fromTextArray(
      border: pw.TableBorder(
        horizontalInside: pw.BorderSide(color: _borderColor, width: 0.5),
        bottom: pw.BorderSide(color: _borderColor, width: 0.5),
        top: pw.BorderSide(color: _primaryColor, width: 1.5),
      ),
      headerStyle: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        fontSize: 8,
        color: PdfColors.white,
      ),
      headerDecoration: const pw.BoxDecoration(
        color: _primaryColor,
      ),
      headerAlignments: {
        0: pw.Alignment.center,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.center,
        3: pw.Alignment.center,
        4: pw.Alignment.centerRight,
        5: pw.Alignment.centerRight,
      },
      cellStyle: pw.TextStyle(
        fontSize: 9,
        color: _textDark,
      ),
      cellAlignments: {
        0: pw.Alignment.center,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.center,
        3: pw.Alignment.center,
        4: pw.Alignment.centerRight,
        5: pw.Alignment.centerRight,
      },
      cellDecoration: (index, data, rowNum) {
        return pw.BoxDecoration(
          color: rowNum % 2 == 0 ? _lightBg : PdfColors.white,
        );
      },
      cellPadding:
          const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      columnWidths: {
        0: const pw.FixedColumnWidth(24),  // #
        1: const pw.FlexColumnWidth(4),    // Désignation
        2: const pw.FlexColumnWidth(1.5),  // Code
        3: const pw.FixedColumnWidth(36),  // Qté
        4: const pw.FlexColumnWidth(1.8),  // P.U.
        5: const pw.FlexColumnWidth(2),    // Total
      },
      headers: headers,
      data: data,
    );
  }

  /// Bloc total avec paiement
  static pw.Widget _buildTotalBlock(Sale sale, String currency) {
    // Calculer la remise globale depuis les items
    final double sousTotalTheorique = sale.items.fold(
      0.0,
      (sum, item) => sum + (item.unitPrice * item.quantity),
    );
    final double remiseTotale = sousTotalTheorique - sale.totalAmount;
    final double remisePct = sousTotalTheorique > 0
        ? (remiseTotale / sousTotalTheorique) * 100
        : 0.0;
    // Vérifier si au moins un item a une remise explicite (depuis backend)
    final bool hasItemDiscount = sale.items.any((i) => i.discountPercent > 0);
    final bool hasDiscount = hasItemDiscount || remisePct > 0.5;

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Côté gauche : mode de paiement + bonus + remise
        pw.Expanded(
          flex: 3,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: pw.BoxDecoration(
                  borderRadius: pw.BorderRadius.circular(4),
                  border: pw.Border.all(color: _borderColor),
                ),
                child: pw.Row(
                  mainAxisSize: pw.MainAxisSize.min,
                  children: [
                    pw.Text(
                      'Paiement: ',
                      style: pw.TextStyle(
                        fontSize: 9,
                        color: _textMuted,
                      ),
                    ),
                    pw.Text(
                      _translatePaymentMethod(sale.paymentMethod),
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: _textDark,
                      ),
                    ),
                  ],
                ),
              ),
              // Badge remise globale
              if (hasDiscount) ...[
                pw.SizedBox(height: 6),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: pw.BoxDecoration(
                    borderRadius: pw.BorderRadius.circular(4),
                    color: const PdfColor.fromInt(0xFFFDF2F2),
                    border: pw.Border.all(
                        color: const PdfColor.fromInt(0xFFE74C3C)),
                  ),
                  child: pw.Row(
                    mainAxisSize: pw.MainAxisSize.min,
                    children: [
                      pw.Text(
                        hasItemDiscount
                            ? 'Remise client: -${sale.items.firstWhere((i) => i.discountPercent > 0).discountPercent.toStringAsFixed(0)}%'
                            : 'Remise: -${remisePct.toStringAsFixed(1)}%',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: const PdfColor.fromInt(0xFFE74C3C),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (sale.bonusEarned > 0) ...[
                pw.SizedBox(height: 6),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: pw.BoxDecoration(
                    borderRadius: pw.BorderRadius.circular(4),
                    color: const PdfColor.fromInt(0xFFE8F8F5),
                    border: pw.Border.all(color: _successColor),
                  ),
                  child: pw.Text(
                    '★  ${sale.bonusEarned.toStringAsFixed(0)} points bonus gagnés',
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: _successColor,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        // Côté droit : TOTAL
        pw.Expanded(
          flex: 2,
          child: pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: _primaryColor,
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'TOTAL À PAYER',
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey300,
                    letterSpacing: 2,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  '${_formatNumber(sale.totalAmount)} $currency',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Bloc assurance
  static pw.Widget _buildInsuranceBlock(Sale sale) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 10),
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _accentColor),
        borderRadius: pw.BorderRadius.circular(4),
        color: const PdfColor.fromInt(0xFFEBF5FB),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'INFORMATIONS ASSURANCE',
            style: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              color: _accentColor,
              letterSpacing: 1.5,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Text(
                  'Assureur: ${sale.insuranceProvider ?? "-"}',
                  style: const pw.TextStyle(fontSize: 9),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Carte/Matricule: ${sale.insuranceCardId ?? "-"}   |   Couverture: ${sale.coveragePercent.toStringAsFixed(0)}%',
            style: const pw.TextStyle(fontSize: 9),
          ),
        ],
      ),
    );
  }

  /// Footer professionnel
  static pw.Widget _buildFooter(
      AppSettings settings, String name, DateFormat dateOnly) {
    return pw.Column(
      children: [
        pw.Divider(color: _borderColor, thickness: 0.5),
        pw.SizedBox(height: 8),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  name,
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: _primaryColor,
                  ),
                ),
                if (settings.pharmacyPhone.isNotEmpty)
                  pw.Text(
                    settings.pharmacyPhone,
                    style: pw.TextStyle(fontSize: 7, color: _textMuted),
                  ),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(
                  'Merci pour votre confiance !',
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontStyle: pw.FontStyle.italic,
                    color: _textMuted,
                  ),
                ),
                pw.Text(
                  'Votre santé, notre priorité.',
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: _accentColor,
                  ),
                ),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'Imprimé le ${dateOnly.format(DateTime.now())}',
                  style: pw.TextStyle(fontSize: 7, color: _textMuted),
                ),
                pw.Text(
                  'PharmaGestion v1.0',
                  style: pw.TextStyle(fontSize: 7, color: _textMuted),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // UTILITAIRES
  // ════════════════════════════════════════════════════════════════════

  /// Formate un nombre avec séparateur de milliers.
  static String _formatNumber(double value) {
    return NumberFormat('#,##0', 'fr_FR').format(value);
  }

  /// Traduit la méthode de paiement en texte lisible.
  static String _translatePaymentMethod(String method) {
    switch (method) {
      case 'cash':
        return 'Espèces';
      case 'insurance':
      case 'insurance_card':
        return 'Carte d\'assurance';
      case 'mobile_money':
        return 'Mobile Money';
      case 'card':
        return 'Carte bancaire';
      case 'credit':
        return 'Crédit';
      default:
        return method.toUpperCase();
    }
  }
}

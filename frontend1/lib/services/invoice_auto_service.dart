// invoice_auto_service.dart
//
// Service de facturation automatique.
// Déclenché dès qu'une vente POS est validée :
//   1. Génère les bytes PDF
//   2. Sauvegarde dans Documents/PharmaGest/Factures/YYYY-MM/
//   3. Ouvre le PDF dans le visualiseur système
//   4. Retourne le chemin pour affichage UI

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:printing/printing.dart';

import 'package:frontend1/models/sale.dart';
import 'package:frontend1/models/app_settings.dart';
import 'package:frontend1/services/invoice_pdf_service.dart';
import 'package:frontend1/core/error_helper.dart';

class InvoiceAutoResult {
  /// Chemin local du PDF sauvegardé (null si échec)
  final String? savedPath;

  /// Bytes du PDF (toujours présent si pas d'erreur)
  final Uint8List? pdfBytes;

  /// Message d'erreur (null si succès)
  final String? error;

  const InvoiceAutoResult({this.savedPath, this.pdfBytes, this.error});

  bool get isSuccess => error == null && pdfBytes != null;
}

class InvoiceAutoService {
  /// Génère, sauvegarde et ouvre automatiquement la facture PDF.
  ///
  /// [sale]       : Objet vente retourné après le checkout
  /// [settings]   : Paramètres pharmacie (nom, adresse, etc.)
  /// [sellerName] : Nom du vendeur (depuis AuthProvider)
  /// [autoOpen]   : Si true, ouvre le PDF avec le visualiseur système
  static Future<InvoiceAutoResult> generateAndSave({
    required Sale sale,
    required AppSettings settings,
    required String sellerName,
    bool autoOpen = true,
  }) async {
    try {
      // ── 1. Générer les bytes PDF ──────────────────────────────────
      final Uint8List pdfBytes = await InvoicePdfService.generateInvoicePdf(
        sale: sale,
        settings: settings,
        sellerName: sellerName,
      );

      // ── 2. Sauvegarder sur le disque (Desktop uniquement) ─────────
      String? savedPath;
      if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
        savedPath = await _saveToLocalDisk(pdfBytes, sale.code);

        // ── 3. Ouvrir avec le visualiseur PDF système ─────────────
        if (autoOpen && savedPath != null) {
          try {
            await OpenFile.open(savedPath);
          } catch (e) {
            debugPrint('[InvoiceAuto] Impossible d\'ouvrir le PDF: $e');
          }
        }
      }

      return InvoiceAutoResult(savedPath: savedPath, pdfBytes: pdfBytes);
    } catch (e) {
      debugPrint('[InvoiceAuto] Erreur génération: $e');
      return InvoiceAutoResult(error: ErrorHelper.extractErrorMessage(e));
    }
  }

  /// Ouvre le dialogue d'impression natif Windows/macOS.
  static Future<void> printInvoice({
    required Sale sale,
    required AppSettings settings,
    required String sellerName,
  }) async {
    await Printing.layoutPdf(
      onLayout: (_) => InvoicePdfService.generateInvoicePdf(
        sale: sale,
        settings: settings,
        sellerName: sellerName,
      ),
      name: 'Facture_${sale.code}',
    );
  }

  /// Re-télécharge / réouvre une facture depuis son chemin sauvegardé.
  static Future<void> reopenSaved(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await OpenFile.open(path);
    } else {
      throw Exception('Fichier introuvable : $path');
    }
  }

  // ─── Helpers privés ───────────────────────────────────────────────

  /// Sauvegarde le PDF dans Documents/PharmaGest/Factures/YYYY-MM/
  static Future<String?> _saveToLocalDisk(Uint8List bytes, String invoiceCode) async {
    try {
      // Dossier Documents utilisateur
      Directory baseDir;
      try {
        baseDir = await getApplicationDocumentsDirectory();
      } catch (_) {
        baseDir = Directory.systemTemp;
      }

      // Structure : PharmaGest/Factures/2026-06/
      final now = DateTime.now();
      final monthFolder = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}';
      final invoiceDir = Directory('${baseDir.path}/PharmaGest/Factures/$monthFolder');
      if (!await invoiceDir.exists()) {
        await invoiceDir.create(recursive: true);
      }

      // Nom de fichier : Facture_INV-2026-0042_2026-06-30.pdf
      final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final fileName = 'Facture_${invoiceCode}_$dateStr.pdf';
      final filePath = '${invoiceDir.path}/$fileName';

      // Écrire le fichier
      final file = File(filePath);
      await file.writeAsBytes(bytes);
      debugPrint('[InvoiceAuto] ✅ Facture sauvegardée: $filePath');

      return filePath;
    } catch (e) {
      debugPrint('[InvoiceAuto] ⚠️ Erreur sauvegarde disque: $e');
      return null;
    }
  }
}

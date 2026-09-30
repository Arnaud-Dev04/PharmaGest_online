// reports_service_web.dart
// Utilisé sur Flutter Web (Chrome, Firefox...)
// dart:io n'est PAS disponible sur le web — on utilise dart:html

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:flutter/foundation.dart';

/// Déclenche un téléchargement navigateur via un lien Blob.
/// Le fichier est téléchargé dans le dossier Téléchargements du navigateur.
/// Retourne le nom du fichier (pas un chemin local — non accessible sur web).
Future<String?> saveFile(List<int> bytes, String defaultName) async {
  try {
    // Ajouter un horodatage pour éviter les conflits
    final timestamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .substring(0, 19);
    final parts = defaultName.split('.');
    final ext = parts.length > 1 ? parts.last : 'bin';
    final base = parts.length > 1
        ? parts.sublist(0, parts.length - 1).join('.')
        : defaultName;
    final fileName = '${base}_$timestamp.$ext';

    // Déterminer le type MIME selon l'extension
    final mimeType = _getMimeType(ext);

    // Créer un Blob et un lien de téléchargement
    final blob = html.Blob([bytes], mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);

    // Créer un élément <a> invisible et cliquer dessus
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..style.display = 'none';

    html.document.body!.append(anchor);
    anchor.click();

    // Nettoyer après le téléchargement
    Future.delayed(const Duration(milliseconds: 500), () {
      anchor.remove();
      html.Url.revokeObjectUrl(url);
    });

    debugPrint('[ReportsService] Téléchargement web déclenché: $fileName');

    // Sur le web, retourner le nom du fichier (pas un chemin disque)
    return fileName;
  } catch (e) {
    debugPrint('[ReportsService] Erreur Web: $e');
    rethrow;
  }
}

/// Retourne le type MIME approprié selon l'extension du fichier
String _getMimeType(String ext) {
  switch (ext.toLowerCase()) {
    case 'pdf':
      return 'application/pdf';
    case 'xlsx':
      return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    case 'xls':
      return 'application/vnd.ms-excel';
    case 'doc':
    case 'docx':
      return 'application/msword';
    default:
      return 'application/octet-stream';
  }
}

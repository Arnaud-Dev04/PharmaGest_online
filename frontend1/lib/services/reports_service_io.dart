// reports_service_io.dart
// Utilisé sur Windows Desktop (et Android/iOS)
// dart:io est disponible sur ces plateformes

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

/// Sauvegarde le fichier dans Documents/PharmaGestion/Rapports/ et l'ouvre.
/// Retourne le chemin absolu du fichier créé.
Future<String?> saveFile(List<int> bytes, String defaultName) async {
  try {
    // Dossier Documents de l'utilisateur
    Directory baseDir;
    try {
      baseDir = await getApplicationDocumentsDirectory();
    } catch (_) {
      // Fallback : dossier temporaire si documents non accessible
      baseDir = Directory.systemTemp;
    }

    // Créer le dossier dédié
    final reportDir = Directory('${baseDir.path}/PharmaGestion/Rapports');
    if (!await reportDir.exists()) {
      await reportDir.create(recursive: true);
    }

    // Nom de fichier horodaté (évite les conflits)
    final timestamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .substring(0, 19);
    final parts = defaultName.split('.');
    final ext = parts.length > 1 ? parts.last : 'bin';
    final base = parts.length > 1
        ? parts.sublist(0, parts.length - 1).join('.')
        : defaultName;
    final filePath = '${reportDir.path}/${base}_$timestamp.$ext';

    // Écrire le fichier sur le disque
    final file = File(filePath);
    await file.writeAsBytes(bytes);
    debugPrint('[ReportsService] Fichier créé: $filePath');

    // Ouvrir avec l'application par défaut du système (Word, Excel, Acrobat...)
    await OpenFile.open(filePath);

    return filePath;
  } catch (e) {
    debugPrint('[ReportsService] Erreur IO: $e');
    rethrow;
  }
}

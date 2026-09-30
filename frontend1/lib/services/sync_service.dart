// sync_service.dart
//
// Service de synchronisation Flutter ↔ Backend (qui pousse vers Supabase).
// Appelle les endpoints /sync/push, /sync/pull et /sync/status.

import 'package:dio/dio.dart' show DioException;
import 'package:frontend1/services/api_service.dart';
import 'package:frontend1/core/error_helper.dart';

class SyncStatus {
  final bool online;
  final int pendingCount;
  final int errorCount;
  final int syncedCount;
  final String? lastCheck;
  final String? error;

  const SyncStatus({
    required this.online,
    this.pendingCount = 0,
    this.errorCount = 0,
    this.syncedCount = 0,
    this.lastCheck,
    this.error,
  });

  factory SyncStatus.offline() => const SyncStatus(online: false);

  factory SyncStatus.fromJson(Map<String, dynamic> json) => SyncStatus(
        online: json['online'] as bool? ?? false,
        pendingCount: json['pending_count'] as int? ?? 0,
        errorCount: json['error_count'] as int? ?? 0,
        syncedCount: json['synced_count'] as int? ?? 0,
        lastCheck: json['last_check'] as String?,
        error: json['error'] as String?,
      );

  /// Icône à afficher dans le header
  String get statusIcon {
    if (!online) return '🔴';
    if (errorCount > 0) return '🟠';
    if (pendingCount > 0) return '🟡';
    return '🟢';
  }

  String get statusLabel {
    if (!online) return 'Hors ligne';
    if (errorCount > 0) return '$errorCount erreur(s)';
    if (pendingCount > 0) return '$pendingCount en attente';
    return 'Synchronisé';
  }
}

class SyncPushResult {
  final bool success;
  final int synced;
  final int errors;
  final bool online;
  final String message;

  const SyncPushResult({
    required this.success,
    required this.synced,
    required this.errors,
    required this.online,
    required this.message,
  });

  factory SyncPushResult.fromJson(Map<String, dynamic> json) => SyncPushResult(
        success: json['success'] as bool? ?? false,
        synced: json['synced'] as int? ?? 0,
        errors: json['errors'] as int? ?? 0,
        online: json['online'] as bool? ?? false,
        message: json['message'] as String? ?? '',
      );
}

class SyncService {
  static final _dio = ApiService();

  /// Retourne l'état de la synchronisation.
  static Future<SyncStatus> getStatus() async {
    try {
      final response = await _dio.get('/sync/status');
      if (response.statusCode == 200) {
        return SyncStatus.fromJson(response.data as Map<String, dynamic>);
      }
      return SyncStatus.offline();
    } on DioException {
      return SyncStatus.offline();
    } catch (_) {
      return SyncStatus.offline();
    }
  }

  /// Pousse les ventes locales vers Supabase via le backend.
  static Future<SyncPushResult> push() async {
    try {
      final response = await _dio.post('/sync/push');
      if (response.statusCode == 200) {
        return SyncPushResult.fromJson(response.data as Map<String, dynamic>);
      }
      return const SyncPushResult(
        success: false, synced: 0, errors: 1, online: false,
        message: 'Erreur serveur',
      );
    } on DioException catch (e) {
      return SyncPushResult(
        success: false, synced: 0, errors: 1, online: false,
        message: e.message ?? 'Connexion impossible',
      );
    } catch (e) {
      return SyncPushResult(
        success: false, synced: 0, errors: 1, online: false,
        message: ErrorHelper.extractErrorMessage(e),
      );
    }
  }

  /// Récupère les paramètres depuis Supabase.
  static Future<bool> pull() async {
    try {
      final response = await _dio.get('/sync/pull');
      return response.statusCode == 200 &&
          (response.data['success'] as bool? ?? false);
    } catch (_) {
      return false;
    }
  }
}

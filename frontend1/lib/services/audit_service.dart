import 'package:flutter/foundation.dart';
import 'package:frontend1/models/deletion_log.dart';
import 'package:frontend1/services/api_service.dart';

class AuditService {
  final ApiService _apiService = ApiService();

  /// Récupère le journal des suppressions (médicaments et factures)
  Future<List<DeletionLogEntry>> getDeletionLogs({
    String? entityType,
    String? search,
    int limit = 100,
    int offset = 0,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'limit': limit,
        'offset': offset,
      };
      if (entityType != null && entityType != 'all') {
        queryParams['entity_type'] = entityType;
      }
      if (search != null && search.trim().isNotEmpty) {
        queryParams['search'] = search.trim();
      }

      final response = await _apiService.get(
        '/admin/deletion-logs',
        queryParameters: queryParams,
      );

      final data = response.data;
      final items = (data['items'] as List<dynamic>?) ?? [];
      return items
          .map((item) => DeletionLogEntry.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[AuditService] Erreur getDeletionLogs: $e');
      rethrow;
    }
  }
}

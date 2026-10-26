import 'package:flutter/foundation.dart';
import 'package:frontend1/services/api_service.dart';

class GlobalSearchService {
  final ApiService _apiService = ApiService();

  /// Recherche globale unifiée (médicaments, clients, ventes, fournisseurs)
  Future<Map<String, dynamic>> search(String query, {int limitPerCategory = 5}) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) {
      return {
        'medicines': [],
        'customers': [],
        'sales': [],
        'suppliers': [],
        'total_results': 0,
      };
    }

    try {
      final response = await _apiService.get(
        '/search',
        queryParameters: {
          'q': trimmed,
          'limit_per_category': limitPerCategory,
        },
      );
      return response.data as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[GlobalSearchService] Erreur search: $e');
      rethrow;
    }
  }
}

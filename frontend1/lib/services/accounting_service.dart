import 'package:flutter/foundation.dart';
import 'package:frontend1/services/api_service.dart';

class AccountingService {
  final ApiService _apiService = ApiService();

  /// Récupère le journal des écritures comptables
  Future<Map<String, dynamic>> getJournal({
    DateTime? fromDate,
    DateTime? toDate,
    int limit = 100,
  }) async {
    try {
      final Map<String, dynamic> params = {'limit': limit};
      if (fromDate != null) {
        params['from_date'] = fromDate.toIso8601String().split('T').first;
      }
      if (toDate != null) {
        params['to_date'] = toDate.toIso8601String().split('T').first;
      }

      final response = await _apiService.get(
        '/accounting/journal',
        queryParameters: params,
      );
      return response.data as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[AccountingService] Erreur getJournal: $e');
      rethrow;
    }
  }

  /// Récupère la balance comptable synthétique
  Future<Map<String, dynamic>> getBalance({
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    try {
      final Map<String, dynamic> params = {};
      if (fromDate != null) {
        params['from_date'] = fromDate.toIso8601String().split('T').first;
      }
      if (toDate != null) {
        params['to_date'] = toDate.toIso8601String().split('T').first;
      }

      final response = await _apiService.get(
        '/accounting/balance',
        queryParameters: params,
      );
      return response.data as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[AccountingService] Erreur getBalance: $e');
      rethrow;
    }
  }
}

import 'package:flutter/foundation.dart';
import 'package:frontend1/services/api_service.dart';

class CustomerCreditsService {
  final ApiService _apiService = ApiService();

  /// Liste paginée des crédits clients
  Future<Map<String, dynamic>> getCredits({
    int page = 1,
    int pageSize = 50,
    String? status,
    int? customerId,
  }) async {
    try {
      final Map<String, dynamic> params = {
        'page': page,
        'page_size': pageSize,
      };
      if (status != null) params['status'] = status;
      if (customerId != null) params['customer_id'] = customerId;

      final response = await _apiService.get(
        '/credits/',
        queryParameters: params,
      );
      return response.data as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[CustomerCreditsService] Erreur getCredits: $e');
      rethrow;
    }
  }

  /// Synthèse globale des crédits
  Future<Map<String, dynamic>> getCreditSummary() async {
    try {
      final response = await _apiService.get('/credits/summary');
      return response.data as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[CustomerCreditsService] Erreur getCreditSummary: $e');
      rethrow;
    }
  }

  /// Enregistre un nouveau crédit client
  Future<Map<String, dynamic>> createCredit(Map<String, dynamic> data) async {
    try {
      final response = await _apiService.post('/credits/', data: data);
      return response.data as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[CustomerCreditsService] Erreur createCredit: $e');
      rethrow;
    }
  }

  /// Remboursement (partiel ou total) d'un crédit client
  Future<Map<String, dynamic>> payCredit(int creditId, Map<String, dynamic> data) async {
    try {
      final response = await _apiService.post('/credits/$creditId/pay', data: data);
      return response.data as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[CustomerCreditsService] Erreur payCredit: $e');
      rethrow;
    }
  }
}

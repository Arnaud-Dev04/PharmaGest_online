import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:frontend1/models/sale.dart';
import 'package:frontend1/services/api_service.dart';

class SalesService {
  final ApiService _apiService = ApiService();

  /// Créer une nouvelle vente
  Future<Map<String, dynamic>> createSale(Map<String, dynamic> saleData) async {
    try {
      final response = await _apiService.post(
        '/sales/create',
        data: saleData,
      );
      return response.data as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[SalesService] Erreur createSale: $e');
      rethrow;
    }
  }

  /// Annuler une vente
  Future<void> cancelSale(int saleId) async {
    try {
      await _apiService.post('/sales/$saleId/cancel');
    } catch (e) {
      debugPrint('[SalesService] Erreur cancelSale: $e');
      rethrow;
    }
  }

  /// Télécharger une facture (PDF)
  /// Retourne les bytes du PDF
  Future<List<int>> downloadInvoice(int saleId) async {
    try {
      final response = await _apiService.get(
        '/sales/$saleId/invoice',
        options: Options(
          responseType: ResponseType.bytes,
        ),
      );
      return response.data as List<int>;
    } catch (e) {
      debugPrint('[SalesService] Erreur downloadInvoice: $e');
      rethrow;
    }
  }

  /// Récupérer l'historique des ventes
  Future<SalesHistoryResponse> getSalesHistory({
    int page = 1,
    String? search,
    String? startDate,
    String? endDate,
    double? minAmount,
    double? maxAmount,
  }) async {
    try {
      final queryParams = <String, dynamic>{'page': page, 'page_size': 20};
      if (search != null) queryParams['search'] = search;
      if (startDate != null && startDate.isNotEmpty) queryParams['start_date'] = startDate;
      if (endDate != null && endDate.isNotEmpty) queryParams['end_date'] = endDate;
      if (minAmount != null) queryParams['min_amount'] = minAmount;
      if (maxAmount != null) queryParams['max_amount'] = maxAmount;

      final response = await _apiService.get(
        '/sales/history',
        queryParameters: queryParams,
      );
      return SalesHistoryResponse.fromJson(response.data);
    } catch (e) {
      debugPrint('[SalesService] Erreur getSalesHistory: $e');
      rethrow;
    }
  }

  /// Récupérer les statistiques de ventes par médicament
  Future<List<MedicineSaleStats>> getMedicineSalesStats({
    String? startDate,
    String? endDate,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (startDate != null && startDate.isNotEmpty) queryParams['start_date'] = startDate;
      if (endDate != null && endDate.isNotEmpty) queryParams['end_date'] = endDate;

      final response = await _apiService.get(
        '/sales/medicine-stats',
        queryParameters: queryParams,
      );
      
      return (response.data as List)
          .map((item) => MedicineSaleStats.fromJson(item))
          .toList();
    } catch (e) {
      debugPrint('[SalesService] Erreur getMedicineSalesStats: $e');
      rethrow;
    }
  }
}

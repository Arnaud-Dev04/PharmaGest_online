import 'package:flutter/foundation.dart';
import 'package:frontend1/services/api_service.dart';
import 'package:frontend1/models/medicine_pricing.dart';

/// Service pour le module de gestion des prix de médicaments
class MedicinePricingService {
  final ApiService _apiService = ApiService();

  /// Récupère la liste paginée des entrées de prix
  Future<PricingResponse> getPricings({
    int page = 1,
    int pageSize = 50,
    String? search,
    bool outOfStockOnly = false,
  }) async {
    try {
      final safePageSize = (pageSize > 100) ? 100 : (pageSize < 1 ? 50 : pageSize);
      final queryParams = <String, dynamic>{
        'page': page,
        'page_size': safePageSize,
      };
      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }
      if (outOfStockOnly) {
        queryParams['out_of_stock_only'] = true;
      }

      final response = await _apiService.get(
        '/pricing/entries',
        queryParameters: queryParams,
      );

      return PricingResponse.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[MedicinePricingService] Erreur getPricings: $e');
      rethrow;
    }
  }

  /// Crée une nouvelle entrée de prix
  Future<MedicinePricing> createPricing(Map<String, dynamic> data) async {
    try {
      final response = await _apiService.post('/pricing/entries', data: data);
      return MedicinePricing.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[MedicinePricingService] Erreur createPricing: $e');
      rethrow;
    }
  }

  /// Met à jour une entrée de prix
  Future<MedicinePricing> updatePricing(
    int id,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _apiService.put(
        '/pricing/entries/$id',
        data: data,
      );
      return MedicinePricing.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[MedicinePricingService] Erreur updatePricing: $e');
      rethrow;
    }
  }

  /// Supprime une entrée de prix
  Future<void> deletePricing(int id) async {
    try {
      await _apiService.delete('/pricing/entries/$id');
    } catch (e) {
      debugPrint('[MedicinePricingService] Erreur deletePricing: $e');
      rethrow;
    }
  }

  /// Récupère les alertes (péremption + stock faible)
  Future<Map<String, dynamic>> getAlerts() async {
    try {
      final response = await _apiService.get('/pricing/alerts');
      return response.data as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[MedicinePricingService] Erreur getAlerts: $e');
      rethrow;
    }
  }

  /// Auto-complétion des noms de médicaments
  Future<List<String>> autocompleteNames(String query) async {
    try {
      final response = await _apiService.get(
        '/pricing/autocomplete',
        queryParameters: {'q': query, 'limit': 10},
      );
      final data = response.data as Map<String, dynamic>;
      return List<String>.from(data['results'] ?? []);
    } catch (e) {
      debugPrint('[MedicinePricingService] Erreur autocomplete: $e');
      return [];
    }
  }

  /// Récupère les informations d'un `Medicine` par ID (inclut `quantity`).
  Future<Map<String, dynamic>?> getMedicineById(int id) async {
    try {
      final response = await _apiService.get('/stock/medicines/$id');
      return response.data as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[MedicinePricingService] Erreur getMedicineById: $e');
      return null;
    }
  }
}

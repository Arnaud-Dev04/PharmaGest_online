import 'package:flutter/foundation.dart';
import 'package:frontend1/services/api_service.dart';
import 'package:frontend1/models/medicine.dart';

/// Service pour la gestion du stock de médicaments
class StockService {
  final ApiService _apiService = ApiService();

  /// Récupère la liste paginée des médicaments
  /// [page] : Numéro de page (commence à 1)
  /// [search] : Terme de recherche optionnel
  Future<StockResponse> getMedicines({
    int page = 1,
    int limit = 10,
    String? search,
  }) async {
    try {
      final queryParams = <String, dynamic>{'page': page, 'page_size': limit};
      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }

      final response = await _apiService.get(
        '/stock/medicines',
        queryParameters: queryParams,
      );

      return StockResponse.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[StockService] Erreur getMedicines: $e');
      rethrow;
    }
  }

  /// Crée un nouveau médicament
  /// [data] : Map contenant tous les champs du formulaire
  Future<Medicine> createMedicine(Map<String, dynamic> data) async {
    try {
      final response = await _apiService.post('/stock/medicines', data: data);

      return Medicine.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[StockService] Erreur createMedicine: $e');
      rethrow;
    }
  }

  /// Met à jour un médicament existant
  /// [id] : ID du médicament
  /// [data] : Map contenant les champs à modifier
  Future<Medicine> updateMedicine(int id, Map<String, dynamic> data) async {
    try {
      final response = await _apiService.put(
        '/stock/medicines/$id',
        data: data,
      );

      return Medicine.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[StockService] Erreur updateMedicine: $e');
      rethrow;
    }
  }

  /// Supprime un médicament
  /// [id] : ID du médicament à supprimer
  Future<void> deleteMedicine(int id) async {
    try {
      await _apiService.delete('/stock/medicines/$id');
    } catch (e) {
      debugPrint('[StockService] Erreur deleteMedicine: $e');
      rethrow;
    }
  }
}

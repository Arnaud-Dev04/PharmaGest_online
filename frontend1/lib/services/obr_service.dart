import 'package:flutter/foundation.dart';
import 'package:frontend1/services/api_service.dart';

/// Service gérant la communication avec le backend pour l'intégration OBR EBMS.
class ObrService {
  final ApiService _apiService = ApiService();

  /// Récupère le statut actuel et les compteurs de synchronisation OBR
  Future<Map<String, dynamic>> getStatus() async {
    try {
      final response = await _apiService.get('/obr/status');
      return response.data as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[ObrService] Erreur getStatus: $e');
      rethrow;
    }
  }

  /// Teste la validité des identifiants OBR de la pharmacie
  Future<Map<String, dynamic>> testConnection() async {
    try {
      final response = await _apiService.post('/obr/test-connection');
      return response.data as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[ObrService] Erreur testConnection: $e');
      rethrow;
    }
  }

  /// Relance l'envoi des factures restées en attente ou en erreur
  Future<Map<String, dynamic>> resyncPendingInvoices() async {
    try {
      final response = await _apiService.post('/obr/resync-pending');
      return response.data as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[ObrService] Erreur resyncPendingInvoices: $e');
      rethrow;
    }
  }
}

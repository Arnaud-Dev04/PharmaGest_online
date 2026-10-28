import 'package:flutter/foundation.dart';
import 'package:frontend1/services/api_service.dart';

/// Service gérant la communication avec le backend pour l'intégration OBR EBMS V0.5.
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

  /// Met à jour les paramètres fiscaux OBR
  Future<Map<String, dynamic>> updateConfig(Map<String, dynamic> data) async {
    try {
      final response = await _apiService.put('/obr/config', data: data);
      return response.data as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[ObrService] Erreur updateConfig: $e');
      rethrow;
    }
  }

  /// Vérifie la validité d'un NIF auprès du serveur EBMS OBR (POST /checkTIN/)
  Future<Map<String, dynamic>> checkTIN(String tin) async {
    try {
      final response = await _apiService.post('/obr/check-tin', data: {'tin': tin.trim()});
      return response.data as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[ObrService] Erreur checkTIN: $e');
      rethrow;
    }
  }

  /// Annule une facture fiscale OBR (POST /cancelInvoice/)
  Future<Map<String, dynamic>> cancelInvoice({
    String? invoiceCode,
    String? invoiceIdentifier,
    required String motif,
  }) async {
    try {
      final response = await _apiService.post(
        '/obr/cancel-invoice',
        data: {
          if (invoiceCode != null && invoiceCode.isNotEmpty) 'invoice_code': invoiceCode,
          if (invoiceIdentifier != null && invoiceIdentifier.isNotEmpty)
            'invoice_identifier': invoiceIdentifier,
          'cn_motif': motif.trim(),
        },
      );
      return response.data as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[ObrService] Erreur cancelInvoice: $e');
      rethrow;
    }
  }

  /// Déclare un mouvement de stock à l'OBR (POST /AddStockMovement/)
  Future<Map<String, dynamic>> sendStockMovement(Map<String, dynamic> movementData) async {
    try {
      final response = await _apiService.post('/obr/stock-movement', data: movementData);
      return response.data as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[ObrService] Erreur sendStockMovement: $e');
      rethrow;
    }
  }
}

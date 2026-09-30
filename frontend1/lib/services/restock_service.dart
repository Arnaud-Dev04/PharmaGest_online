import 'package:frontend1/services/api_service.dart';
import 'package:frontend1/models/restock.dart';

class RestockService {
  final ApiService _api = ApiService();

  /// Récupérer les commandes (optionnel: filtrer par supplier_id)
  Future<List<RestockOrder>> getOrders({int? supplierId}) async {
    final response = await _api.get(
      '/restock/',
      queryParameters: supplierId != null ? {'supplier_id': supplierId} : null,
    );

    return (response.data as List)
        .map((json) => RestockOrder.fromJson(json))
        .toList();
  }

  /// Créer une commande
  Future<RestockOrder> createOrder(Map<String, dynamic> data) async {
    final response = await _api.post('/restock/', data: data);
    return RestockOrder.fromJson(response.data);
  }

  /// Confirmer une commande
  Future<RestockOrder> confirmOrder(int id) async {
    final response = await _api.post('/restock/$id/confirm');
    return RestockOrder.fromJson(response.data);
  }

  /// Annuler une commande
  Future<RestockOrder> cancelOrder(int id) async {
    final response = await _api.post('/restock/$id/cancel');
    return RestockOrder.fromJson(response.data);
  }

  /// Supprimer une commande (Draft uniquement)
  Future<void> deleteOrder(int id) async {
    await _api.delete('/restock/$id');
  }
}

import 'package:frontend1/services/api_service.dart';
import 'package:frontend1/models/supplier.dart';

class SupplierService {
  final ApiService _apiService = ApiService();

  Future<SupplierResponse> getSuppliers({int page = 1, int pageSize = 10, String? search}) async {
    final Map<String, dynamic> queryParams = {
      'page': page,
      'size': pageSize,
    };
    if (search != null && search.isNotEmpty) {
      queryParams['search'] = search;
    }

    final response = await _apiService.get('/suppliers', queryParameters: queryParams);
    return SupplierResponse.fromJson(response.data);
  }

  Future<Supplier> createSupplier(Map<String, dynamic> data) async {
    final response = await _apiService.post('/suppliers', data: data);
    return Supplier.fromJson(response.data);
  }

  Future<Supplier> updateSupplier(int id, Map<String, dynamic> data) async {
    final response = await _apiService.put('/suppliers/$id', data: data);
    return Supplier.fromJson(response.data);
  }

  Future<void> deleteSupplier(int id) async {
    await _apiService.delete('/suppliers/$id');
  }
}

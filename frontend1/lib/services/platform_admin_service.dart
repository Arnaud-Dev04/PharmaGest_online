import 'package:frontend1/models/pharmacy.dart';
import 'package:frontend1/services/api_service.dart';

class PlatformAdminService {
  final ApiService _api = ApiService();

  Future<PharmacyPage> getPharmacies({
    int page = 1,
    int pageSize = 25,
    String? search,
  }) async {
    final response = await _api.get(
      '/platform/pharmacies',
      queryParameters: {
        'page': page,
        'page_size': pageSize,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      },
    );
    return PharmacyPage.fromJson(response.data as Map<String, dynamic>);
  }

  Future<PlatformMetrics> getMetrics() async {
    final response = await _api.get('/platform/metrics');
    return PlatformMetrics.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Pharmacy> onboardPharmacy(Map<String, dynamic> data) async {
    final response = await _api.post('/platform/pharmacies', data: data);
    final body = response.data as Map<String, dynamic>;
    return Pharmacy.fromJson(body['pharmacy'] as Map<String, dynamic>);
  }

  Future<Pharmacy> updatePharmacy(int id, Map<String, dynamic> data) async {
    final response = await _api.put('/platform/pharmacies/$id', data: data);
    return Pharmacy.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Pharmacy> setPharmacyStatus(int id, bool isActive) async {
    final response = await _api.patch(
      '/platform/pharmacies/$id/status',
      data: {'is_active': isActive},
    );
    return Pharmacy.fromJson(response.data as Map<String, dynamic>);
  }
}
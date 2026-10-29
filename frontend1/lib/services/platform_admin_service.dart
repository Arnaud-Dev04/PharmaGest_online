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

  Future<List<PlatformAccount>> getAccounts() async {
    final response = await _api.get('/platform/accounts');
    return (response.data as List<dynamic>)
        .map((item) => PlatformAccount.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> createPlatformAccount({
    required String username,
    required String password,
  }) async {
    await _api.post(
      '/platform/accounts/platform-admin',
      data: {'username': username, 'password': password},
    );
  }

  Future<void> resetAdminPassword({
    required int userId,
    required String temporaryPassword,
    String? currentPassword,
  }) async {
    await _api.put(
      '/platform/accounts/$userId/password',
      data: {
        'temporary_password': temporaryPassword,
        if (currentPassword != null) 'current_password': currentPassword,
      },
    );
  }

  // Platform Admins Management
  Future<List<Map<String, dynamic>>> getPlatformAdmins() async {
    final response = await _api.get('/platform/admins');
    return (response.data as List<dynamic>).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>> createPlatformAdmin(Map<String, dynamic> data) async {
    final response = await _api.post('/platform/admins', data: data);
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> updatePlatformAdmin(int id, Map<String, dynamic> data) async {
    final response = await _api.put('/platform/admins/$id', data: data);
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<void> deletePlatformAdmin(int id) async {
    await _api.delete('/platform/admins/$id');
  }

  // License Keys Management
  Future<List<Map<String, dynamic>>> generateLicenseKeys({
    required String plan,
    required int durationDays,
    int maxUsers = 3,
    int quantity = 1,
    String? notes,
  }) async {
    final response = await _api.post(
      '/license/platform/generate',
      data: {
        'plan': plan,
        'duration_days': durationDays,
        'max_users': maxUsers,
        'quantity': quantity,
        'notes': notes,
      },
    );
    return (response.data as List<dynamic>).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<List<Map<String, dynamic>>> getLicenseKeys({String? plan, bool? isActive}) async {
    final response = await _api.get(
      '/license/platform/keys',
      queryParameters: {
        if (plan != null) 'plan': plan,
        if (isActive != null) 'is_active': isActive,
      },
    );
    return (response.data as List<dynamic>).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> revokeLicenseKey(int id) async {
    await _api.put('/license/platform/keys/$id/revoke');
  }
}

class PlatformAccount {
  final int id;
  final String username;
  final String role;
  final bool isActive;
  final bool mustChangePassword;
  final String? pharmacyName;

  const PlatformAccount({
    required this.id,
    required this.username,
    required this.role,
    required this.isActive,
    required this.mustChangePassword,
    this.pharmacyName,
  });

  factory PlatformAccount.fromJson(Map<String, dynamic> json) =>
      PlatformAccount(
        id: (json['id'] as num).toInt(),
        username: json['username']?.toString() ?? '',
        role: json['role']?.toString() ?? '',
        isActive: json['is_active'] as bool? ?? false,
        mustChangePassword: json['must_change_password'] as bool? ?? false,
        pharmacyName: json['pharmacy_name']?.toString(),
      );
}

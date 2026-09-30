import 'package:flutter/foundation.dart';
import 'package:frontend1/models/app_settings.dart';
import 'package:frontend1/services/api_service.dart';

class SettingsService {
  final ApiService _apiService = ApiService();

  Future<AppSettings> getSettings() async {
    try {
      final response = await _apiService.get('/settings');
      return AppSettings.fromJson(response.data);
    } catch (e) {
      debugPrint('[SettingsService] Erreur getSettings: $e');
      rethrow;
    }
  }

  Future<AppSettings> updateSettings(Map<String, dynamic> data) async {
    try {
      final response = await _apiService.put(
        '/settings',
        data: data,
      ); // ou PUT selon backend, React utilise POST ou PUT
      return AppSettings.fromJson(response.data);
    } catch (e) {
      debugPrint('[SettingsService] Erreur updateSettings: $e');
      rethrow;
    }
  }
}

class AdminService {
  final ApiService _apiService = ApiService();

  Future<Map<String, dynamic>> resetData({
    bool sales = false,
    bool products = false,
    bool users = false,
  }) async {
    try {
      final response = await _apiService.post(
        '/admin/reset',
        data: {'sales': sales, 'products': products, 'users': users},
      );
      return response.data;
    } catch (e) {
      debugPrint('[AdminService] Erreur resetData: $e');
      rethrow;
    }
  }

  /// Get current license status
  /// Public endpoint - no authentication required
  Future<Map<String, dynamic>> getLicenseStatus() async {
    try {
      final response = await _apiService.get('/license/status');
      return response.data;
    } catch (e) {
      debugPrint('[AdminService] Erreur getLicenseStatus: $e');
      rethrow;
    }
  }

  /// Update license configuration (Super Admin only)
  /// Works even when license is expired
  Future<Map<String, dynamic>> updateLicense({
    required String expirationDate,
    int? warningDays,
    String? warningMessage,
  }) async {
    try {
      final data = {
        'expiration_date': expirationDate,
        if (warningDays != null) 'warning_days': warningDays,
        if (warningMessage != null) 'warning_message': warningMessage,
      };
      
      final response = await _apiService.put(
        '/license/update',
        data: data,
      );
      return response.data;
    } catch (e) {
      debugPrint('[AdminService] Erreur updateLicense: $e');
      rethrow;
    }
  }

  /// Changer le mot de passe de l'utilisateur connecté
  /// Le super_admin n'a pas besoin de fournir l'ancien mot de passe
  Future<Map<String, dynamic>> changePassword({
    required String newPassword,
    String? currentPassword,
    required String token,
  }) async {
    try {
      final response = await _apiService.post(
        '/auth/change-password',
        data: {
          'new_password': newPassword,
          if (currentPassword != null) 'current_password': currentPassword,
        },
      );
      return response.data;
    } catch (e) {
      debugPrint('[AdminService] Erreur changePassword: $e');
      rethrow;
    }
  }
}

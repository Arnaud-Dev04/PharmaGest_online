import 'package:flutter/material.dart';
import 'package:frontend1/services/api_service.dart';

class LicenseStatus {
  final bool isValid;
  final bool isExpired;
  final int daysRemaining;
  final String message;

  LicenseStatus({
    required this.isValid,
    required this.isExpired,
    required this.daysRemaining,
    required this.message,
  });

  factory LicenseStatus.fromJson(Map<String, dynamic> json) {
    return LicenseStatus(
      isValid: json['is_valid'] ?? true,
      isExpired: json['is_expired'] ?? false,
      daysRemaining: json['days_remaining'] ?? 999,
      message: json['message'] ?? '',
    );
  }
}

class LicenseProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  LicenseStatus? _status;
  bool _loading = false;
  bool _hasShownWarningThisSession = false;

  LicenseStatus? get status => _status;
  bool get isLoading => _loading;
  bool get hasShownWarningThisSession => _hasShownWarningThisSession;

  void markWarningAsShown() {
    _hasShownWarningThisSession = true;
    notifyListeners();
  }

  Future<void> checkLicense() async {
    _loading = true;
    notifyListeners();

    try {
      // On suppose l'endpoint /license/status ou /server/license
      // Si le backend n'a pas cet endpoint, on try-catch silencieux
      final response = await _apiService.get('/license/status');
      _status = LicenseStatus.fromJson(response.data);
    } catch (e) {
      debugPrint('License check failed: $e');
      // Fallback: Licence valide par défaut pour ne pas bloquer si l'endpoint n'existe pas encore
      _status = LicenseStatus(
        isValid: true,
        isExpired: false,
        daysRemaining: 999,
        message: '',
      );
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}

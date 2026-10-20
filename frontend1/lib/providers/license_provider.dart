import 'package:flutter/material.dart';
import 'package:frontend1/services/api_service.dart';

class LicenseStatus {
  final bool isValid;
  final bool isExpired;
  final int daysRemaining;
  final String message;
  final String plan;
  final int activeUsers;
  final int maxUsers;
  final Set<String> availableFeatures;

  LicenseStatus({
    required this.isValid,
    required this.isExpired,
    required this.daysRemaining,
    required this.message,
    required this.plan,
    required this.activeUsers,
    required this.maxUsers,
    required this.availableFeatures,
  });

  factory LicenseStatus.fromJson(Map<String, dynamic> json) {
    return LicenseStatus(
      isValid: json['is_valid'] ?? true,
      isExpired: json['is_expired'] ?? false,
      daysRemaining: json['days_remaining'] ?? 999,
      message: json['message'] ?? '',
      plan: json['plan'] ?? '',
      activeUsers: json['active_users'] ?? 0,
      maxUsers: json['max_users'] ?? 0,
      availableFeatures: (json['available_features'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toSet(),
    );
  }
}

class LicenseProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  LicenseStatus? _status;
  bool _loading = false;
  bool _hasShownWarningThisSession = false;
  String? _lastCheckedUser;
  DateTime? _lastCheckedAt;

  LicenseStatus? get status => _status;
  bool get isLoading => _loading;
  bool get hasShownWarningThisSession => _hasShownWarningThisSession;
  bool hasFeature(String feature) =>
      _status?.availableFeatures.contains(feature) ?? false;

  void markWarningAsShown() {
    _hasShownWarningThisSession = true;
    notifyListeners();
  }

  Future<void> checkLicense({String? userKey, bool force = false}) async {
    final now = DateTime.now();
    if (!force &&
        userKey != null &&
        userKey == _lastCheckedUser &&
        _lastCheckedAt != null &&
        now.difference(_lastCheckedAt!) < const Duration(minutes: 1)) {
      return;
    }
    _loading = true;
    notifyListeners();

    try {
      // On suppose l'endpoint /license/status ou /server/license
      // Si le backend n'a pas cet endpoint, on try-catch silencieux
      final response = await _apiService.get('/license/status');
      _status = LicenseStatus.fromJson(response.data);
      if (userKey != null) {
        _lastCheckedUser = userKey;
        _lastCheckedAt = DateTime.now();
      }
    } catch (e) {
      debugPrint('License check failed: $e');
      // Fallback: Licence valide par défaut pour ne pas bloquer si l'endpoint n'existe pas encore
      _status = LicenseStatus(
        isValid: true,
        isExpired: false,
        daysRemaining: 999,
        message: '',
        plan: '',
        activeUsers: 0,
        maxUsers: 0,
        availableFeatures: const {},
      );
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}

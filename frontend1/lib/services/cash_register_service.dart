import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:frontend1/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Client for the cashier-session API.
class CashRegisterService {
  final ApiService _api = ApiService();

  String _cacheKey(String cashier) => 'cash_register_session_$cashier';

  Future<Map<String, dynamic>?> getCurrentSession({String cashier = ''}) async {
    try {
      final response = await _api.get('/cash-register/current');
      if (response.data == null) {
        if (cashier.isNotEmpty) {
          await (await SharedPreferences.getInstance()).remove(
            _cacheKey(cashier),
          );
        }
        return null;
      }
      final session = Map<String, dynamic>.from(response.data as Map);
      await _cacheSession(session, cashier);
      return session;
    } on DioException catch (error) {
      final isNetworkError = {
        DioExceptionType.connectionError,
        DioExceptionType.connectionTimeout,
        DioExceptionType.receiveTimeout,
        DioExceptionType.sendTimeout,
      }.contains(error.type);
      if (!isNetworkError) rethrow;
      if (cashier.isEmpty) rethrow;
      final cached = (await SharedPreferences.getInstance()).getString(
        _cacheKey(cashier),
      );
      if (cached == null) rethrow;
      return Map<String, dynamic>.from(
        (jsonDecode(cached) as Map).cast<String, dynamic>(),
      );
    }
  }

  Future<Map<String, dynamic>> openSession({
    required double openingAmount,
    String? notes,
    String cashier = '',
  }) async {
    final response = await _api.post(
      '/cash-register/open',
      data: {'opening_amount': openingAmount, 'notes': _optional(notes)},
    );
    final session = Map<String, dynamic>.from(response.data as Map);
    await _cacheSession(session, cashier);
    return session;
  }

  Future<Map<String, dynamic>> addMovement({
    required int sessionId,
    required String movementType,
    required double amount,
    required String reason,
    String cashier = '',
  }) async {
    final response = await _api.post(
      '/cash-register/$sessionId/movements',
      data: {
        'movement_type': movementType,
        'amount': amount,
        'reason': reason.trim(),
      },
    );
    final session = Map<String, dynamic>.from(response.data as Map);
    await _cacheSession(session, cashier);
    return session;
  }

  Future<Map<String, dynamic>> closeSession({
    required int sessionId,
    required double countedAmount,
    String? notes,
    String cashier = '',
  }) async {
    final response = await _api.post(
      '/cash-register/$sessionId/close',
      data: {'counted_amount': countedAmount, 'notes': _optional(notes)},
    );
    final session = Map<String, dynamic>.from(response.data as Map);
    await _cacheSession(session, cashier);
    return session;
  }

  Future<Map<String, dynamic>> getSessions({
    int page = 1,
    int pageSize = 25,
    String? status,
  }) async {
    final response = await _api.get(
      '/cash-register/sessions',
      queryParameters: {
        'page': page,
        'page_size': pageSize,
        if (status != null) 'status_filter': status,
      },
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  static String? _optional(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  Future<void> cacheOpenSession(Map<String, dynamic> session, String cashier) =>
      _cacheSession(session, cashier);

  Future<void> clearCachedSession(String cashier) async {
    await (await SharedPreferences.getInstance()).remove(_cacheKey(cashier));
  }

  Future<void> _cacheSession(
    Map<String, dynamic> session,
    String cashier,
  ) async {
    if (cashier.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    if (session['status'] == 'open') {
      await prefs.setString(_cacheKey(cashier), jsonEncode(session));
    } else {
      await prefs.remove(_cacheKey(cashier));
    }
  }
}

String cashRegisterErrorMessage(Object error) {
  if (error is DioException) {
    final detail = error.response?.data;
    if (detail is Map && detail['detail'] != null) {
      return detail['detail'].toString();
    }
    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return 'Serveur inaccessible. Réessayez lorsque la connexion est rétablie.';
    }
  }
  return error.toString();
}

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:frontend1/core/constants.dart';
import 'package:frontend1/main.dart'; // For scaffoldMessengerKey
import 'package:flutter/material.dart'; // For SnackBar colors
import 'package:frontend1/core/error_helper.dart';

/// Service API centralisé utilisant Dio
/// Gère les intercepteurs JWT pour l'authentification
class ApiService {
  late final Dio _dio;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  // Singleton pattern
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  ApiService._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.apiBaseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // Ajouter les intercepteurs
    _dio.interceptors.add(_AuthInterceptor(_secureStorage, _dio));
    _dio.interceptors.add(_ErrorInterceptor());
    _dio.interceptors.add(
      LogInterceptor(
        request: true,
        requestHeader: true,
        requestBody: true,
        responseHeader: false,
        responseBody: true,
        error: true,
        logPrint: (obj) => debugPrint('[API] $obj'),
      ),
    );
  }

  /// Instance Dio pour accès direct si nécessaire
  Dio get dio => _dio;

  /// GET request
  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return await _dio.get(
      path,
      queryParameters: queryParameters,
      options: options,
    );
  }

  /// POST request
  Future<Response> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return await _dio.post(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  /// PUT request
  Future<Response> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return await _dio.put(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  /// DELETE request
  Future<Response> delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return await _dio.delete(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  /// PATCH request
  Future<Response> patch(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return await _dio.patch(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }
}

/// Intercepteur pour ajouter le token JWT aux requêtes et renouveler automatiquement les sessions expirées (401)
class _AuthInterceptor extends QueuedInterceptor {
  final FlutterSecureStorage _storage;
  final Dio _dio;

  _AuthInterceptor(this._storage, this._dio);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Récupérer le token depuis le secure storage
    final token = await _storage.read(key: 'auth_token');

    if (token != null) {
      // Ajouter le header Authorization
      options.headers['Authorization'] = 'Bearer $token';
    }

    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode == 401) {
      final path = err.requestOptions.path;
      // Ne pas renouveler si la requête est déjà une tentative d'authentification
      if (!path.contains('/auth/login') &&
          !path.contains('/auth/refresh') &&
          !path.contains('/auth/forgot-password')) {
        final refreshToken = await _storage.read(key: 'refresh_token');

        if (refreshToken != null && refreshToken.isNotEmpty) {
          try {
            // Instance séparée pour éviter les boucles d'interception
            final refreshDio = Dio(
              BaseOptions(
                baseUrl: AppConstants.apiBaseUrl,
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 15),
                headers: {
                  'Content-Type': 'application/json',
                  'Accept': 'application/json',
                },
              ),
            );

            final response = await refreshDio.post(
              '/auth/refresh',
              data: {'refresh_token': refreshToken},
            );

            if (response.statusCode == 200 && response.data != null) {
              final newAccessToken = response.data['access_token'] as String;
              final newRefreshToken = response.data['refresh_token'] as String?;

              await _storage.write(key: 'auth_token', value: newAccessToken);
              if (newRefreshToken != null && newRefreshToken.isNotEmpty) {
                await _storage.write(key: 'refresh_token', value: newRefreshToken);
              }

              // Mettre à jour le header de la requête en échec et la relancer
              err.requestOptions.headers['Authorization'] = 'Bearer $newAccessToken';
              final clonedResponse = await _dio.fetch(err.requestOptions);
              return handler.resolve(clonedResponse);
            }
          } catch (e) {
            debugPrint('[_AuthInterceptor] Échec du rafraîchissement automatique: $e');
            await _storage.delete(key: 'auth_token');
            await _storage.delete(key: 'refresh_token');
          }
        }
      }
    }

    handler.next(err);
  }
}

/// Intercepteur pour gérer les erreurs globalement
class _ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // Gérer les erreurs 401 Unauthorized
    if (err.response?.statusCode == 401) {
      debugPrint('[API] 401 Unauthorized - Token invalide ou expiré');
      // La déconnexion sera gérée par AuthProvider
      // qui écoute les erreurs 401
    }

    // Gérer les erreurs réseau
    if (err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.sendTimeout) {
      debugPrint('[API] Erreur de connexion : ${err.message}');
    }

    if (err.type == DioExceptionType.connectionError) {
      debugPrint('[API] Impossible de se connecter au serveur');
    }

    String errorMessage = ErrorHelper.extractErrorMessage(err);
    Color bgColor = Colors.red;

    if (err.response != null) {
      final code = err.response?.statusCode;
      if (code == 400) {
        bgColor = Colors.orange;
      } else if (code == 401) {
        bgColor = Colors.blueGrey;
      } else if (code == 403) {
        bgColor = Colors.orangeAccent;
      } else if (code == 404) {
        bgColor = Colors.grey;
      } else if (code == 422) {
        bgColor = Colors.orange;
      } else if (code == 500) {
        bgColor = Colors.red[900]!;
      }
    }

    // Afficher le message (si la vue est montée)
    final messenger = scaffoldMessengerKey.currentState;
    if (messenger != null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            errorMessage,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: bgColor,
          behavior: SnackBarBehavior.floating, // Flottant pour être plus joli
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: const EdgeInsets.all(10),
          duration: const Duration(seconds: 4),
        ),
      );
    }

    handler.next(err);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    // Log les réponses réussies (optionnel en production)
    if (response.statusCode == 200 || response.statusCode == 201) {
      debugPrint(
        '[API]  ${response.requestOptions.method} ${response.requestOptions.path} - Success',
      );
    }

    handler.next(response);
  }
}

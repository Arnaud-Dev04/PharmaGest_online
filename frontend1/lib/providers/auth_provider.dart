import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:frontend1/models/user.dart';
import 'package:frontend1/services/auth_service.dart';
import 'package:frontend1/core/error_helper.dart';

/// Provider pour gérer l'état d'authentification
/// Utilise ChangeNotifier pour notifier les widgets des changements d'état
class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  // État
  User? _user;
  String? _token;
  bool _isLoading = true;
  String? _errorMessage;
  bool _mustChangePassword = false;
  bool _isFirstSetup = false;

  // Getters
  User? get user => _user;
  String? get token => _token;
  bool get isAuthenticated => _token != null && _user != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get mustChangePassword => _mustChangePassword;
  bool get isFirstSetup => _isFirstSetup;

  /// Initialiser l'authentification au démarrage de l'app
  /// Vérifie si un token existe et s'il est valide
  Future<void> initAuth() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Récupérer le token sauvegardé
      final savedToken = await _secureStorage.read(key: 'auth_token');

      if (savedToken != null) {
        _token = savedToken;

        // Récupérer les flags sauvegardés
        final savedMustChange = await _secureStorage.read(key: 'must_change_password');
        final savedFirstSetup = await _secureStorage.read(key: 'is_first_setup');
        _mustChangePassword = savedMustChange == 'true';
        _isFirstSetup = savedFirstSetup == 'true';

        // Vérifier si le token est valide en récupérant l'utilisateur
        try {
          final userData = await _authService.getCurrentUser();
          _user = userData;
          // Mettre à jour must_change_password depuis le serveur
          _mustChangePassword = userData.mustChangePassword;
        } catch (e) {
          // Token invalide ou expiré, on le supprime
          debugPrint('[AuthProvider] Token invalide: $e');
          await _clearAuthData();
        }
      }
    } catch (e) {
      debugPrint('[AuthProvider] Erreur lors de l\'initialisation: $e');
      await _clearAuthData();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Connexion avec username et password
  Future<bool> login(String username, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. Appeler l'API de login pour obtenir le token et les flags
      final loginResult = await _authService.login(username, password);
      final accessToken = loginResult['access_token'] as String;
      _token = accessToken;
      _mustChangePassword = loginResult['must_change_password'] as bool;
      _isFirstSetup = loginResult['is_first_setup'] as bool;

      // 2. Sauvegarder le token et les flags
      await _secureStorage.write(key: 'auth_token', value: accessToken);
      await _secureStorage.write(
        key: 'must_change_password',
        value: _mustChangePassword.toString(),
      );
      await _secureStorage.write(
        key: 'is_first_setup',
        value: _isFirstSetup.toString(),
      );

      // 3. Récupérer les informations de l'utilisateur
      final userData = await _authService.getCurrentUser();
      _user = userData;

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = ErrorHelper.extractErrorMessage(e).replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Changer le mot de passe initial (première connexion)
  Future<bool> changeInitialPassword(
    String newPassword,
    String confirmPassword,
  ) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _authService.changeInitialPassword(
        newPassword,
        confirmPassword,
      );

      // Mettre à jour le token si retourné
      if (result['access_token'] != null) {
        _token = result['access_token'] as String;
        await _secureStorage.write(key: 'auth_token', value: _token!);
      }

      _mustChangePassword = false;
      await _secureStorage.write(key: 'must_change_password', value: 'false');

      // Rafraîchir l'utilisateur
      final userData = await _authService.getCurrentUser();
      _user = userData;

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = ErrorHelper.extractErrorMessage(e).replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Marquer la configuration initiale comme terminée
  Future<bool> completeSetup() async {
    try {
      await _authService.completeSetup();
      _isFirstSetup = false;
      await _secureStorage.write(key: 'is_first_setup', value: 'false');
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = ErrorHelper.extractErrorMessage(e).replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  /// Déconnexion
  Future<void> logout() async {
    await _clearAuthData();
    notifyListeners();
  }

  /// Rafraîchir les données de l'utilisateur
  Future<void> refreshUser() async {
    if (!isAuthenticated) return;

    try {
      final userData = await _authService.getCurrentUser();
      _user = userData;
      notifyListeners();
    } catch (e) {
      debugPrint('[AuthProvider] Erreur lors du rafraîchissement: $e');
      // Si l'erreur est 401 (session expirée), déconnecter l'utilisateur
      bool is401 = false;
      if (e is Exception) {
        final msg = ErrorHelper.extractErrorMessage(e);
        is401 = msg.contains('Session expirée') || msg.contains('reconnecter');
      }
      if (is401) {
        await logout();
      }
    }
  }

  /// Supprimer toutes les données d'authentification
  Future<void> _clearAuthData() async {
    _user = null;
    _token = null;
    _errorMessage = null;
    _mustChangePassword = false;
    _isFirstSetup = false;
    await _secureStorage.delete(key: 'auth_token');
    await _secureStorage.delete(key: 'user_data');
    await _secureStorage.delete(key: 'must_change_password');
    await _secureStorage.delete(key: 'is_first_setup');
  }

  /// Réinitialiser le message d'erreur
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}

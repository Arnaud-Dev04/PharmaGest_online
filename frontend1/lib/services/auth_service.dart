import 'package:dio/dio.dart';
import 'package:frontend1/services/api_service.dart';
import 'package:frontend1/models/user.dart';

/// Service d'authentification
/// Gère les requêtes d'authentification vers le backend FastAPI
class AuthService {
  final ApiService _apiService = ApiService();

  /// Login avec username et password
  /// Retourne un Map contenant le token, must_change_password et is_first_setup
  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      // Préparer les données en format form-urlencoded
      // Le backend FastAPI attend ce format pour OAuth2PasswordRequestForm
      final formData = {'username': username, 'password': password};

      final response = await _apiService.post(
        '/auth/login',
        data: formData,
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );

      return {
        'access_token': response.data['access_token'] as String,
        'must_change_password': response.data['must_change_password'] as bool? ?? false,
        'is_first_setup': response.data['is_first_setup'] as bool? ?? false,
      };
    } on DioException catch (e) {
      // Gérer les erreurs spécifiques
      if (e.response?.statusCode == 401) {
        throw Exception('Identifiants incorrects');
      } else if (e.response?.statusCode == 400) {
        throw Exception('Requête invalide');
      } else if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout) {
        throw Exception('Impossible de se connecter au serveur');
      }
      throw Exception('Erreur lors de la connexion: ${e.message}');
    } catch (e) {
      throw Exception('Erreur inattendue: $e');
    }
  }

  /// Récupérer les informations de l'utilisateur connecté
  /// Nécessite un token JWT valide
  Future<User> getCurrentUser() async {
    try {
      final response = await _apiService.get('/auth/me');
      return User.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw Exception('Session expirée. Veuillez vous reconnecter.');
      }
      throw Exception('Erreur lors de la récupération du profil: ${e.message}');
    } catch (e) {
      throw Exception('Erreur inattendue: $e');
    }
  }

  /// Vérifier si le token est valide
  /// Retourne true si le token est valide, false sinon
  Future<bool> validateToken() async {
    try {
      await getCurrentUser();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Changer le mot de passe lors de la première connexion
  Future<Map<String, dynamic>> changeInitialPassword(
    String newPassword,
    String confirmPassword,
  ) async {
    try {
      final response = await _apiService.post(
        '/auth/change-initial-password',
        data: {
          'new_password': newPassword,
          'confirm_password': confirmPassword,
        },
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      if (e.response?.statusCode == 400) {
        final detail = e.response?.data['detail'] ?? 'Erreur de validation';
        throw Exception(detail);
      }
      throw Exception('Erreur: ${e.message}');
    }
  }

  /// Marquer la configuration initiale comme terminée (Super Admin)
  Future<void> completeSetup() async {
    try {
      await _apiService.post('/auth/complete-setup');
    } on DioException catch (e) {
      throw Exception('Erreur: ${e.message}');
    }
  }
}

import 'package:dio/dio.dart';

class ErrorHelper {
  static String extractErrorMessage(Object e) {
    if (e is DioException) {
      if (e.response != null) {
        final statusCode = e.response?.statusCode;
        final data = e.response?.data;
        
        if (statusCode == 400) {
          return _extractDetail(data) ?? "Requête invalide (Vérifiez les données saisies).";
        } else if (statusCode == 401) {
          return _extractDetail(data) ?? "Session expirée ou identifiants incorrects. Veuillez vous reconnecter.";
        } else if (statusCode == 403) {
          return "Accès refusé. Vous n'avez pas les droits nécessaires pour effectuer cette action.";
        } else if (statusCode == 404) {
          return _extractDetail(data) ?? "L'élément demandé est introuvable.";
        } else if (statusCode == 422) {
          return "Données invalides : Veuillez vérifier que tous les champs obligatoires sont correctement remplis.";
        } else if (statusCode == 500) {
          return "Erreur interne du serveur. Veuillez réessayer plus tard.";
        }
        return _extractDetail(data) ?? "Erreur serveur ($statusCode).";
      } else {
        if (e.type == DioExceptionType.connectionTimeout || 
            e.type == DioExceptionType.receiveTimeout) {
          return "Le serveur met trop de temps à répondre. Vérifiez votre connexion.";
        } else if (e.type == DioExceptionType.connectionError) {
          return "Impossible de se connecter au serveur. Vérifiez votre connexion réseau.";
        }
        return "Erreur de connexion au serveur.";
      }
    }
    
    // Fallback pour les erreurs non-Dio
    final raw = e.toString();
    final m = RegExp(r'detail["\s]*:["\s]*(.{0,300})', caseSensitive: false).firstMatch(raw);
    if (m != null) return m.group(1)?.replaceAll(RegExp(r'[\[\]"\\]'), '').trim() ?? raw;
    return raw;
  }

  static String? _extractDetail(dynamic data) {
    if (data is Map<String, dynamic> && data.containsKey('detail')) {
      var detail = data['detail'];
      if (detail is String) return detail;
      if (detail is List && detail.isNotEmpty) {
        // Souvent une liste d'erreurs Pydantic pour 422
        return "Vérifiez les informations saisies (données invalides ou incomplètes).";
      }
    }
    return null;
  }
}

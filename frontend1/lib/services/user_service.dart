import 'package:flutter/foundation.dart';
import 'package:frontend1/models/user.dart';
import 'package:frontend1/models/user_stats.dart';
import 'package:frontend1/services/api_service.dart';

class UserService {
  final ApiService _apiService = ApiService();

  Future<List<User>> getUsers() async {
    try {
      final response = await _apiService.get('/auth/users');
      return (response.data as List).map((i) => User.fromJson(i)).toList();
    } catch (e) {
      debugPrint('[UserService] Erreur getUsers: $e');
      rethrow;
    }
  }

  Future<UserStats> getUserStats(
    int id,
    String startDate,
    String endDate,
  ) async {
    try {
      final response = await _apiService.get(
        '/users/$id/stats',
        queryParameters: {'start_date': startDate, 'end_date': endDate},
      );
      return UserStats.fromJson(response.data);
    } catch (e) {
      debugPrint('[UserService] Erreur getUserStats: $e');
      rethrow;
    }
  }

  Future<User> createUser(Map<String, dynamic> data) async {
    try {
      final response = await _apiService.post(
        '/auth/register',
        data: data,
      ); // Ou /users/create selon backend, React use userService.create qui pointe vers auth/register ou users/
      // React userService.create -> api.post('/users/') usually. Mais si c'est pour register, c'est souvent auth.
      // Backend users.py a POST /users/
      return User.fromJson(response.data);
    } catch (e) {
      debugPrint('[UserService] Erreur createUser: $e');
      rethrow;
    }
  }

  Future<User> updateUser(int id, Map<String, dynamic> data) async {
    try {
      final response = await _apiService.put('/users/$id', data: data);
      return User.fromJson(response.data);
    } catch (e) {
      debugPrint('[UserService] Erreur updateUser: $e');
      rethrow;
    }
  }

  Future<void> deleteUser(int id) async {
    try {
      await _apiService.delete('/users/$id');
    } catch (e) {
      debugPrint('[UserService] Erreur deleteUser: $e');
      rethrow;
    }
  }

  Future<void> toggleStatus(int id) async {
    try {
      await _apiService.post('/users/$id/toggle-status');
    } catch (e) {
      debugPrint('[UserService] Erreur toggleStatus: $e');
      rethrow;
    }
  }

  Future<void> updatePassword(int id, String newPassword) async {
    try {
      await _apiService.post(
        '/users/$id/password',
        data: {'password': newPassword},
      );
    } catch (e) {
      debugPrint('[UserService] Erreur updatePassword: $e');
      rethrow;
    }
  }
}

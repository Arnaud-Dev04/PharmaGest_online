class User {
  final int id;
  final String username;
  final String email;
  final String role; // 'admin', 'pharmacist', 'super_admin'
  final bool isActive;
  final bool mustChangePassword;
  final DateTime? createdAt;

  bool get isAdmin => role == 'admin' || role == 'super_admin';
  bool get isSuperAdmin => role == 'super_admin';

  User({
    required this.id,
    required this.username,
    this.email = '',
    required this.role,
    this.isActive = true,
    this.mustChangePassword = false,
    this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int? ?? 0,
      username: json['username']?.toString() ?? 'Inconnu',
      email: json['email']?.toString() ?? '',
      role: json['role']?.toString() ?? 'pharmacist',
      isActive: json['is_active'] as bool? ?? true,
      mustChangePassword: json['must_change_password'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'role': role,
      'is_active': isActive,
      'must_change_password': mustChangePassword,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}

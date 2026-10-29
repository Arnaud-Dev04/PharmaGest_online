class User {
  final int id;
  final String username;
  final String email;
  final String role;
  final List<String>? allowedFeatures; // 'admin', 'pharmacist', 'super_admin'
  final bool isActive;
  final bool mustChangePassword;
  final int? pharmacyId;
  final DateTime? createdAt;

  bool get isAdmin => role == 'admin' || role == 'super_admin';
  bool get isSuperAdmin => role == 'super_admin';

  User({
    required this.id,
    required this.username,
    this.email = '',
    required this.role,
    this.allowedFeatures,
    this.isActive = true,
    this.mustChangePassword = false,
    this.pharmacyId,
    this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int? ?? 0,
      username: json['username']?.toString() ?? 'Inconnu',
      email: json['email']?.toString() ?? '',
      role: json['role']?.toString() ?? 'pharmacist',
      allowedFeatures: (json['allowed_features'] as List<dynamic>?)?.map((e) => e.toString()).toList(),
      isActive: json['is_active'] as bool? ?? true,
      mustChangePassword: json['must_change_password'] as bool? ?? false,
      pharmacyId: json['pharmacy_id'] as int?,
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
      'pharmacy_id': pharmacyId,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}

/// Modèle de données pour une entrée du journal des suppressions
class DeletionLogEntry {
  final int id;
  final String action;
  final String entityType;
  final int? entityId;
  final String entityName;
  final int? userId;
  final String username;
  final String? userRole;
  final String? details;
  final DateTime? createdAt;

  const DeletionLogEntry({
    required this.id,
    required this.action,
    required this.entityType,
    this.entityId,
    required this.entityName,
    this.userId,
    required this.username,
    this.userRole,
    this.details,
    this.createdAt,
  });

  factory DeletionLogEntry.fromJson(Map<String, dynamic> json) {
    return DeletionLogEntry(
      id: json['id'] as int? ?? 0,
      action: json['action'] as String? ?? '',
      entityType: json['entity_type'] as String? ?? '',
      entityId: json['entity_id'] as int?,
      entityName: json['entity_name'] as String? ?? 'N/A',
      userId: json['user_id'] as int?,
      username: json['username'] as String? ?? 'Inconnu',
      userRole: json['user_role'] as String?,
      details: json['details'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }
}

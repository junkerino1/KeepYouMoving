/// Model for a user account returned by the backend.
library;

class Account {
  final String id;
  final String email;
  final String fullName;
  final String? googlePictureUrl;
  final bool isAdmin;
  final DateTime? lastLoginAt;
  final DateTime createdAt;

  const Account({
    required this.id,
    required this.email,
    required this.fullName,
    this.googlePictureUrl,
    required this.isAdmin,
    this.lastLoginAt,
    required this.createdAt,
  });

  factory Account.fromJson(Map<String, dynamic> json) {
    return Account(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      googlePictureUrl: json['google_picture_url'] as String?,
      isAdmin: json['is_admin'] as bool? ?? false,
      lastLoginAt: json['last_login_at'] != null
          ? DateTime.tryParse(json['last_login_at'] as String)
          : null,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

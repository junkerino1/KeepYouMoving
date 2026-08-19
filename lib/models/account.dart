/// Model for a user account returned by the backend.
library;

import '../utils/format.dart';

class Account {
  final String id;
  final String email;
  final String fullName;
  final String? dateOfBirth;
  final String? profileMediaId;
  final String? googlePictureUrl;
  final String? profilePictureUrl;
  final bool isAdmin;
  final DateTime? lastLoginAt;
  final DateTime createdAt;

  const Account({
    required this.id,
    required this.email,
    required this.fullName,
    this.dateOfBirth,
    this.profileMediaId,
    this.googlePictureUrl,
    this.profilePictureUrl,
    required this.isAdmin,
    this.lastLoginAt,
    required this.createdAt,
  });

  factory Account.fromJson(Map<String, dynamic> json) {
    return Account(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      dateOfBirth: json['date_of_birth'] as String?,
      profileMediaId: json['profile_media_id'] as String?,
      googlePictureUrl: json['google_picture_url'] as String?,
      profilePictureUrl: json['profile_picture_url'] as String?,
      isAdmin: json['is_admin'] as bool? ?? false,
      lastLoginAt: json['last_login_at'] != null
          ? parseUtcToLocal(json['last_login_at'])
          : null,
      createdAt: parseUtcToLocal(json['created_at']) ?? DateTime.now(),
    );
  }

  Account copyWith({
    String? fullName,
    String? dateOfBirth,
    String? profileMediaId,
    String? profilePictureUrl,
  }) {
    return Account(
      id: id,
      email: email,
      fullName: fullName ?? this.fullName,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      profileMediaId: profileMediaId ?? this.profileMediaId,
      googlePictureUrl: googlePictureUrl,
      profilePictureUrl: profilePictureUrl ?? this.profilePictureUrl,
      isAdmin: isAdmin,
      lastLoginAt: lastLoginAt,
      createdAt: createdAt,
    );
  }
}

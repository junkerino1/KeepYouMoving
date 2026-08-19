/// Model for an account session returned by the backend.
library;

class AccountSession {
  final String id;
  final String name;
  final SessionDevice? device;
  final DateTime? lastUsedAt;
  final DateTime? expiresAt;
  final DateTime? revokedAt;
  final bool isCurrent;

  const AccountSession({
    required this.id,
    required this.name,
    this.device,
    this.lastUsedAt,
    this.expiresAt,
    this.revokedAt,
    required this.isCurrent,
  });

  factory AccountSession.fromJson(Map<String, dynamic> json) {
    final device = json['device'];
    return AccountSession(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      device: device is Map<String, dynamic>
          ? SessionDevice.fromJson(device)
          : null,
      lastUsedAt: json['last_used_at'] != null
          ? DateTime.tryParse(json['last_used_at'] as String)
          : null,
      expiresAt: json['expires_at'] != null
          ? DateTime.tryParse(json['expires_at'] as String)
          : null,
      revokedAt: json['revoked_at'] != null
          ? DateTime.tryParse(json['revoked_at'] as String)
          : null,
      isCurrent: json['is_current'] as bool? ?? false,
    );
  }

  bool get isRevoked => revokedAt != null;
}

class SessionDevice {
  final String id;
  final String installationId;
  final String platform;
  final String deviceModel;
  final String appVersion;

  const SessionDevice({
    required this.id,
    required this.installationId,
    required this.platform,
    required this.deviceModel,
    required this.appVersion,
  });

  factory SessionDevice.fromJson(Map<String, dynamic> json) {
    return SessionDevice(
      id: json['id'] as String? ?? '',
      installationId: json['installation_id'] as String? ?? '',
      platform: json['platform'] as String? ?? '',
      deviceModel: json['device_model'] as String? ?? '',
      appVersion: json['app_version'] as String? ?? '',
    );
  }
}

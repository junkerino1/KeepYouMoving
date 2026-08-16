import 'package:uuid/uuid.dart';

import 'secure_token_store.dart';

/// Generates a stable, cryptographically-random device ID once per install and
/// persists it in secure storage so it survives restarts.
///
/// The ID is sent with the PoW exchange (`device_id`) so the returned token is
/// device-bound. It is generated at runtime — never hard-coded.
class DeviceIdentity {
  DeviceIdentity(this._store);

  final SecureTokenStore _store;

  static const Uuid _uuid = Uuid();

  /// Returns the persisted device ID, generating and persisting one on the
  /// first run.
  Future<String> ensureDeviceId() async {
    final existing = await _store.readDeviceId();
    if (existing != null && existing.isNotEmpty) return existing;
    final id = _uuid.v4();
    await _store.writeDeviceId(id);
    return id;
  }
}

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Encrypted, persistent store for the device identity and the proof-of-work
/// token.
///
/// The PoW token is a bearer credential, so it is deliberately kept in secure
/// (encrypted) storage rather than plain preferences.
class SecureTokenStore {
  SecureTokenStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _deviceIdKey = 'device_id';
  static const _powTokenKey = 'pow_token';
  static const _powExpiresAtKey = 'pow_token_expires_at';
  static const _accountTokenKey = 'account_access_token';

  /// Reads the persisted device ID, or `null` on a fresh install.
  Future<String?> readDeviceId() => _storage.read(key: _deviceIdKey);

  /// Persists the generated device ID.
  Future<void> writeDeviceId(String id) =>
      _storage.write(key: _deviceIdKey, value: id);

  /// Reads the persisted PoW token, or `null` when none has been stored.
  Future<String?> readPowToken() => _storage.read(key: _powTokenKey);

  /// Reads the persisted PoW expiry (unix seconds), or `null` if unknown.
  Future<int?> readPowExpiresAt() async {
    final raw = await _storage.read(key: _powExpiresAtKey);
    return raw == null ? null : int.tryParse(raw);
  }

  /// Persists the PoW token and its expiry (unix seconds), if provided.
  Future<void> writePowToken(String token, {int? expiresAt}) async {
    await _storage.write(key: _powTokenKey, value: token);
    if (expiresAt != null) {
      await _storage.write(
        key: _powExpiresAtKey,
        value: expiresAt.toString(),
      );
    }
  }

  /// Removes the stored PoW token (used when it is rejected/expired).
  Future<void> clearPowToken() async {
    await _storage.delete(key: _powTokenKey);
    await _storage.delete(key: _powExpiresAtKey);
  }

  /// Reads the persisted account access token, or `null` when not logged in.
  Future<String?> readAccountToken() => _storage.read(key: _accountTokenKey);

  /// Persists the account access token after login.
  Future<void> writeAccountToken(String token) =>
      _storage.write(key: _accountTokenKey, value: token);

  /// Removes the stored account token (on logout).
  Future<void> clearAccountToken() => _storage.delete(key: _accountTokenKey);
}

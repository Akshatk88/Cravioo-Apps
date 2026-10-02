import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Encrypted storage for the JWT pair.
///
/// Tokens are a security boundary — they live in Keychain / EncryptedSharedPrefs,
/// never in SharedPreferences alongside app settings. [clear] is what "log out
/// securely" means; app preferences stored elsewhere survive it.
class TokenStorage {
  static const _accessKey = 'auth_access_token';
  static const _refreshKey = 'auth_refresh_token';

  final FlutterSecureStorage _storage;

  TokenStorage([FlutterSecureStorage? storage])
      : _storage = storage ??
            const FlutterSecureStorage(
              iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
            );

  /// Cached in memory so the auth interceptor doesn't hit the keychain on
  /// every single request.
  String? _accessToken;
  String? _refreshToken;
  bool _loaded = false;

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    try {
      _accessToken = await _storage.read(key: _accessKey);
      _refreshToken = await _storage.read(key: _refreshKey);
    } catch (e) {
      if (kDebugMode) {
        developer.log('TokenStorage read failed, clearing stale keys: $e', name: 'TokenStorage');
      }
      _accessToken = null;
      _refreshToken = null;
      try {
        await _storage.deleteAll();
      } catch (_) {}
    } finally {
      _loaded = true;
    }
  }

  Future<String?> get accessToken async {
    await _ensureLoaded();
    return _accessToken;
  }

  Future<String?> get refreshToken async {
    await _ensureLoaded();
    return _refreshToken;
  }

  Future<bool> get hasSession async => (await accessToken)?.isNotEmpty ?? false;

  Future<void> save({required String accessToken, required String refreshToken}) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    _loaded = true;
    try {
      await Future.wait([
        _storage.write(key: _accessKey, value: accessToken),
        _storage.write(key: _refreshKey, value: refreshToken),
      ]);
    } catch (e) {
      if (kDebugMode) {
        developer.log('TokenStorage save failed, attempting recovery: $e', name: 'TokenStorage');
      }
      try {
        await _storage.deleteAll();
        await Future.wait([
          _storage.write(key: _accessKey, value: accessToken),
          _storage.write(key: _refreshKey, value: refreshToken),
        ]);
      } catch (_) {}
    }
  }

  Future<void> clear() async {
    _accessToken = null;
    _refreshToken = null;
    _loaded = true;
    try {
      await Future.wait([
        _storage.delete(key: _accessKey),
        _storage.delete(key: _refreshKey),
      ]);
    } catch (_) {
      try {
        await _storage.deleteAll();
      } catch (_) {}
    }
  }
}

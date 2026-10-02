import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Wraps [FlutterSecureStorage] for persisting auth tokens across app restarts.
class TokenStorage {
  TokenStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _fcmTokenKey = 'fcm_token';

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: _accessTokenKey, value: accessToken);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('delivery_access_token', accessToken);
    } catch (_) {}
  }

  Future<String?> getAccessToken() => _storage.read(key: _accessTokenKey);

  Future<String?> getRefreshToken() => _storage.read(key: _refreshTokenKey);

  Future<void> saveFcmToken(String token) =>
      _storage.write(key: _fcmTokenKey, value: token);

  Future<String?> getFcmToken() => _storage.read(key: _fcmTokenKey);

  Future<void> clear() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('delivery_access_token');
    } catch (_) {}
  }

  Future<bool> hasAccessToken() async =>
      (await getAccessToken())?.isNotEmpty ?? false;
}

final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());

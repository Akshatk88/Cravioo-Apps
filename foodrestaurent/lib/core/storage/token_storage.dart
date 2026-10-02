import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure-storage wrapper for the restaurant partner's session.
///
/// Everything here is cleared on logout except [hasSeenOnboarding] and
/// [hasSeenBatteryPrompt], which should persist across sessions on the same
/// device.
class TokenStorage {
  TokenStorage(this._storage);

  final FlutterSecureStorage _storage;

  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _restaurantIdKey = 'restaurant_id';
  static const _restaurantStatusKey = 'restaurant_status';
  static const _hasSeenOnboardingKey = 'has_seen_onboarding';
  static const _hasSeenBatteryPromptKey = 'has_seen_battery_prompt';
  static const _registrationTokenKey = 'registration_token';

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: _accessTokenKey, value: accessToken);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
  }

  Future<String?> get accessToken => _storage.read(key: _accessTokenKey);

  Future<String?> get refreshToken => _storage.read(key: _refreshTokenKey);

  /// Save registration token separately so it survives [clear].
  Future<void> saveRegistrationToken(String token) =>
      _storage.write(key: _registrationTokenKey, value: token);

  /// Get the stored registration token (survives session clear).
  Future<String?> get registrationToken =>
      _storage.read(key: _registrationTokenKey);

  /// Clear only the registration token (after successful registration).
  Future<void> clearRegistrationToken() =>
      _storage.delete(key: _registrationTokenKey);

  Future<void> saveRestaurantSnapshot({
    required String id,
    required String status,
  }) async {
    await _storage.write(key: _restaurantIdKey, value: id);
    await _storage.write(key: _restaurantStatusKey, value: status);
  }

  Future<String?> get restaurantId => _storage.read(key: _restaurantIdKey);

  Future<String?> get restaurantStatus =>
      _storage.read(key: _restaurantStatusKey);

  Future<void> setHasSeenOnboarding() =>
      _storage.write(key: _hasSeenOnboardingKey, value: 'true');

  Future<bool> get hasSeenOnboarding async {
    final value = await _storage.read(key: _hasSeenOnboardingKey);
    return value == 'true';
  }

  Future<void> setHasSeenBatteryPrompt() =>
      _storage.write(key: _hasSeenBatteryPromptKey, value: 'true');

  Future<bool> get hasSeenBatteryPrompt async {
    final value = await _storage.read(key: _hasSeenBatteryPromptKey);
    return value == 'true';
  }

  Future<void> clear() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _restaurantIdKey);
    await _storage.delete(key: _restaurantStatusKey);
    // NOTE: _registrationTokenKey is intentionally NOT cleared here
    // so onboarding can survive app restarts / session clears.
  }
}

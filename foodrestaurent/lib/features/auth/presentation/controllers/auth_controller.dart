import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_user_application/core/network/api_exception.dart';
import 'package:food_user_application/core/network/dio_client.dart';
import 'package:food_user_application/core/providers/core_providers.dart';
import 'package:food_user_application/core/providers/session_reset.dart';
import 'package:food_user_application/core/services/fcm_service.dart';
import 'package:food_user_application/features/auth/data/auth_api.dart';
import 'package:food_user_application/features/auth/domain/restaurant_model.dart';
import 'package:food_user_application/features/auth/presentation/controllers/auth_state.dart';

const _pendingApprovalDefaultMessage =
    'Your restaurant registration is pending approval.';
const _rejectedDefaultMessage =
    'Your restaurant registration has been rejected. Please contact support.';

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    // A refresh-token failure anywhere in the app forces the session back
    // to logged-out so the router redirects to /login. authSessionProvider
    // is a plain singleton ChangeNotifier (Riverpod 3 dropped
    // ChangeNotifierProvider), so we subscribe to it directly.
    final session = ref.watch(authSessionProvider);
    session.addListener(_onSessionExpired);
    ref.onDispose(() => session.removeListener(_onSessionExpired));
    return const AuthInitial();
  }

  void _onSessionExpired() {
    resetSessionScopedProviders(ref);
    state = const AuthLoggedOut();
  }

  AuthApi get _api => ref.read(authApiProvider);

  /// Called once at app start (from the splash screen) to resolve whether a
  /// stored session is still valid.
  Future<void> checkSession() async {
    final tokenStorage = ref.read(tokenStorageProvider);
    final token = await tokenStorage.accessToken;
    if (token == null || token.isEmpty) {
      state = const AuthLoggedOut();
      return;
    }
    try {
      await _loadCurrentRestaurantAndSetState();
    } catch (_) {
      await tokenStorage.clear();
      state = const AuthLoggedOut();
    }
  }

  Future<void> requestOtp(String phone) async {
    await _api.requestOtp(phone);
    state = AuthOtpSent(phone);
  }

  Future<void> verifyOtp({required String phone, required String otp}) async {
    String? fcmToken;
    try {
      fcmToken = await ref.read(fcmServiceProvider).currentToken();
    } catch (_) {
      fcmToken = null;
    }

    Map<String, dynamic> result;
    try {
      result = await _api.verifyOtp(phone: phone, otp: otp, fcmToken: fcmToken);
    } on DioException catch (e) {
      final message = e.error is ApiException
          ? (e.error as ApiException).message
          : (e.message ?? 'OTP verification failed');
      final lower = message.toLowerCase();
      if (lower.contains('pending approval')) {
        state = AuthPendingApproval(message);
        return;
      }
      if (lower.contains('rejected')) {
        state = AuthRejected(message);
        return;
      }
      rethrow;
    }

    if (result['needsRegistration'] == true) {
      final regToken = result['registrationToken']?.toString();
      debugPrint('🔑 [AUTH] needsRegistration=true, regToken: ${regToken != null ? "exists (${regToken.length} chars)" : "NULL"}');
      if (regToken != null && regToken.isNotEmpty) {
        await ref.read(tokenStorageProvider).saveRegistrationToken(regToken);
        debugPrint('🔑 [AUTH] Registration token saved to dedicated key');
      } else {
        debugPrint('❌ [AUTH] No registrationToken in response! keys=${result.keys.toList()}');
      }
      state = AuthNeedsRegistration(phone, regToken);
      return;
    }

    final accessToken = result['accessToken']?.toString();
    final refreshToken = result['refreshToken']?.toString();
    if (accessToken == null || refreshToken == null) {
      throw ApiException('Unexpected response from server. Please try again.');
    }
    await ref
        .read(tokenStorageProvider)
        .saveTokens(accessToken: accessToken, refreshToken: refreshToken);

    await _loadCurrentRestaurantAndSetState();
    final fcm = ref.read(fcmServiceProvider);
    await fcm.requestPermission();
    await fcm.saveTokenToServer();
  }

  Future<void> refreshRestaurantProfile() =>
      _loadCurrentRestaurantAndSetState();

  Future<void> _loadCurrentRestaurantAndSetState() async {
    final json = await _api.getCurrentRestaurant();
    final raw = json['restaurant'] ?? json;
    final restaurant = RestaurantModel.fromJson(
      Map<String, dynamic>.from(raw as Map),
    );

    await ref
        .read(tokenStorageProvider)
        .saveRestaurantSnapshot(id: restaurant.id, status: restaurant.status);

    if (restaurant.isApproved) {
      // A different restaurant may have been logged in during this same app
      // process — clear out anything it left cached before screens start
      // reading the new one.
      resetSessionScopedProviders(ref);
      await ref.read(fcmServiceProvider).initForegroundHandling();
      state = AuthAuthenticated(restaurant);
    } else if (restaurant.isRejected) {
      state = AuthRejected(
        restaurant.rejectionReason.isNotEmpty
            ? restaurant.rejectionReason
            : _rejectedDefaultMessage,
      );
    } else {
      state = const AuthPendingApproval(_pendingApprovalDefaultMessage);
    }
  }

  Future<void> logout() async {
    final tokenStorage = ref.read(tokenStorageProvider);
    final refreshToken = await tokenStorage.refreshToken;
    try {
      await ref.read(fcmServiceProvider).removeTokenFromServer();
      await _api.logout(refreshToken: refreshToken);
    } catch (_) {
      // Best-effort — always clear local state regardless.
    }
    await tokenStorage.clear();
    resetSessionScopedProviders(ref);
    state = const AuthLoggedOut();
  }

  Future<void> deleteAccount() async {
    final tokenStorage = ref.read(tokenStorageProvider);
    try {
      await ref.read(fcmServiceProvider).removeTokenFromServer();
    } catch (_) {}
    try {
      await _api.deleteAccount();
    } finally {
      await tokenStorage.clear();
      resetSessionScopedProviders(ref);
      state = const AuthLoggedOut();
    }
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

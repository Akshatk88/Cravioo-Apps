import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_user_application/config/constants/app_constants.dart';
import 'package:food_user_application/core/network/api_exception.dart';
import 'package:food_user_application/core/providers/core_providers.dart';
import 'package:food_user_application/core/storage/token_storage.dart';

/// Broadcasts when the session is force-terminated (refresh token invalid).
/// The auth controller listens to this and resets to the logged-out state;
/// the router picks that up and redirects to /login.
class AuthSessionNotifier extends ChangeNotifier {
  void notifySessionExpired() => notifyListeners();
}

final authSessionProvider = Provider<AuthSessionNotifier>((ref) {
  return AuthSessionNotifier();
});

final dioProvider = Provider<Dio>((ref) {
  final tokenStorage = ref.watch(tokenStorageProvider);
  final session = ref.watch(authSessionProvider);

  final dio = Dio(
    BaseOptions(
      baseUrl: AppConstants.baseUrl,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 30),
      contentType: 'application/json',
    ),
  );

  // Separate, interceptor-free client for the refresh call itself, so a
  // failed refresh can't recursively trigger another refresh attempt.
  final refreshDio = Dio(BaseOptions(baseUrl: AppConstants.baseUrl));

  var isRefreshing = false;
  var refreshWaiters = <Completer<bool>>[];

  Future<bool> refreshTokens(TokenStorage storage) async {
    if (isRefreshing) {
      final completer = Completer<bool>();
      refreshWaiters.add(completer);
      return completer.future;
    }
    isRefreshing = true;
    var didRefresh = false;
    try {
      final refreshToken = await storage.refreshToken;
      if (refreshToken == null || refreshToken.isEmpty) {
        return false;
      }
      final response = await refreshDio.post(
        '/food/auth/refresh-token',
        data: {'refreshToken': refreshToken},
      );
      final body = response.data;
      final payload = (body is Map && body['data'] != null)
          ? body['data']
          : body;
      final newAccess = payload?['accessToken'] as String?;
      final newRefresh = payload?['refreshToken'] as String?;
      if (newAccess == null || newRefresh == null) {
        return false;
      }
      await storage.saveTokens(
        accessToken: newAccess,
        refreshToken: newRefresh,
      );
      didRefresh = true;
      return true;
    } catch (_) {
      return false;
    } finally {
      isRefreshing = false;
      final waiters = refreshWaiters;
      refreshWaiters = <Completer<bool>>[];
      for (final waiter in waiters) {
        if (!waiter.isCompleted) waiter.complete(didRefresh);
      }
    }
  }

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final existingAuth =
            options.headers['Authorization'] ?? options.headers['authorization'];
        if (existingAuth == null ||
            (existingAuth is String && existingAuth.trim().isEmpty)) {
          final token = await tokenStorage.accessToken;
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
        }
        handler.next(options);
      },
      onResponse: (response, handler) {
        final body = response.data;
        if (body is Map && body.containsKey('success')) {
          if (body['success'] == true) {
            response.data = body['data'];
            handler.next(response);
            return;
          }
          handler.reject(
            DioException(
              requestOptions: response.requestOptions,
              response: response,
              type: DioExceptionType.badResponse,
              error: ApiException(
                body['message']?.toString() ?? 'Something went wrong',
                statusCode: response.statusCode,
                data: body,
              ),
            ),
          );
          return;
        }
        handler.next(response);
      },
      onError: (error, handler) async {
        final statusCode = error.response?.statusCode;
        final path = error.requestOptions.path;
        final isAuthEndpoint =
            path.contains('/auth/restaurant/') ||
            path.contains('/auth/refresh-token') ||
            path.contains('/restaurant/register');

        if (statusCode == 401 && !isAuthEndpoint) {
          final refreshed = await refreshTokens(tokenStorage);
          if (refreshed) {
            try {
              final token = await tokenStorage.accessToken;
              final retryOptions = error.requestOptions;
              retryOptions.headers['Authorization'] = 'Bearer $token';
              final response = await dio.fetch(retryOptions);
              handler.resolve(response);
              return;
            } catch (_) {
              // fall through to structured error below
            }
          } else {
            await tokenStorage.clear();
            session.notifySessionExpired();
          }
        }

        final apiException = error.error is ApiException
            ? error.error as ApiException
            : ApiException(
                _extractMessage(error),
                statusCode: statusCode,
                data: error.response?.data,
              );
        handler.next(error.copyWith(error: apiException));
      },
    ),
  );

  return dio;
});

String _extractMessage(DioException error) {
  final data = error.response?.data;
  if (data is Map && data['message'] != null) {
    return data['message'].toString();
  }
  switch (error.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return 'Connection timed out. Please check your internet and try again.';
    case DioExceptionType.connectionError:
      return 'No internet connection. Please try again.';
    default:
      return error.message ?? 'Something went wrong';
  }
}

import 'package:dio/dio.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.data});

  final String message;
  final int? statusCode;
  final dynamic data;

  /// Server message for any error thrown by a Dio call. The Dio interceptor
  /// (see dio_client.dart) wraps the [ApiException] inside a [DioException]'s
  /// `.error`, so a bare `e is ApiException` check never matches there.
  static String messageOf(
    Object error, {
    String fallback = 'Something went wrong. Please try again.',
  }) {
    if (error is ApiException) return error.message;
    if (error is DioException && error.error is ApiException) {
      return (error.error as ApiException).message;
    }
    return fallback;
  }

  @override
  String toString() => message;
}

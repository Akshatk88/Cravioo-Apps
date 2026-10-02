import 'dart:convert';
import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:food_user_application/config/constants/app_constants.dart';

const orderAcceptActionId = 'accept_order';
const orderRejectActionId = 'reject_order';

Map<String, dynamic>? _decodePayload(String? payload) {
  if (payload == null || payload.isEmpty) return null;
  try {
    final decoded = jsonDecode(payload);
    return decoded is Map<String, dynamic> ? decoded : null;
  } catch (_) {
    return null;
  }
}

/// Handles taps on the Accept/Reject buttons of the new-order notification.
///
/// Accept is declared `showsUserInterface: true`, so Android routes it through
/// MainActivity and it also reaches the app's normal main-isolate handler.
/// Reject is `showsUserInterface: false` on purpose — declining should not drag
/// the restaurant out of whatever they were doing — so the OS dispatches it to
/// this callback in a fresh background isolate instead. That requires
/// ActionBroadcastReceiver to be declared in AndroidManifest.xml; without it the
/// press is swallowed and the order is never rejected.
///
/// Being a fresh isolate, there is no Riverpod container or cached Dio client
/// here: the access token is read straight from secure storage (the same key
/// `TokenStorage` uses) and the request goes out on a bare, one-off Dio.
@pragma('vm:entry-point')
Future<void> notificationBackgroundResponseHandler(
  NotificationResponse response,
) async {
  final actionId = response.actionId;
  if (actionId != orderAcceptActionId && actionId != orderRejectActionId) {
    return;
  }

  final orderId = _decodePayload(response.payload)?['orderId'] as String?;
  if (orderId == null || orderId.isEmpty) return;

  // A background isolate starts with no plugins registered. Without this,
  // FlutterSecureStorage below throws MissingPluginException — and that read is
  // the first plugin call in the function, so the whole handler dies before it
  // ever reaches the try/catch and the rejection is lost silently.
  //
  // Harmless and idempotent when the isolate already has them (the foreground
  // delegation path in FcmService calls this same function).
  try {
    DartPluginRegistrant.ensureInitialized();
  } catch (_) {
    // Already initialized, or a platform where it does not apply.
  }

  await submitOrderDecision(
    orderId: orderId,
    accepted: actionId == orderAcceptActionId,
  );
}

/// Send the restaurant's accept/reject to the server.
///
/// Extracted so the two ways an order can be answered from outside the app — the
/// notification actions handled here, and the native Kotlin alert via
/// [NewOrderActionChannel] — go through ONE implementation. Two copies of "which
/// status string means rejected" is exactly the kind of thing that drifts and then
/// cancels orders that were meant to be confirmed.
///
/// Deliberately built from scratch rather than using the app's Dio/Riverpod stack:
/// this can run in a background isolate where neither exists, so the token is read
/// straight from secure storage (the same key TokenStorage uses) and the request goes
/// out on a bare, one-off client.
Future<bool> submitOrderDecision({
  required String orderId,
  required bool accepted,
}) async {
  if (orderId.isEmpty) return false;

  final orderStatus = accepted ? 'confirmed' : 'cancelled_by_restaurant';

  try {
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'access_token');
    if (token == null || token.isEmpty) return false;

    final dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.baseUrl,
        headers: {'Authorization': 'Bearer $token'},
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
      ),
    );
    await dio.patch(
      '/food/restaurant/orders/$orderId/status',
      data: {'orderStatus': orderStatus},
    );
    return true;
  } catch (_) {
    // Best-effort — this may be running in an isolate with no UI to surface a retry.
    // The token read is inside the try because it is a plugin call and can throw, and
    // an uncaught throw here takes the isolate down mid-action.
    return false;
  }
}

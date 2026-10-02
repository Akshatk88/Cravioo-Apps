import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The app's side of the native incoming-order overlay.
///
/// The card itself is Kotlin, drawn straight from the FCM payload. Accept and Reject
/// on it travel the same path as the notification buttons (see
/// NewOrderActionChannel), so this only carries the overlay permission and a way to
/// take the card down when the in-app dialog takes over.
class NewOrderOverlayBridge {
  NewOrderOverlayBridge._();

  static const _channel = MethodChannel('app.foodrestaurant/new_order_overlay');

  static Future<T?> _call<T>(String method) async {
    if (!Platform.isAndroid) return null;
    try {
      return await _channel.invokeMethod<T>(method);
    } on MissingPluginException {
      // The channel lives on MainActivity, so it does not exist in the FCM
      // background isolate. Calling from there is a no-op, not a crash.
      return null;
    } catch (e) {
      debugPrint('[offer] overlay bridge $method failed: $e');
      return null;
    }
  }

  static Future<bool> hasPermission() async =>
      await _call<bool>('hasOverlayPermission') ?? false;

  static Future<void> requestPermission() => _call<bool>('requestOverlayPermission');

  static Future<void> dismiss() => _call<bool>('dismissOverlay');
}

import 'dart:io';

import 'package:flutter/services.dart';

/// Dart's side of the in-app incoming-order ringtone, plus taking down any
/// native copy of an order's alert.
///
/// The floating card and its fallback notification are native and are answered
/// through [NewOrderOverlayBridge]; nothing here carries a decision back.
class NewOrderActionChannel {
  static const MethodChannel _channel =
      MethodChannel('app.fooddelivery/new_order_action');

  /// Dismiss the native notification.
  static Future<void> dismiss(String orderId) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<bool>('dismissOrderAlert', {'orderId': orderId});
    } on PlatformException {
      // Ignored
    } on MissingPluginException {
      // Ignored
    }
  }

  /// Start the ringing loop for a new order.
  static Future<void> startSound(String orderId, {int ringMillis = 45000}) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<bool>('startAlertSound', {
        'orderId': orderId,
        'ringMillis': ringMillis,
      });
    } on PlatformException {
      // Ignored
    } on MissingPluginException {
      // Ignored
    }
  }

  /// Stop the ringing loop.
  static Future<void> stopSound([String? orderId]) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<bool>('stopAlertSound', {'orderId': orderId});
    } on PlatformException {
      // Ignored
    } on MissingPluginException {
      // Ignored
    }
  }
}

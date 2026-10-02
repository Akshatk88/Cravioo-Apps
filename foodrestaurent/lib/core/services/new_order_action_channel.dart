import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

/// A decision the restaurant made on the native new-order notification.
class NewOrderAction {
  const NewOrderAction({required this.orderId, required this.accepted});

  final String orderId;
  final bool accepted;
}

/// Dart's side of the native new-order alert.
///
/// The alert is posted and answered entirely in Kotlin, usually while no Flutter
/// engine exists. So the decision cannot simply be delivered as an event — there is
/// often nothing listening when it is made. Kotlin parks it instead, and this reads
/// it back on the next start or resume.
///
/// Both paths are wired deliberately:
///  - [consumePendingAction] covers the app being killed, which is the common case
///    for a phone sitting locked on a counter.
///  - [onAction] covers the app being alive but backgrounded, where waiting for the
///    next poll would add a visible delay to a press the restaurant expects to be
///    instant — and, for Reject, would leave the order unanswered on the server
///    until someone opened the app.
class NewOrderActionChannel {
  static const MethodChannel _channel =
      MethodChannel('app.foodrestaurant/new_order_action');

  static final StreamController<NewOrderAction> _actions =
      StreamController<NewOrderAction>.broadcast();

  static final StreamController<String> _incomingOrders =
      StreamController<String>.broadcast();

  /// Decisions pushed from native while the engine is alive.
  static Stream<NewOrderAction> get onAction => _actions.stream;

  /// Incoming order alerts triggered when opening the app.
  static Stream<String> get onIncomingOrder => _incomingOrders.stream;

  static bool _handlerAttached = false;

  static void initialize() {
    if (_handlerAttached || !Platform.isAndroid) return;
    _handlerAttached = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onOrderAction') {
        final action = _parse(call.arguments);
        if (action != null) _actions.add(action);
      } else if (call.method == 'onIncomingOrder') {
        final orderId = call.arguments?.toString();
        if (orderId != null && orderId.isNotEmpty) {
          _incomingOrders.add(orderId);
        }
      }
      return null;
    });
  }

  /// Read-and-clear pending incoming order id when app is launched with order intent.
  static Future<String?> consumePendingIncomingOrderId() async {
    if (!Platform.isAndroid) return null;
    try {
      final res = await _channel.invokeMethod<dynamic>('consumePendingIncomingOrder');
      return res?.toString();
    } catch (_) {
      return null;
    }
  }

  /// Read-and-clear, so the same decision is never acted on twice.
  ///
  /// Call on start AND on resume: a decision made on the lock screen with the app
  /// killed exists before the engine does.
  static Future<NewOrderAction?> consumePendingAction() async {
    if (!Platform.isAndroid) return null;
    try {
      return _parse(await _channel.invokeMethod<dynamic>('consumePendingAction'));
    } on PlatformException {
      // No decision is a normal, frequent outcome. Never treat a channel error as
      // one having been made.
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  /// Take down a showing alert and stop its ringing — used when the order is
  /// answered inside the app, or withdrawn.
  static Future<void> dismiss(String orderId) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<bool>('dismissOrderAlert', {'orderId': orderId});
    } on PlatformException {
      // Worst case the alert lingers until its own timeout.
    } on MissingPluginException {
      // Older build without the native side.
    }
  }

  /// Start the ringing loop for a new order.
  static Future<void> startSound(String orderId, {int ringMillis = 60000}) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<bool>('startAlertSound', {
        'orderId': orderId,
        'ringMillis': ringMillis,
      });
    } on PlatformException {
    } on MissingPluginException {
    }
  }

  /// Stop the ringing without clearing the notification.
  static Future<void> stopSound([String? orderId]) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<bool>('stopAlertSound', {'orderId': orderId});
    } on PlatformException {
      // The ring has its own hard timeout, so this can only delay silence.
    } on MissingPluginException {
      // Older build without the native side.
    }
  }

  static NewOrderAction? _parse(dynamic raw) {
    if (raw is! Map) return null;
    final orderId = raw['orderId']?.toString();
    if (orderId == null || orderId.isEmpty) return null;
    return NewOrderAction(orderId: orderId, accepted: raw['accepted'] == true);
  }
}

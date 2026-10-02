import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

/// A decision the delivery partner made on the native incoming-order notification.
class NewOrderAction {
  const NewOrderAction({required this.orderId, required this.accepted});

  final String orderId;
  final bool accepted;
}

/// Dart's side of the native incoming-order alert for delivery partners.
class NewOrderActionChannel {
  static const MethodChannel _channel =
      MethodChannel('app.fooddelivery/new_order_action');

  static final StreamController<NewOrderAction> _actions =
      StreamController<NewOrderAction>.broadcast();
  static final StreamController<String> _incomingOrders =
      StreamController<String>.broadcast();

  /// Decisions pushed from native while the engine is alive.
  static Stream<NewOrderAction> get onAction => _actions.stream;

  /// Incoming order alerts opened by tapping the notification.
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
        final raw = call.arguments;
        final id = raw is Map ? raw['orderId']?.toString() : raw?.toString();
        if (id != null && id.isNotEmpty) {
          _incomingOrders.add(id);
        }
      }
      return null;
    });
  }

  /// Read-and-clear: check if user tapped Accept/Reject on lock screen
  /// before the Flutter engine initialized.
  static Future<NewOrderAction?> consumePendingAction() async {
    if (!Platform.isAndroid) return null;
    try {
      return _parse(await _channel.invokeMethod<dynamic>('consumePendingAction'));
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  /// Read-and-clear: check if the app was launched by tapping an incoming order notification.
  static Future<String?> consumePendingIncomingOrderId() async {
    if (!Platform.isAndroid) return null;
    try {
      final res = await _channel.invokeMethod<dynamic>('consumePendingIncomingOrderId');
      if (res is String && res.isNotEmpty) return res;
      if (res is Map) return res['orderId']?.toString();
      return null;
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

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

  static NewOrderAction? _parse(dynamic raw) {
    if (raw is! Map) return null;
    final orderId = raw['orderId']?.toString();
    final accepted = raw['accepted'] as bool?;
    if (orderId == null || orderId.isEmpty || accepted == null) return null;
    return NewOrderAction(orderId: orderId, accepted: accepted);
  }
}

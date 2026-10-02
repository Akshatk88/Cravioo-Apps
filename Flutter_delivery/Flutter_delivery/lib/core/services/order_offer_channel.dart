import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

/// A decision the rider made on the native full-screen offer card.
class OrderOfferAction {
  const OrderOfferAction({
    required this.orderId,
    required this.accepted,
    required this.data,
  });

  final String orderId;
  final bool accepted;

  /// The whole push payload the card was drawn from. Carried through so the
  /// accept path can rebuild the order locally instead of having to fetch it —
  /// see [OrderOfferChannel] for why that matters.
  final Map<String, dynamic> data;
}

/// Dart's side of the native offer card.
///
/// The card is posted and answered entirely in Kotlin, usually while no Flutter
/// engine exists at all. So the decision cannot be delivered as an event — there is
/// nothing listening when it is made. Kotlin parks it instead, and this reads it back
/// on the next start or resume.
///
/// Both paths are wired deliberately:
///  - [consumePendingAction] covers the app being killed, which is the common case.
///  - [onAction] covers the app being alive and backgrounded, where waiting for the
///    next poll would add a visible delay to a tap the rider expects to be instant.
class OrderOfferChannel {
  static const MethodChannel _channel =
      MethodChannel('app.fooddelivery/order_offer');

  static final StreamController<OrderOfferAction> _actions =
      StreamController<OrderOfferAction>.broadcast();

  /// Decisions pushed from native while the engine is alive.
  static Stream<OrderOfferAction> get onAction => _actions.stream;

  static bool _handlerAttached = false;

  static void initialize() {
    if (_handlerAttached || !Platform.isAndroid) return;
    _handlerAttached = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onOfferAction') {
        final action = _parse(call.arguments);
        if (action != null) _actions.add(action);
      }
      return null;
    });
  }

  /// Read-and-clear, so the same decision is never acted on twice.
  ///
  /// Call on start AND on resume: a rider who accepted from the lock screen with the
  /// app killed produces a decision that exists before the engine does.
  static Future<OrderOfferAction?> consumePendingAction() async {
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

  /// Takes down a showing card and its notification — used when the offer is
  /// withdrawn or resolved from inside the app.
  static Future<void> dismiss(String orderId) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<bool>('dismissOffer', {'orderId': orderId});
    } on PlatformException {
      // Worst case a stale card lingers until its own countdown expires.
    } on MissingPluginException {
      // Older build without the native side.
    }
  }

  static OrderOfferAction? _parse(dynamic raw) {
    if (raw is! Map) return null;
    final data = <String, dynamic>{};
    raw.forEach((key, value) => data[key.toString()] = value);

    final orderId = data['orderId']?.toString();
    if (orderId == null || orderId.isEmpty) return null;

    return OrderOfferAction(
      orderId: orderId,
      accepted: data['accepted'] == true,
      data: data,
    );
  }
}

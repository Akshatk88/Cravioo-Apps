import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:food_user_application/config/constants/app_constants.dart';

const _applicationId = 'com.cravioo.restaurant';
const _pendingOrderPrefsKey = 'pending_overlay_order';
const _askedPermissionPrefsKey = 'asked_overlay_permission';

// Must match NewOrderNotifier.ACTION_ACCEPT / ACTION_REJECT / EXTRA_ORDER_ID.
const _actionAccept = '$_applicationId.NEW_ORDER_ACCEPT';
const _actionReject = '$_applicationId.NEW_ORDER_REJECT';
const _extraOrderId = 'orderId';

/// How long the alert stays up. Matches the native ringtone's default ring.
const _overlayLifetime = Duration(seconds: 60);

/// Reads that cross isolates (the FCM background handler writes, the overlay
/// engine and the main app read) must see what is on disk, not the snapshot the
/// per-isolate singleton took when it was first created.
Future<SharedPreferences> _freshPrefs() async {
  final prefs = await SharedPreferences.getInstance();
  try {
    await prefs.reload();
  } catch (_) {
    // Best effort — fall back to whatever the cache holds.
  }
  return prefs;
}

String? _orderIdOf(Map<String, dynamic> data) {
  final id = (data['orderMongoId'] ?? data['orderId'] ?? data['_id'] ?? data['id'])
      ?.toString();
  return (id == null || id.isEmpty) ? null : id;
}

/// Floating new-order alert drawn over other apps — the same kind of window the
/// delivery app uses. It sits on top of whatever is on screen, so a restaurant
/// that has the app closed (or is in another app) still sees the order and can
/// answer it with one tap.
///
/// The ringing, the notification and the status update are all owned by the
/// native layer already ([NewOrderNotifier] / [NewOrderActionReceiver]); the
/// overlay only adds the on-screen card, and answers by sending the very same
/// broadcast the notification's Accept / Reject buttons send. So there is exactly
/// one implementation of "accept an order" and it stops the ringing in the same
/// place whichever button was pressed.
class OrderOverlayService {
  static Future<bool> hasPermission() async {
    if (!Platform.isAndroid) return false;
    try {
      return await FlutterOverlayWindow.isPermissionGranted();
    } catch (_) {
      return false;
    }
  }

  static Future<void> requestPermission() async {
    if (!Platform.isAndroid) return;
    try {
      if (!await FlutterOverlayWindow.isPermissionGranted()) {
        await FlutterOverlayWindow.requestPermission();
      }
    } catch (_) {}
  }

  /// Whether the restaurant has already been asked once. Declining must not
  /// bring the system settings screen up on every launch.
  static Future<bool> hasAskedPermission() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_askedPermissionPrefsKey) ?? false;
    } catch (_) {
      return true;
    }
  }

  static Future<void> markAskedPermission() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_askedPermissionPrefsKey, true);
    } catch (_) {}
  }

  /// Shows (or refreshes) the alert for [data], an FCM `new_order` data map.
  /// Returns false when the permission is missing or the window could not open.
  static Future<bool> showForOrder(Map<String, dynamic> data) async {
    if (!Platform.isAndroid) return false;
    try {
      if (!await FlutterOverlayWindow.isPermissionGranted()) return false;

      final encoded = jsonEncode(data);
      final prefs = await _freshPrefs();
      await prefs.setString(_pendingOrderPrefsKey, encoded);

      if (await FlutterOverlayWindow.isActive()) {
        await FlutterOverlayWindow.shareData(encoded);
        return true;
      }

      await FlutterOverlayWindow.showOverlay(
        height: WindowSize.matchParent,
        width: WindowSize.matchParent,
        alignment: OverlayAlignment.topCenter,
        // defaultFlag keeps touches outside the card reaching the app below, so
        // the overlay can never freeze the phone.
        flag: OverlayFlag.defaultFlag,
        enableDrag: false,
        positionGravity: PositionGravity.auto,
        overlayTitle: 'Incoming order',
      );

      // The overlay engine needs a moment to start listening.
      unawaited(
        Future.delayed(const Duration(milliseconds: 350), () async {
          try {
            if (await FlutterOverlayWindow.isActive()) {
              await FlutterOverlayWindow.shareData(encoded);
            }
          } catch (_) {}
        }),
      );
      return true;
    } catch (e) {
      debugPrint('[OrderOverlayService] showForOrder failed: $e');
      return false;
    }
  }

  static Future<void> close() async {
    if (!Platform.isAndroid) return;
    try {
      if (await FlutterOverlayWindow.isActive()) {
        await FlutterOverlayWindow.closeOverlay();
      }
    } catch (_) {}
  }

  /// Closes the window if it is showing [orderId] — the order was answered
  /// elsewhere or cancelled. A different order's window is left alone: a newer
  /// alert has already replaced this one in place.
  static Future<void> closeForOrder(String orderId) async {
    if (!Platform.isAndroid) return;
    final prefs = await _freshPrefs();
    final raw = prefs.getString(_pendingOrderPrefsKey);
    if (raw != null) {
      try {
        final pending = Map<String, dynamic>.from(jsonDecode(raw) as Map);
        final pendingId = _orderIdOf(pending);
        if (pendingId != null && pendingId != orderId) return;
      } catch (_) {
        // Unreadable payload — treat as ours and clear it.
      }
      await prefs.remove(_pendingOrderPrefsKey);
    }
    await close();
  }

  static Future<Map<String, dynamic>?> consumePendingOrder() async {
    final prefs = await _freshPrefs();
    final raw = prefs.getString(_pendingOrderPrefsKey);
    if (raw == null) return null;
    await prefs.remove(_pendingOrderPrefsKey);
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return null;
    }
  }

  /// Answers the order through the native receiver — identical to pressing
  /// Accept / Reject on the notification (stops the ringing, clears the alert,
  /// updates the order on the server, and opens the app on Accept).
  static Future<void> answer({
    required String orderId,
    required bool accept,
  }) async {
    final intent = AndroidIntent(
      action: accept ? _actionAccept : _actionReject,
      package: _applicationId,
      componentName: '$_applicationId.NewOrderActionReceiver',
      arguments: <String, dynamic>{_extraOrderId: orderId},
    );
    await intent.sendBroadcast();
  }

  /// Brings the app to the front on this order.
  ///
  /// [answered] marks an order the restaurant has just accepted from the overlay:
  /// the app then opens on it without raising the incoming-order dialog again,
  /// the same flags the notification's Accept button launches with.
  static Future<void> openApp(
    String orderId, {
    bool answered = false,
    String? restaurantId,
  }) async {
    final intent = AndroidIntent(
      action: 'android.intent.action.MAIN',
      category: 'android.intent.category.LAUNCHER',
      package: _applicationId,
      componentName: '$_applicationId.MainActivity',
      arguments: <String, dynamic>{
        _extraOrderId: orderId,
        if (restaurantId != null && restaurantId.isNotEmpty) 'restaurantId': restaurantId,
        if (answered) 'orderActionHandled': true,
        if (answered) 'accepted': true,
      },
      flags: [Flag.FLAG_ACTIVITY_NEW_TASK, Flag.FLAG_ACTIVITY_SINGLE_TOP],
    );
    await intent.launch();
  }

  /// Best-effort details for the card. The push carries only a headline, so the
  /// items and total come from the order itself. Never throws; the card works
  /// without them.
  static Future<Map<String, dynamic>?> fetchOrder(String orderId) async {
    try {
      const storage = FlutterSecureStorage();
      final token = await storage.read(key: 'access_token');
      if (token == null || token.isEmpty) return null;
      final dio = Dio(
        BaseOptions(
          baseUrl: AppConstants.baseUrl,
          headers: {'Authorization': 'Bearer $token'},
          connectTimeout: const Duration(seconds: 6),
          receiveTimeout: const Duration(seconds: 6),
        ),
      );
      final response = await dio.get('/food/restaurant/orders/$orderId');
      dynamic body = response.data;
      if (body is Map && body['data'] != null) body = body['data'];
      if (body is Map && body['order'] is Map) body = body['order'];
      return body is Map ? Map<String, dynamic>.from(body) : null;
    } catch (_) {
      return null;
    }
  }
}

/// Root of the overlay's own Flutter engine.
class OrderBubbleApp extends StatelessWidget {
  const OrderBubbleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      color: Colors.transparent,
      home: _OrderOverlayUI(),
    );
  }
}

class _OrderOverlayUI extends StatefulWidget {
  const _OrderOverlayUI();

  @override
  State<_OrderOverlayUI> createState() => _OrderOverlayUIState();
}

class _OrderOverlayUIState extends State<_OrderOverlayUI> {
  Map<String, dynamic>? _push;
  Map<String, dynamic>? _order;
  StreamSubscription<dynamic>? _sub;
  Timer? _failsafe;
  Timer? _tick;
  int _secondsLeft = _overlayLifetime.inSeconds;
  bool _busy = false;

  /// The order belongs to another outlet than the one signed in. Accept/Reject
  /// would be answered as the wrong outlet, so the card only offers to open it.
  bool _otherOutlet = false;

  @override
  void initState() {
    super.initState();
    _failsafe = Timer(_overlayLifetime + const Duration(seconds: 5), _close);
    _sub = FlutterOverlayWindow.overlayListener.listen((event) {
      if (event is String) _accept(event);
    });
    // The first payload can land before the listener exists; read what the
    // background handler stored.
    OrderOverlayService.consumePendingOrder().then((data) {
      if (data != null && _push == null) {
        _acceptMap(data);
      }
    });
  }

  void _accept(String raw) {
    try {
      _acceptMap(Map<String, dynamic>.from(jsonDecode(raw) as Map));
    } catch (_) {}
  }

  void _acceptMap(Map<String, dynamic> data) {
    if (!mounted) return;
    final incomingId = _orderIdOf(data);
    final currentId = _push == null ? null : _orderIdOf(_push!);
    setState(() {
      _push = data;
      if (incomingId != currentId) {
        _order = null;
        _secondsLeft = _overlayLifetime.inSeconds;
      }
    });
    _startCountdown();
    _checkOutlet(data);
    if (incomingId != null && incomingId != currentId) {
      OrderOverlayService.fetchOrder(incomingId).then((order) {
        if (mounted && order != null && _orderIdOf(_push ?? {}) == incomingId) {
          setState(() => _order = order);
        }
      });
    }
  }

  /// Compares the push's outlet with the one signed in (mirrored into
  /// SharedPreferences by TokenStorage; this overlay runs in its own engine).
  Future<void> _checkOutlet(Map<String, dynamic> data) async {
    final restaurantId = _str(data['restaurantId']);
    if (restaurantId.isEmpty) return;
    try {
      final prefs = await _freshPrefs();
      final active = prefs.getString('restaurant_id') ?? '';
      final other = active.isNotEmpty && active != restaurantId;
      if (mounted && other != _otherOutlet) setState(() => _otherOutlet = other);
    } catch (_) {}
  }

  void _startCountdown() {
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_secondsLeft <= 1) {
        _close();
        return;
      }
      setState(() => _secondsLeft -= 1);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _failsafe?.cancel();
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _close() async {
    _tick?.cancel();
    _failsafe?.cancel();
    try {
      await FlutterOverlayWindow.closeOverlay();
    } catch (_) {}
  }

  Future<void> _answer(bool accept) async {
    final id = _push == null ? null : _orderIdOf(_push!);
    if (id == null || _busy) return;
    setState(() => _busy = true);
    // Accept opens the app. Launch it FIRST, while this overlay is still on
    // screen: Android allows a background app to start an activity only while it
    // has a visible window, and that is gone once the overlay closes (the native
    // receiver's own launch, which follows, can then be silently blocked).
    if (accept) {
      try {
        await OrderOverlayService.openApp(id, answered: true);
      } catch (_) {}
    }
    try {
      await OrderOverlayService.answer(orderId: id, accept: accept);
    } catch (_) {}
    await _close();
  }

  Future<void> _view() async {
    final id = _push == null ? null : _orderIdOf(_push!);
    if (id == null) return;
    try {
      await OrderOverlayService.openApp(
        id,
        restaurantId: _str(_push?['restaurantId']),
      );
    } catch (_) {}
    await _close();
  }

  static String _str(Object? v) => (v ?? '').toString().trim();

  static double? _num(Object? v) {
    if (v is num) return v.toDouble();
    return double.tryParse(_str(v));
  }

  String get _displayId {
    final fromOrder = _str(_order?['order_id'] ?? _order?['orderId']);
    if (fromOrder.isNotEmpty) return fromOrder;
    return _str(_push?['orderDisplayId'] ?? _push?['orderId']);
  }

  List<String> get _itemLines {
    final items = _order?['items'];
    if (items is! List) return const [];
    return items
        .whereType<Map>()
        .map((i) {
          final qty = _str(i['quantity']);
          final name = _str(i['name']);
          return name.isEmpty ? '' : '${qty.isEmpty ? '1' : qty} × $name';
        })
        .where((s) => s.isNotEmpty)
        .toList();
  }


  // ---- presentation helpers -------------------------------------------------

  static const _green = Color(0xFF22C55E);
  static const _greenDark = Color(0xFF16A34A);
  static const _ink = Color(0xFF111827);
  static const _muted = Color(0xFF6B7280);

  String get _customerName {
    final name = _str(_order?['customerName'] ?? _push?['customerName']);
    return name.isEmpty ? 'Customer' : name;
  }

  String get _customerPhone =>
      _str(_order?['customerPhone'] ?? _push?['customerPhone']);

  String get _outletName => _str(_push?['restaurantName']);

  double? get _total => _num(
        _order?['total'] ??
            (_order?['pricing'] is Map ? (_order!['pricing'] as Map)['total'] : null) ??
            _push?['total'],
      );

  /// Cash on delivery vs paid online, from the order's payment block.
  bool get _isCod {
    final payment = _order?['payment'];
    final method = _str(
      (payment is Map ? payment['method'] : null) ?? _order?['paymentMethod'] ?? _push?['paymentMethod'],
    ).toLowerCase();
    return method == 'cash' || method == 'cod';
  }

  bool get _paymentKnown {
    final payment = _order?['payment'];
    return _str(
      (payment is Map ? payment['method'] : null) ?? _order?['paymentMethod'] ?? _push?['paymentMethod'],
    ).isNotEmpty;
  }

  String get _address {
    final a = _order?['deliveryAddress'];
    if (a is! Map) return '';
    return [
      a['street'],
      a['additionalDetails'],
      a['city'],
      a['state'],
      a['zipCode'],
    ].map(_str).where((s) => s.isNotEmpty).join(', ');
  }

  Widget _infoRow({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String label,
    required Widget value,
    Widget? trailing,
    bool divider = true,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(fontSize: 13, color: _muted),
                    ),
                    const SizedBox(height: 2),
                    value,
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing],
            ],
          ),
        ),
        if (divider) const Divider(height: 1, color: Color(0xFFEDEFF2)),
      ],
    );
  }

  Widget _bold(String text, {double size = 17}) => Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: size,
          fontWeight: FontWeight.w800,
          color: _ink,
        ),
      );

  Widget _dash() => const Text(
        '—',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _greenDark),
      );

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final topInset = mq.padding.top;
    final total = _total;
    final lines = _itemLines;
    final cod = _isCod;
    final otherOutlet = _otherOutlet;
    final headline = _displayId.isEmpty
        ? (total != null && total > 0 ? '₹${total.toStringAsFixed(2)}' : 'Waiting for review')
        : 'Order $_displayId${total != null && total > 0 ? ' • ₹${total.toStringAsFixed(2)}' : ''}';

    return Material(
      color: Colors.transparent,
      type: MaterialType.transparency,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(12, topInset + 40, 12, 0),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: mq.size.height * 0.80),
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.topCenter,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x59000000),
                          blurRadius: 28,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ---- header ----
                          Container(
                            width: double.infinity,
                            color: _green,
                            padding: const EdgeInsets.fromLTRB(18, 44, 18, 18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 64,
                                      height: 64,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      clipBehavior: Clip.antiAlias,
                                      child: Image.asset(
                                        'assets/image/logo.jpeg',
                                        fit: BoxFit.contain,
                                        errorBuilder: (_, _, _) => const Icon(
                                          Icons.storefront,
                                          color: _greenDark,
                                          size: 32,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            '🔔 New Order Received!',
                                            style: TextStyle(
                                              fontSize: 21,
                                              fontWeight: FontWeight.w800,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            headline,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            otherOutlet
                                                ? 'This order is for another outlet'
                                                : 'Accept before the time runs out',
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: Color(0xE6FFFFFF),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 22,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.timer_outlined, size: 20, color: _muted),
                                        const SizedBox(width: 8),
                                        const Text(
                                          'Accept within ',
                                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _ink),
                                        ),
                                        Text(
                                          '$_secondsLeft',
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w900,
                                            color: _greenDark,
                                          ),
                                        ),
                                        const Text(
                                          ' sec',
                                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _ink),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // ---- details ----
                          Padding(
                            padding: const EdgeInsets.fromLTRB(18, 6, 18, 0),
                            child: Column(
                              children: [
                                if (_outletName.isNotEmpty)
                                  _infoRow(
                                    icon: Icons.storefront_rounded,
                                    iconBg: const Color(0xFFDCFCE7),
                                    iconColor: _greenDark,
                                    label: 'Outlet',
                                    value: _bold(_outletName),
                                  ),
                                _infoRow(
                                  icon: Icons.person_rounded,
                                  iconBg: const Color(0xFFE0F2FE),
                                  iconColor: const Color(0xFF0369A1),
                                  label: 'Customer',
                                  value: _bold(_customerName),
                                  trailing: _customerPhone.isEmpty
                                      ? null
                                      : Text(
                                          _customerPhone,
                                          style: const TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w600,
                                            color: _muted,
                                          ),
                                        ),
                                ),
                                if (_address.isNotEmpty)
                                  _infoRow(
                                    icon: Icons.location_on_rounded,
                                    iconBg: const Color(0xFFFEF3C7),
                                    iconColor: const Color(0xFFB45309),
                                    label: 'Deliver to',
                                    value: Text(
                                      _address,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: _ink,
                                      ),
                                    ),
                                  ),
                                _infoRow(
                                  icon: Icons.inventory_2_rounded,
                                  iconBg: const Color(0xFFEDE9FE),
                                  iconColor: const Color(0xFF6D28D9),
                                  label: lines.isEmpty ? 'Items' : 'Items (${lines.length})',
                                  value: lines.isEmpty
                                      ? (_str(_push?['body']).isNotEmpty
                                          ? Text(
                                              _str(_push?['body']),
                                              maxLines: 3,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(fontSize: 13.5, color: _ink),
                                            )
                                          : _dash())
                                      : Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            for (final line in lines.take(6))
                                              Padding(
                                                padding: const EdgeInsets.only(bottom: 2),
                                                child: Text(
                                                  line,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w700,
                                                    color: _ink,
                                                  ),
                                                ),
                                              ),
                                            if (lines.length > 6)
                                              Text(
                                                '+ ${lines.length - 6} more',
                                                style: const TextStyle(fontSize: 12.5, color: _muted),
                                              ),
                                          ],
                                        ),
                                ),
                                _infoRow(
                                  icon: Icons.currency_rupee_rounded,
                                  iconBg: const Color(0xFFFEE2E2),
                                  iconColor: const Color(0xFFDC2626),
                                  label: 'Order Value (Customer Pays)',
                                  value: total != null && total > 0
                                      ? _bold('₹${total.toStringAsFixed(2)}', size: 20)
                                      : _dash(),
                                  trailing: !_paymentKnown
                                      ? null
                                      : Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 10,
                                          ),
                                          decoration: BoxDecoration(
                                            color: cod ? const Color(0xFFFFF4E5) : const Color(0xFFE8F8EE),
                                            borderRadius: BorderRadius.circular(14),
                                          ),
                                          child: Text(
                                            cod ? 'Cash' : 'Prepaid',
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w800,
                                              color: cod ? const Color(0xFFB45309) : _greenDark,
                                            ),
                                          ),
                                        ),
                                  divider: false,
                                ),
                                const SizedBox(height: 8),
                                if (_paymentKnown)
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF0FDF4),
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(color: const Color(0xFFBBF7D0)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFFDB2777)),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            cod
                                                ? 'Cash on delivery — the rider collects ${total != null && total > 0 ? '₹${total.toStringAsFixed(2)}' : 'the amount'} from the customer.'
                                                : 'Paid online — nothing to collect at delivery.',
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: _muted,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                const SizedBox(height: 16),

                                // ---- actions ----
                                if (otherOutlet)
                                  SizedBox(
                                    width: double.infinity,
                                    height: 56,
                                    child: ElevatedButton(
                                      onPressed: _busy ? null : _view,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _greenDark,
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(18),
                                        ),
                                      ),
                                      child: Text(
                                        _outletName.isNotEmpty ? 'OPEN ${_outletName.toUpperCase()}' : 'OPEN OUTLET',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.4,
                                        ),
                                      ),
                                    ),
                                  )
                                else
                                  Row(
                                    children: [
                                      Expanded(
                                        child: SizedBox(
                                          height: 56,
                                          child: OutlinedButton.icon(
                                            onPressed: _busy ? null : () => _answer(false),
                                            icon: const Icon(Icons.close_rounded, size: 22),
                                            label: const Text(
                                              'REJECT',
                                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                                            ),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: const Color(0xFFDC2626),
                                              side: const BorderSide(color: Color(0xFFDC2626), width: 2),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(18),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        flex: 2,
                                        child: SizedBox(
                                          height: 56,
                                          child: ElevatedButton.icon(
                                            onPressed: _busy ? null : () => _answer(true),
                                            icon: const Icon(Icons.check_rounded, size: 24),
                                            label: const Text(
                                              'ACCEPT ORDER',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w900,
                                                letterSpacing: 0.4,
                                              ),
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: _greenDark,
                                              foregroundColor: Colors.white,
                                              elevation: 0,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(18),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                if (!otherOutlet)
                                  Center(
                                    child: TextButton(
                                      onPressed: _busy ? null : _view,
                                      child: const Text('View order details'),
                                    ),
                                  ),
                                const SizedBox(height: 10),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Bell badge straddling the card's top edge.
                  Positioned(
                    top: -34,
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(6),
                      child: Container(
                        decoration: const BoxDecoration(
                          color: _green,
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Text('🔔', style: TextStyle(fontSize: 28)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ---- high-priority strip ----
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xB3000000),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                children: [
                  Icon(Icons.shield_rounded, color: Color(0xFF60A5FA), size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'High priority order  •  The customer is notified once you accept.',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Everything below is transparent and dismisses on tap.
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _close,
              child: const SizedBox.expand(),
            ),
          ),
        ],
      ),
    );
  }
}

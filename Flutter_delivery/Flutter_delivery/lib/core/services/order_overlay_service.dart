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

import 'package:food_user_application/core/constants/app_constants.dart';

import 'new_order_action_channel.dart';
import 'sound_service.dart';

const _applicationId = 'com.cravioo.delivery';
const _pendingOrderPrefsKey = 'pending_overlay_order';

/// SharedPreferences that reflect what is actually on disk right now.
///
/// The pending-order key is written by one isolate (the FCM background handler)
/// and read by two others (the overlay engine, the main app on resume).
/// getInstance() hands back a per-isolate cached singleton holding a snapshot
/// taken the first time it was called in that isolate, and it never re-reads on
/// its own — so a reader whose isolate was already warm sees a value from before
/// the write and concludes there is no pending order.
///
/// Every cross-isolate read of that key goes through here.
Future<SharedPreferences> _freshPrefs() async {
  final prefs = await SharedPreferences.getInstance();
  try {
    await prefs.reload();
  } catch (_) {
    // Best effort — fall back to whatever the cache holds.
  }
  return prefs;
}

/// Floating "bubble" over the home screen for a new-order alert that arrives
/// while the app is backgrounded — the Rapido/Uber-style overlay, distinct
/// from the lock-screen full-screen-intent notification which already
/// covers the locked-device case.
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

  /// Displays the floating incoming order overlay screen over other apps.
  /// Uses defaultFlag so screen touches outside are not blocked and the app never freezes.
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
        flag: OverlayFlag.defaultFlag, // defaultFlag prevents touch trapping and app lockups
        enableDrag: false,
        positionGravity: PositionGravity.auto,
        overlayTitle: 'Incoming Delivery Order',
      );

      // Asynchronously deliver data to the overlay engine once it awakens
      unawaited(Future.delayed(const Duration(milliseconds: 350), () async {
        try {
          if (await FlutterOverlayWindow.isActive()) {
            await FlutterOverlayWindow.shareData(encoded);
          }
        } catch (_) {}
      }));

      return true;
    } catch (e) {
      debugPrint('[OrderOverlayService] showForOrder failed: $e');
      return false;
    }
  }

  static Future<void> openAppWithOrder(Map<String, dynamic> data) async {
    if (!Platform.isAndroid) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingOrderPrefsKey, jsonEncode(data));
    await reopenApp();
  }

  static Future<void> close() async {
    if (!Platform.isAndroid) return;
    try {
      if (await FlutterOverlayWindow.isActive()) {
        await FlutterOverlayWindow.closeOverlay();
      }
    } catch (_) {}
  }

  /// Closes the bubble if it is showing [orderId] — used when another rider
  /// accepted first.
  ///
  /// If the stored payload is for a DIFFERENT order the window is left alone: a
  /// newer offer has already replaced this one in place via [shareData], and
  /// closing would throw away a live offer. If nothing is stored the window is
  /// closed anyway, since the only thing it can be showing is the payload the main
  /// isolate already consumed — which is this one.
  static Future<void> closeForOrder(String orderId) async {
    if (!Platform.isAndroid) return;

    final prefs = await _freshPrefs();
    final raw = prefs.getString(_pendingOrderPrefsKey);
    if (raw != null) {
      try {
        final pending = Map<String, dynamic>.from(jsonDecode(raw) as Map);
        final pendingId =
            (pending['orderMongoId'] ?? pending['orderId'] ?? pending['_id'])
                ?.toString();
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

  /// Accepts or rejects an order straight from the overlay.
  ///
  /// The overlay runs in its own engine with no Riverpod container and no
  /// configured Dio, so the token is read directly from the same secure-storage
  /// key TokenStorage uses and the request goes out on a bare client — the same
  /// approach the FCM background handler takes.
  ///
  /// Never throws. A failure here falls back to the autoAccept flag the caller
  /// wrote, which the app applies when it opens; surfacing an error inside a
  /// window that is about to close would help nobody.
  static Future<bool> submitOrderAction({
    required String orderId,
    required bool accept,
  }) async {
    try {
      const storage = FlutterSecureStorage();
      final token = await storage.read(key: 'access_token');
      if (token == null || token.isEmpty) return false;

      final path = accept
          ? '/food/delivery/orders/$orderId/accept'
          : '/food/delivery/orders/$orderId/reject';

      final dio = Dio(
        BaseOptions(
          baseUrl: AppConstants.baseUrl,
          headers: {'Authorization': 'Bearer $token'},
          // Short: the rider is watching a window that is closing. Better to
          // fall through to the app-open retry than to hold the overlay.
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
        ),
      );

      await dio.patch(path);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> reopenApp() async {
    const intent = AndroidIntent(
      action: 'android.intent.action.MAIN',
      category: 'android.intent.category.LAUNCHER',
      package: _applicationId,
      componentName: '$_applicationId.MainActivity',
      flags: [Flag.FLAG_ACTIVITY_NEW_TASK, Flag.FLAG_ACTIVITY_REORDER_TO_FRONT],
    );
    await intent.launch();
  }
}

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

/// Chrome shared by the loading and loaded states of the overlay.
///
/// The window is now full height (see showForOrder), so this is what keeps the
/// alert anchored to the top and stops it becoming a screen-blocker again:
///
///  - Real status bar / notch insets instead of the hardcoded 64px that used to
///    sit here. Cutout heights differ by device, which is why the card looked
///    correctly placed on some phones and jammed under the status bar on others.
///  - The card scrolls if it is ever taller than the screen. On a short or
///    heavily-scaled display the content can exceed the viewport, and a clipped
///    card with the Accept button below the fold is unusable — scrolling
///    degrades instead of truncating.
///  - Everything below the card is transparent and dismisses on tap, so the rest
///    of the screen still behaves as if the overlay were not there.
class _OverlayShell extends StatelessWidget {
  const _OverlayShell({required this.child, required this.onDismiss});

  final Widget child;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;

    return Material(
      color: Colors.transparent,
      type: MaterialType.transparency,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Column(
            children: [
              ConstrainedBox(
                // Capped so the scroll view has a bounded height to shrink-wrap
                // into: it then takes the content's height, or this cap if the
                // content is bigger, and scrolls the remainder.
                constraints: BoxConstraints(maxHeight: constraints.maxHeight * 0.92),
                child: SingleChildScrollView(
                  // 48 below the real inset, so the card clears the status bar
                  // and any camera cutout on every device with comfortable spacing.
                  padding: EdgeInsets.fromLTRB(16, topInset + 48, 16, 0),
                  child: child,
                ),
              ),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onDismiss,
                  child: const SizedBox.expand(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _OrderOverlayUI extends StatefulWidget {
  const _OrderOverlayUI();

  @override
  State<_OrderOverlayUI> createState() => _OrderOverlayUIState();
}

class _OrderOverlayUIState extends State<_OrderOverlayUI> {
  Map<String, dynamic>? _orderData;

  /// FCM data values are always Strings, so parse rather than cast.
  static double _num(Object? v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString().trim() ?? '') ?? 0.0;
  }

  static String? _str(Object? v) {
    final text = v?.toString().trim();
    return (text == null || text.isEmpty) ? null : text;
  }
  late int _secondsLeft;
  Timer? _countdownTimer;
  Timer? _failsafeTimer;
  bool _closing = false;
  bool _submitting = false;

  Timer? _watchdog;
  StreamSubscription<dynamic>? _dataSub;

  /// When the currently shown order was last applied, so the shareData retry
  /// burst can be told apart from a genuine re-offer of the same order.
  DateTime? _lastAppliedAt;

  /// The offer window, taken from the push rather than hardcoded.
  ///
  /// The backend sends acceptTimeoutSeconds and an absolute
  /// acceptanceDeadlineAt. The deadline is preferred because it cannot drift
  /// with delivery latency, but a push held in Doze arrives already expired —
  /// so the window length is used whenever the deadline is in the past or
  /// missing, rather than opening the card at zero.
  static int _timeoutSecondsFrom(Map<String, dynamic>? data) {
    const fallback = 45;
    if (data == null) return fallback;

    final deadlineRaw = data['acceptanceDeadlineAt']?.toString();
    if (deadlineRaw != null && deadlineRaw.isNotEmpty) {
      final deadline = DateTime.tryParse(deadlineRaw);
      if (deadline != null) {
        final left = deadline.difference(DateTime.now()).inSeconds;
        if (left > 0) return left;
      }
    }

    final windowRaw = data['acceptTimeoutSeconds']?.toString();
    final window = int.tryParse(windowRaw ?? '');
    if (window != null && window > 0) return window;

    return fallback;
  }

  @override
  void initState() {
    super.initState();
    _secondsLeft = 45;

    _failsafeTimer = Timer(const Duration(seconds: 70), _forceClose);

    _watchdog = Timer(const Duration(seconds: 5), () {
      if (_orderData == null) {
        debugPrint('[Overlay] Nothing rendered within 5s — closing to free the screen.');
        _forceClose();
      }
    });

    _dataSub = FlutterOverlayWindow.overlayListener.listen((event) {
      try {
        final decoded = jsonDecode(event.toString());
        if (decoded is Map && mounted) {
          final map = Map<String, dynamic>.from(decoded);
          final incomingId =
              (map['orderMongoId'] ?? map['orderId'] ?? map['_id'])?.toString();
          final currentId = (_orderData?['orderMongoId'] ??
                  _orderData?['orderId'] ??
                  _orderData?['_id'])
              ?.toString();

          // showForOrder fires shareData several times to beat the race with
          // this listener registering, so the same order lands repeatedly
          // within about a second. Those repeats must not restart the countdown
          // or replay the sound.
          //
          // Deduped on a short time window rather than on the id alone. The id
          // check rejected the order FOREVER, so when an admin re-sent the same
          // order the card was ignored outright — the reported "second time it
          // will not start". A resend arrives seconds or minutes later and is a
          // genuinely new offer that must restart the countdown.
          final now = DateTime.now();
          final isRetryBurst = incomingId != null &&
              incomingId == currentId &&
              _lastAppliedAt != null &&
              now.difference(_lastAppliedAt!) < const Duration(seconds: 3);
          if (isRetryBurst) return;

          _lastAppliedAt = now;
          setState(() {
            _orderData = map;
            _secondsLeft = _timeoutSecondsFrom(map);
          });
          _startCountdown();
          
          if (incomingId != null) {
            SharedPreferences.getInstance().then((prefs) {
              prefs.setString('overlay_rendered_order', incomingId);
            });
          }
        }
      } catch (e) {
        debugPrint('[Overlay] Ignoring unreadable shared data: $e');
      }
    });

    _loadOrder();
  }

  Future<void> _loadOrder({int attempt = 0}) async {
    // _freshPrefs (not getInstance) is what makes the retry below able to
    // succeed, and its absence is why the loading state stuck on some devices.
    //
    // getInstance() hands back a per-isolate cached snapshot and never re-reads
    // the disk. When the overlay engine is reused for a second order — which the
    // plugin does on some ROMs and never on others — that snapshot predates the
    // write the FCM isolate just made, so the key looks absent. The retry loop
    // re-called getInstance() and was handed the SAME stale object every time,
    // so it could not possibly recover: it burned a second and then force-closed.
    // A cold engine worked, a reused one did not, which is exactly the "some
    // devices, sometimes" shape of the report.
    //
    // The write is cross-isolate durable; only the reader's cache was stale.
    final prefs = await _freshPrefs();
    final raw = prefs.getString(_pendingOrderPrefsKey);
    if (raw == null) {
      if (attempt < 5) {
        await Future.delayed(const Duration(milliseconds: 200));
        if (mounted) await _loadOrder(attempt: attempt + 1);
        return;
      }
      debugPrint('[Overlay] No pending order found — closing.');
      await _forceClose();
      return;
    }
    
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      await _forceClose();
      return;
    }

    if (mounted) {
      final incomingId = (decoded['orderMongoId'] ?? decoded['orderId'] ?? decoded['_id'])?.toString();
      final map = Map<String, dynamic>.from(decoded);
      _lastAppliedAt = DateTime.now();
      setState(() {
        _orderData = map;
        // Same server-driven window as the shareData path — this one had kept
        // the initState default of 45, so a card restored from disk counted
        // down from a number unrelated to the offer actually in flight.
        _secondsLeft = _timeoutSecondsFrom(map);

      });
      _startCountdown();
      
      if (incomingId != null) {
        prefs.setString('overlay_rendered_order', incomingId);
      }
    }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    SoundService.playEffect('neworder.mp3');
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final next = _secondsLeft - 1;
      setState(() => _secondsLeft = next < 0 ? 0 : next);

      // Counts down to 0 and only then closes.
      //
      // It used to close at 1, so the card never showed 0 — and, worse, the
      // timer was cancelled BEFORE the close was attempted. Any failure to
      // close then left the card frozen at "1s" forever with the countdown
      // already dead, which is exactly the stuck state riders were seeing.
      if (next <= 0) {
        timer.cancel();
        _expire();
      }
    });
  }

  /// The offer ran out. Distinct from accept/reject so the sound and the
  /// countdown state are cleaned up the same way regardless of how it ended.
  Future<void> _expire() async {
    await SoundService.stopEffect();
    await _forceClose();
  }

  Future<void> _forceClose() async {
    if (_closing) return;
    _closing = true;
    _countdownTimer?.cancel();
    _failsafeTimer?.cancel();
    _watchdog?.cancel();
    _dataSub?.cancel();
    await SoundService.stopEffect();

    // closeOverlay is called unconditionally.
    //
    // It used to be gated on isActive(), so whenever that returned false — or
    // threw — the window was left on screen with every timer already cancelled
    // and nothing able to remove it. Closing a window that is already closed is
    // harmless; failing to close one that is open is not.
    try {
      await FlutterOverlayWindow.closeOverlay();
    } catch (_) {
      // Already gone, or the channel is unavailable in this isolate.
    } finally {
      _closing = false;
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _failsafeTimer?.cancel();
    _watchdog?.cancel();
    _dataSub?.cancel();
    SoundService.stopEffect();
    super.dispose();
  }

  String? get _orderId => (_orderData?['orderMongoId'] ??
          _orderData?['orderId'] ??
          _orderData?['_id'])
      ?.toString();

  Future<void> _accept() async {
    if (_submitting) return;
    setState(() => _submitting = true);

    await SoundService.stopEffect();
    _countdownTimer?.cancel();

    if (_orderData != null) {
      _orderData!['autoAccept'] = true;
      final prefs = await _freshPrefs();
      await prefs.setString(_pendingOrderPrefsKey, jsonEncode(_orderData));
    }

    final id = _orderId;
    if (id != null && id.isNotEmpty) {
      unawaited(NewOrderActionChannel.stopSound(id));
      await OrderOverlayService.submitOrderAction(orderId: id, accept: true);
    }
    await OrderOverlayService.reopenApp();
    await _forceClose();
  }

  Future<void> _reject() async {
    if (_submitting) return;
    setState(() => _submitting = true);

    await SoundService.stopEffect();
    _countdownTimer?.cancel();

    final id = _orderId;
    if (id != null && id.isNotEmpty) {
      unawaited(NewOrderActionChannel.stopSound(id));
      await OrderOverlayService.submitOrderAction(orderId: id, accept: false);
    }

    final prefs = await _freshPrefs();
    await prefs.remove(_pendingOrderPrefsKey);
    await _forceClose();
  }

  @override
  Widget build(BuildContext context) {
    if (_orderData == null) {
      return _OverlayShell(
        onDismiss: _forceClose,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 18,
              ),
            ],
          ),
          child: const Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Text(
                  'New order incoming…',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final driverEarning = _num(_orderData?['earnings'] ?? _orderData?['riderEarning'] ?? _orderData?['price'] ?? _orderData?['earningAmount'] ?? _orderData?['total']);
    final tripDistance = _num(_orderData?['tripDistanceKm'] ?? _orderData?['distance']);

    final pickupAddr = _str(_orderData?['pickupAddress']) ??
        _str(_orderData?['restaurantAddress']) ??
        _str(_orderData?['restaurantName']) ??
        'Pickup Location';
    final dropAddr = _str(_orderData?['dropAddress']) ??
        _str(_orderData?['customerAddress']) ??
        'Drop Location';

    final customerName = _str(_orderData?['customerName']) ?? 'Customer';

    return _OverlayShell(
      onDismiss: _forceClose,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 26, 20, 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 20, offset: const Offset(0, -4)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        driverEarning > 0 ? '₹ ${driverEarning.toStringAsFixed(2)}' : '₹ —',
                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.black87),
                      ),
                      if (tripDistance > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE85B17).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${tripDistance.toStringAsFixed(1)} km',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFFE85B17)),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTimelineRow(
                          title: 'RESTAURANT PICKUP',
                          name: _str(_orderData?['restaurantName']) ?? 'Restaurant',
                          address: pickupAddr,
                          dotColor: const Color(0xFFE85B17),
                          phoneColor: const Color(0xFFE85B17),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 3, top: 4, bottom: 4),
                          child: Container(width: 2, height: 16, color: Colors.grey[300]),
                        ),
                        _buildTimelineRow(
                          title: 'CUSTOMER DROP',
                          name: customerName,
                          address: dropAddr,
                          dotColor: Colors.blue,
                          phoneColor: Colors.blue,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: _submitting ? null : _accept,
                          child: Container(
                            height: 62,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE85B17),
                              borderRadius: BorderRadius.circular(31),
                            ),
                            alignment: Alignment.center,
                            child: _submitting
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : Text(
                                    'ACCEPT   ·   ${_secondsLeft}s',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: _reject,
                        child: Container(
                          width: 62,
                          height: 62,
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.red[200]!, width: 2),
                          ),
                          child: Icon(Icons.close_rounded, color: Colors.red[700], size: 32),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildTimelineRow({
    required String title, 
    required String name, 
    required String address, 
    required Color dotColor,
    required Color phoneColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.rectangle,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: dotColor)),
              const SizedBox(height: 4),
              Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.black87)),
              const SizedBox(height: 2),
              Text(
                address,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

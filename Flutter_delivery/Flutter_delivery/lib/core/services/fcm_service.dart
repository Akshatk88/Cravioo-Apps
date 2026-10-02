import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';
import '../network/api_endpoints.dart';
import '../network/dio_client.dart';
import '../storage/token_storage.dart';
import 'new_order_action_channel.dart';
import 'new_order_overlay_bridge.dart';
import 'order_resolution_tracker.dart';

/// Dedicated channel for incoming-order alerts — separate from
/// [_ordersChannel] because it needs call-category / full-screen-intent
/// semantics that a plain order-status-update notification shouldn't have.
const _incomingOrdersChannel = AndroidNotificationChannel(
  'incoming_orders_channel_v6',
  'Incoming Orders',
  description: 'Full-screen incoming order alerts that require immediate action',
  importance: Importance.max,
  playSound: true,
  sound: RawResourceAndroidNotificationSound('tujh_bin1'),
);

const _ordersChannel = AndroidNotificationChannel(
  'orders_channel',
  'Order Updates',
  description: 'New order alerts and delivery status updates',
  importance: Importance.max,
);

/// Stable notification id for an order's incoming alert.
///
/// The alert used to be posted under `message.hashCode`, which is derived from the
/// push itself and is therefore unknowable to anything that later wants to take the
/// alert down. Keying on the order id means the withdrawal push can cancel exactly
/// the alert its order raised. Masked positive because Android ids are ints and a
/// negative one is not portable across the plugin.
int incomingOrderNotificationId(String orderId) => orderId.hashCode & 0x7fffffff;

String? _orderIdOf(Map<String, dynamic> data) {
  final id = (data['orderMongoId'] ??
          data['orderId'] ??
          data['_id'] ??
          data['id'] ??
          data['order_id'] ??
          (data['data'] is Map
              ? (data['data']['orderMongoId'] ??
                  data['data']['orderId'] ??
                  data['data']['_id'] ??
                  data['data']['id'])
              : null))
      ?.toString();
  return (id == null || id.isEmpty) ? null : id;
}

/// Takes down the incoming-order alert for [orderId] wherever it is showing.
///
/// Safe to call from the background isolate, which is the case that matters: the
/// rider whose app is closed is the one the socket `order_claimed` event cannot
/// reach, so this is the only path that clears their screen.
Future<void> dismissIncomingOrderAlert(String orderId) async {
  await NewOrderActionChannel.stopSound(orderId);
  await NewOrderActionChannel.dismiss(orderId);
  // The native overlay is taken down by NewOrderMessagingService on the same push;
  // this covers the app-alive paths (accept/decline/socket withdrawal).
  await NewOrderOverlayBridge.dismiss();
  final localNotifications = FlutterLocalNotificationsPlugin();
  await localNotifications.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/launcher_icon'),
    ),
    onDidReceiveBackgroundNotificationResponse: backgroundNotificationResponseHandler,
  );
  await localNotifications.cancel(incomingOrderNotificationId(orderId));
  await cancelFcmTrayCopy(orderId);
}

@pragma('vm:entry-point')
void backgroundNotificationResponseHandler(NotificationResponse response) async {
  try {
    DartPluginRegistrant.ensureInitialized();
  } catch (_) {}

  final payload = response.payload;
  final actionId = response.actionId;

  if (actionId == 'accept' || actionId == 'reject') {
    final orderId = _orderIdOfPayload(payload);
    if (orderId != null) {
      await _respondToOrderFromBackground(orderId: orderId, accept: actionId == 'accept');
    }
  }
}

String? _orderIdOfPayload(String? payload) {
  if (payload == null || payload.isEmpty) return null;
  try {
    final decoded = jsonDecode(payload);
    if (decoded is Map) {
      final id = (decoded['orderMongoId'] ?? decoded['orderId'] ?? decoded['_id'])?.toString();
      return (id == null || id.isEmpty) ? null : id;
    }
  } catch (_) {}
  return payload;
}

Future<void> _respondToOrderFromBackground({
  required String orderId,
  required bool accept,
}) async {
  try {
    try {
      DartPluginRegistrant.ensureInitialized();
    } catch (_) {}
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'access_token');
    if (token != null && token.isNotEmpty) {
      final dio = Dio(BaseOptions(
        baseUrl: AppConstants.baseUrl,
        headers: {'Authorization': 'Bearer $token'},
      ));
      await dio.patch(
        accept
            ? ApiEndpoints.orderAccept(orderId)
            : ApiEndpoints.orderReject(orderId),
      );
    }
  } catch (e) {
    if (kDebugMode) {
      debugPrint('[FCM Background Action] Error responding to order $orderId: $e');
    }
  } finally {
    try {
      final localNotifications = FlutterLocalNotificationsPlugin();
      await localNotifications.cancel(incomingOrderNotificationId(orderId));
      await NewOrderActionChannel.stopSound(orderId);
      await NewOrderActionChannel.dismiss(orderId);
      await cancelFcmTrayCopy(orderId);

      const feedbackChannel = AndroidNotificationChannel(
        'delivery_action_feedback_channel',
        'Delivery Action Feedback',
        description: 'Shows confirmation when delivery order is accepted or rejected.',
        importance: Importance.defaultImportance,
      );
      final androidPlugin = localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(feedbackChannel);
      await localNotifications.show(
        incomingOrderNotificationId(orderId),
        accept ? 'Order Accepted ✅' : 'Order Rejected ❌',
        accept ? 'Delivery order #$orderId has been accepted.' : 'Delivery order #$orderId was rejected.',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'delivery_action_feedback_channel',
            'Delivery Action Feedback',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
            autoCancel: true,
          ),
        ),
      );
    } catch (_) {}
  }
}

/// Removes the OS-rendered copy of the new-order push.
///
/// The push is hybrid: FCM posts a tray notification itself (tag `order_<id>`,
/// set by the backend — the two must stay in sync) so ROMs that refuse to start
/// the app in the background still ring. Wherever OUR alert does manage to show,
/// this takes the tray copy down so the rider sees one alert, not two. FCM posts
/// tagged notifications under id 0.
Future<void> cancelFcmTrayCopy(String orderId) async {
  try {
    await FlutterLocalNotificationsPlugin().cancel(0, tag: 'order_$orderId');
  } catch (_) {
    // Worst case the tray copy stays — a duplicate, not a lost order.
  }
}

Future<String?> _fetchRemoteOrderStatus(String orderId) async {
  try {
    const storage = FlutterSecureStorage();
    String? token = await storage.read(key: 'access_token');
    if (token == null || token.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      token = prefs.getString('delivery_access_token');
    }
    final dio = Dio(BaseOptions(
      baseUrl: AppConstants.baseUrl,
      connectTimeout: const Duration(seconds: 3),
      receiveTimeout: const Duration(seconds: 3),
      headers: {
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
    ));
    final res = await dio.get(ApiEndpoints.orderDetails(orderId));
    final data = res.data['data'] as Map<String, dynamic>?;
    final order = data?['order'] is Map ? data!['order'] as Map : data;
    return order?['orderStatus']?.toString().toLowerCase();
  } catch (_) {
    return null;
  }
}

/// Must stay top-level / static so the Dart VM can invoke it in the
/// background isolate when a push arrives while the app is killed.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();

  final type = message.data['type']?.toString();

  // Android owns new orders natively (NewOrderMessagingService). The plugin's
  // receiver starts this handler independently of that service, so returning
  // early there cannot stop it — it has to return here, before anything is posted.
  if (Platform.isAndroid && type == 'new_order') {
    debugPrint('[NEW_ORDER] handled natively — Dart posts nothing');
    return;
  }

  final orderId = _orderIdOf(message.data);
  String? orderStatus = (message.data['orderStatus'] ?? message.data['status'])?.toString().toLowerCase();
  final title = (message.data['title'] ?? message.notification?.title ?? '').toString().toLowerCase();
  final body = (message.data['body'] ?? message.notification?.body ?? '').toString().toLowerCase();

  final isOrderReadyType = type == 'order_ready' ||
      type == 'order_ready_for_pickup' ||
      title.contains('ready for pickup') ||
      title.contains('order ready') ||
      body.contains('ready for pickup') ||
      body.contains('order ready');

  if ((orderStatus == null || orderStatus.isEmpty) && !isOrderReadyType && orderId != null) {
    orderStatus = await _fetchRemoteOrderStatus(orderId);
  }

  final isReady = isOrderReadyType ||
      orderStatus == 'ready_for_pickup' ||
      orderStatus == 'ready';

  final isNotReady = (orderStatus != null && (
      orderStatus == 'created' ||
      orderStatus == 'pending' ||
      orderStatus == 'placed' ||
      orderStatus == 'confirmed' ||
      orderStatus == 'preparing')) || (!isReady && orderStatus != null);

  final isDismiss = type == 'order_taken' ||
      type == 'order_deassigned' ||
      type == 'order_cancelled' ||
      type == 'cancel_order' ||
      type == 'order_completed' ||
      type == 'order_delivered' ||
      isNotReady ||
      (orderId != null && OrderResolutionTracker.isResolved(orderId));

  if (isDismiss && orderId != null) {
    await dismissIncomingOrderAlert(orderId);
    return;
  }

  final isNewOrderPush = isReady && !isNotReady && (
      type == 'new_order' ||
      type == 'new_order_available' ||
      type == 'order_assigned' ||
      type == 'delivery_partner_assigned' ||
      isOrderReadyType ||
      message.data['audience'] == 'delivery' ||
      message.data.containsKey('pickupAddress') ||
      message.data.containsKey('restaurantName')
  );

  if (!isNewOrderPush) {
    return;
  }

  if (Platform.isAndroid) {
    // Android posts the card — or, failing that, the notification — natively in
    // NewOrderMessagingService. It has to be decided there because that is the
    // only place that knows whether the overlay went up, and the plugin's own
    // receiver runs this handler regardless of what the service does. Posting
    // from here as well is what put a notification on top of the card.
    debugPrint('[NEW_ORDER_NOTIFICATION] handled natively — Dart posts nothing');
    return;
  }

  try {
    // A fresh isolate on non-Android — the channel/plugin registered by FcmService.initialize()
    // in the main isolate doesn't exist here, so set both up again.
    final localNotifications = FlutterLocalNotificationsPlugin();
    await localNotifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/launcher_icon'),
      ),
      onDidReceiveBackgroundNotificationResponse: backgroundNotificationResponseHandler,
    );
    final androidPlugin = localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_incomingOrdersChannel);
    await androidPlugin?.createNotificationChannel(_ordersChannel);
    await androidPlugin?.createNotificationChannel(_defaultChannel);

    final pickup = message.data['pickupAddress'] as String? ?? 'Restaurant';
    final drop = message.data['dropAddress'] as String? ?? 'Customer';
    final price = message.data['price'] as String? ?? '';
    final distance = message.data['distance'] as String? ?? '';
    final body = 'From: $pickup\nTo: $drop\nEarnings: ₹$price | Dist: ${distance}km';

    await localNotifications.show(
      incomingOrderNotificationId(_orderIdOf(message.data) ?? ''),
      message.data['restaurantName'] as String? ?? 'New order',
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _incomingOrdersChannel.id,
          _incomingOrdersChannel.name,
          channelDescription: _incomingOrdersChannel.description,
          importance: Importance.max,
          priority: Priority.high,
          category: AndroidNotificationCategory.call,
          fullScreenIntent: true,
          ongoing: true,
          playSound: true,
          sound: const RawResourceAndroidNotificationSound('tujh_bin1'),
          styleInformation: BigTextStyleInformation(body),
          actions: <AndroidNotificationAction>[
            const AndroidNotificationAction(
              'accept',
              'Accept',
              showsUserInterface: true,
              cancelNotification: true,
            ),
            const AndroidNotificationAction(
              'reject',
              'Reject',
              showsUserInterface: false,
              cancelNotification: true,
            ),
          ],
        ),
      ),
      payload: jsonEncode(message.data),
    );
  } catch (_) {
    // Non-Android fallback
  }
}

/// The backend's FCM_DEFAULT_CHANNEL_ID, used for every push that is NOT a
/// new-order alert (order status updates and the like).
///
/// Those arrive WITH a notification block, so the OS renders them against this id
/// directly. Android silently ignores an unknown channel id and drops back to a
/// low-importance default, so never creating this one left every status update
/// without a heads-up — indistinguishable from the push not arriving at all.
const _defaultChannel = AndroidNotificationChannel(
  'default',
  'Default Channel',
  description: 'Default notification channel for order status updates and alerts',
  importance: Importance.max,
);

const _highImportanceChannel = AndroidNotificationChannel(
  'high_importance_channel',
  'Order updates',
  description: 'Order status updates and alerts',
  importance: Importance.max,
);

class FcmService {
  FcmService(this._dio, this._tokenStorage);

  final Dio _dio;
  final TokenStorage _tokenStorage;

  final _localNotifications = FlutterLocalNotificationsPlugin();
  final _notificationTapController = StreamController<Map<String, dynamic>>.broadcast();
  final _notificationReceivedController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get onNotificationTap =>
      _notificationTapController.stream;
      
  Stream<Map<String, dynamic>> get onNotificationReceived =>
      _notificationReceivedController.stream;

  static const _channel = _ordersChannel;

  Future<void> initialize() async {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Attach message listeners IMMEDIATELY so no incoming push is ever dropped
    // while waiting for permissions or channel creation.
    FirebaseMessaging.onMessage.listen(_showForegroundNotification);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationOpen);
    FirebaseMessaging.instance.onTokenRefresh.listen(_saveToken);

    // Register token on cold start right away
    unawaited(registerToken());

    unawaited(FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    ));

    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    const androidInit = AndroidInitializationSettings('@mipmap/launcher_icon');
    const iosInit = DarwinInitializationSettings();
    await _localNotifications.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: _handleNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: backgroundNotificationResponseHandler,
    );

    if (Platform.isAndroid) {
      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await androidPlugin?.createNotificationChannel(_defaultChannel);
      await androidPlugin?.createNotificationChannel(_channel);
      await androidPlugin?.createNotificationChannel(_highImportanceChannel);
      await androidPlugin?.createNotificationChannel(_incomingOrdersChannel);
    }

    // Cold start via the full-screen-intent notification (lock screen /
    // killed app) — onDidReceiveNotificationResponse above isn't guaranteed
    // to fire for the launching notification itself, so check explicitly.
    final launchDetails = await _localNotifications.getNotificationAppLaunchDetails();
    final launchResponse = launchDetails?.notificationResponse;
    if ((launchDetails?.didNotificationLaunchApp ?? false) && launchResponse != null) {
      _handleNotificationResponse(launchResponse);
    }

    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) _handleNotificationOpen(initialMessage);

    // Check alert & overlay permissions after listeners are safely attached
    unawaited(ensureAndroidAlertPermissions());
  }

  /// Re-checked on every cold start AND every app resume (see main.dart's
  /// `didChangeAppLifecycleState`), not just once at cold start.
  ///
  /// Android 14+ revokes USE_FULL_SCREEN_INTENT by default for apps without
  /// calling/alarm functionality, even though it's declared in the
  /// manifest — without this explicit grant, fullScreenIntent notifications
  /// silently downgrade to a normal heads-up banner on both the lock screen
  /// and home screen. `requestFullScreenIntentPermission()` no-ops (returns
  /// true) if already granted or on pre-Android-14 devices, so it's cheap
  /// to call repeatedly. Re-running it on resume also catches riders who
  /// dismissed the Settings prompt the first time, or who granted/revoked
  /// it manually from system Settings mid-session — a one-shot check at
  /// process init would otherwise miss both cases for the app's entire
  /// lifetime in memory.
  Future<void> ensureAndroidAlertPermissions() async {
    if (!Platform.isAndroid) return;

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.requestNotificationsPermission();
    await androidPlugin?.requestFullScreenIntentPermission();
  }

  /// Routes a notification interaction: an Accept/Reject action button, or a
  /// plain tap on the notification body.
  ///
  /// The action id was previously discarded, so both buttons did exactly the same
  /// thing as tapping the notification — open the order screen. They looked like
  /// Accept and Reject but neither accepted nor rejected anything.
  ///
  /// Both actions are declared `showsUserInterface: true`, so the OS launches or
  /// resumes the app before dispatching here. That means the main isolate is alive
  /// and the injected Dio client (with its auth interceptor) is usable — no
  /// separate isolate-safe path is needed.
  void _handleNotificationResponse(NotificationResponse response) async {
    final payload = response.payload;
    final actionId = response.actionId;

    if (actionId == 'accept') {
      final orderId = _orderIdFromPayload(payload);
      if (orderId != null) {
        await _respondToOrder(orderId: orderId, accept: true);
        await dismissIncomingOrderAlert(orderId);
        await showLocalNotification(
          title: 'Order Accepted ✅',
          body: 'Delivery order #$orderId has been accepted.',
        );
      }
      if (payload != null) _handleLocalNotificationPayload(payload);
      return;
    }

    if (actionId == 'reject') {
      final orderId = _orderIdFromPayload(payload);
      if (orderId != null) {
        await _respondToOrder(orderId: orderId, accept: false);
        await dismissIncomingOrderAlert(orderId);
        await showLocalNotification(
          title: 'Order Rejected ❌',
          body: 'Delivery order #$orderId was rejected.',
        );
      }
      return;
    }

    if (payload != null) _handleLocalNotificationPayload(payload);
  }

  String? _orderIdFromPayload(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map) {
        final id = (decoded['orderMongoId'] ?? decoded['orderId'])?.toString();
        return (id == null || id.isEmpty) ? null : id;
      }
    } catch (_) {
      // Legacy bare-orderId payload.
    }
    return payload;
  }

  Future<void> _respondToOrder({
    required String orderId,
    required bool accept,
  }) async {
    try {
      await _dio.patch(
        accept
            ? ApiEndpoints.orderAccept(orderId)
            : ApiEndpoints.orderReject(orderId),
      );
    } catch (_) {
      // Best-effort: the offer may already have expired or gone to another rider.
      // The order screen we open alongside this shows the real current state.
    }
  }

  /// Payload from a locally-shown notification — the full-screen incoming-
  /// order alert encodes the whole data map as JSON; older/other local
  /// notifications may still carry a bare orderId string.
  void _handleLocalNotificationPayload(String payload) {
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map) {
        _notificationTapController.add(Map<String, dynamic>.from(decoded));
        return;
      }
    } catch (_) {
      // Not JSON — fall through to the legacy plain-orderId form.
    }
    _notificationTapController.add({'orderId': payload});
  }

  Future<bool> registerToken() async {
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null || token.isEmpty) {
      if (kDebugMode) debugPrint('[FCM Delivery] getToken returned null or empty');
      return false;
    }
    return await _saveToken(token);
  }

  Future<bool> _saveToken(String token) async {
    await _tokenStorage.saveFcmToken(token);

    for (var attempt = 0; attempt < 3; attempt++) {
      if (attempt > 0) {
        await Future.delayed(Duration(seconds: attempt * 2));
      }

      final accessToken = await _tokenStorage.getAccessToken();
      if (accessToken == null || accessToken.isEmpty) {
        if (kDebugMode) debugPrint('[FCM Delivery] No access token found (attempt ${attempt + 1})');
        continue;
      }

      final endpoints = [
        ApiEndpoints.fcmTokenSaveMobile,
        '/fcm-tokens/save',
        '/v1/fcm-tokens/mobile/save',
        '/v1/fcm-tokens/save',
      ];

      for (final endpoint in endpoints) {
        try {
          await _dio.post(
            endpoint,
            data: {'token': token, 'platform': 'mobile'},
            options: Options(
              headers: {'Authorization': 'Bearer $accessToken'},
            ),
          );
          debugPrint('[FCM Delivery] Token registered successfully on backend ($endpoint): $token');
          return true;
        } catch (e) {
          if (kDebugMode) {
            debugPrint('[FCM Delivery] Save attempt ${attempt + 1} ($endpoint) failed: $e');
          }
        }
      }
    }
    return false;
  }

  /// Unsubscribes this device from pushes for the account being signed out.
  ///
  /// The token was not being sent, so the server had no idea which device to
  /// detach — it rejected the call, this catch swallowed the error, and logout
  /// completed locally with the token still attached. The rider signed out and
  /// kept receiving new-order alerts.
  ///
  /// Sends the token the device actually holds so only this device is detached.
  /// Falls back to the live FCM token when nothing was stored, and to a bare
  /// request when neither is available — the server treats that as "sign this
  /// owner out everywhere", which is still better than leaving it subscribed.
  Future<void> removeToken() async {
    String? token = await _tokenStorage.getFcmToken();
    if (token == null || token.isEmpty) {
      try {
        token = await FirebaseMessaging.instance.getToken();
      } catch (_) {
        token = null;
      }
    }

    try {
      await _dio.delete(
        ApiEndpoints.fcmTokenRemove,
        data: (token != null && token.isNotEmpty) ? {'token': token} : null,
      );
    } catch (_) {
      // Ignore — logging out locally regardless.
    }
    try {
      // Force Firebase to invalidate this token locally. This guarantees that 
      // even if the backend fails to remove it from the old user's profile, 
      // this device will no longer receive their pushes. The next user to 
      // log in will get a brand new unique token.
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {}
  }

  void _showForegroundNotification(RemoteMessage message) async {
    final orderId = _orderIdOf(message.data);
    final type = message.data['type']?.toString();
    String? orderStatus = (message.data['orderStatus'] ?? message.data['status'])?.toString().toLowerCase();
    final title = (message.data['title'] ?? message.notification?.title ?? '').toString().toLowerCase();
    final rawBody = (message.data['body'] ?? message.notification?.body ?? '').toString().toLowerCase();

    final isOrderReadyType = type == 'order_ready' ||
        type == 'order_ready_for_pickup' ||
        title.contains('ready for pickup') ||
        title.contains('order ready') ||
        rawBody.contains('ready for pickup') ||
        rawBody.contains('order ready');

    if ((orderStatus == null || orderStatus.isEmpty) && !isOrderReadyType && orderId != null) {
      orderStatus = await _fetchRemoteOrderStatus(orderId);
    }

    final isReady = isOrderReadyType ||
        orderStatus == 'ready_for_pickup' ||
        orderStatus == 'ready';

    final isNotReady = (orderStatus != null && (
        orderStatus == 'created' ||
        orderStatus == 'pending' ||
        orderStatus == 'placed' ||
        orderStatus == 'confirmed' ||
        orderStatus == 'preparing')) || (!isReady && orderStatus != null);

    final isDismiss = type == 'order_taken' ||
        type == 'order_deassigned' ||
        type == 'order_cancelled' ||
        type == 'cancel_order' ||
        type == 'order_completed' ||
        type == 'order_delivered' ||
        isNotReady ||
        (orderId != null && OrderResolutionTracker.isResolved(orderId));

    if (isDismiss && orderId != null) {
      _localNotifications.cancel(incomingOrderNotificationId(orderId));
      unawaited(NewOrderActionChannel.stopSound(orderId));
      unawaited(NewOrderActionChannel.dismiss(orderId));
      return;
    }

    final isNewOrderPush = isReady && !isNotReady && (
        type == 'new_order' ||
        type == 'new_order_available' ||
        type == 'order_assigned' ||
        type == 'delivery_partner_assigned' ||
        isOrderReadyType ||
        message.data['audience'] == 'delivery' ||
        message.data.containsKey('pickupAddress') ||
        message.data.containsKey('restaurantName')
    );

    if (!isNewOrderPush) {
      return;
    }

    if (orderId != null && OrderResolutionTracker.hasAlertedRecently(orderId)) {
      return;
    }
    if (orderId != null) {
      OrderResolutionTracker.markAlerted(orderId);
    }

    _notificationReceivedController.add(message.data);

    final notification = message.notification;
    final displayTitle = notification?.title ??
        message.data['title'] ??
        (isOrderReadyType
            ? 'Order ready for pickup 🛍️'
            : message.data['restaurantName'] ?? 'New Order Available');

    String body;
    if (isNewOrderPush) {
      final pickup = message.data['pickupAddress'] as String? ?? 'Restaurant';
      final drop = message.data['dropAddress'] as String? ?? 'Customer';
      final price = message.data['price'] as String? ?? '';
      final distance = message.data['distance'] as String? ?? '';
      body = 'From: $pickup\nTo: $drop\nEarnings: ₹$price | Dist: ${distance}km';
    } else {
      body = notification?.body ??
          message.data['body'] ??
          (isOrderReadyType
              ? 'Order is ready at the restaurant.'
              : 'You have an order update');
    }

    final notifId = isNewOrderPush && orderId != null
        ? incomingOrderNotificationId(orderId)
        : message.hashCode;

    try {
      _localNotifications.show(
        notifId,
        displayTitle,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            isNewOrderPush
                ? _incomingOrdersChannel.id
                : _defaultChannel.id,
            isNewOrderPush
                ? _incomingOrdersChannel.name
                : _defaultChannel.name,
            channelDescription: isNewOrderPush
                ? _incomingOrdersChannel.description
                : _defaultChannel.description,
            importance: Importance.max,
            priority: Priority.max,
            category: isNewOrderPush ? AndroidNotificationCategory.call : AndroidNotificationCategory.event,
            visibility: NotificationVisibility.public,
            icon: '@mipmap/launcher_icon',
            playSound: true,
            sound: isNewOrderPush
                ? const RawResourceAndroidNotificationSound('tujh_bin1')
                : null,
            styleInformation: BigTextStyleInformation(body),
            fullScreenIntent: isNewOrderPush,
            ongoing: isNewOrderPush,
            autoCancel: !isNewOrderPush,
            actions: isNewOrderPush
                ? const <AndroidNotificationAction>[
                    AndroidNotificationAction(
                      'accept',
                      'Accept',
                      showsUserInterface: true,
                      cancelNotification: true,
                    ),
                    AndroidNotificationAction(
                      'reject',
                      'Reject',
                      showsUserInterface: false,
                      cancelNotification: true,
                    ),
                  ]
                : null,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        payload: jsonEncode(message.data),
      );
      if (isNewOrderPush && orderId != null) {
        unawaited(cancelFcmTrayCopy(orderId));
      }
    } catch (_) {}
  }

  Future<void> showLocalNotification({
    required String title,
    required String body,
    Map<String, dynamic>? payload,
  }) async {
    try {
      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch & 0x7fffffff,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _defaultChannel.id,
            _defaultChannel.name,
            channelDescription: _defaultChannel.description,
            importance: Importance.max,
            priority: Priority.high,
            icon: '@mipmap/launcher_icon',
            playSound: true,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        payload: payload != null ? jsonEncode(payload) : null,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[FcmService] showLocalNotification error: $e');
    }
  }

  void _handleNotificationOpen(RemoteMessage message) {
    _notificationTapController.add(message.data);
  }

  void dispose() {
    _notificationTapController.close();
    _notificationReceivedController.close();
  }
}

final fcmServiceProvider = Provider<FcmService>((ref) {
  final service = FcmService(
    ref.read(dioProvider),
    ref.read(tokenStorageProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_user_application/config/theme/app_theme.dart';
import 'package:go_router/go_router.dart';
import 'package:food_user_application/core/providers/core_providers.dart';
import 'package:food_user_application/core/services/fcm_service.dart';
import 'package:food_user_application/core/services/new_order_action_channel.dart';
import 'package:food_user_application/core/services/order_resolution_tracker.dart';
import 'package:food_user_application/core/services/order_notification_action_handler.dart';
import 'package:food_user_application/config/router/app_router.dart';
import 'package:food_user_application/core/services/socket_service.dart';
import 'package:food_user_application/core/services/local_notification_service.dart';
import 'package:food_user_application/features/orders/presentation/views/incoming_order_dialog.dart';
import 'package:food_user_application/features/auth/presentation/controllers/auth_controller.dart';
import 'package:food_user_application/features/auth/presentation/controllers/auth_state.dart';
import 'package:food_user_application/features/orders/domain/order_model.dart';
import 'package:food_user_application/features/orders/presentation/controllers/live_orders_controller.dart';
import 'package:food_user_application/config/theme/theme_mode_provider.dart';
import 'package:food_user_application/core/services/network_controller.dart';
import 'package:food_user_application/core/widgets/no_network_overlay.dart';
import 'package:food_user_application/features/dining/presentation/controllers/dining_controller.dart';

class FoodUserApplication extends ConsumerStatefulWidget {
  const FoodUserApplication({super.key});

  @override
  ConsumerState<FoodUserApplication> createState() =>
      _FoodUserApplicationState();
}

class _FoodUserApplicationState extends ConsumerState<FoodUserApplication>
    with WidgetsBindingObserver {
  StreamSubscription<NewOrderAction>? _orderActionSub;
  StreamSubscription<String>? _incomingOrderSub;
  bool _socketAlertsWired = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Attached before anything else can produce a decision.
    NewOrderActionChannel.initialize();
    _orderActionSub = NewOrderActionChannel.onAction.listen(_handleOrderAction);
    // Two orders at once: answering one dialog brings up the next unanswered one.
    incomingOrderDialogClosedHook = () {
      Future.delayed(const Duration(milliseconds: 600), () async {
        if (!mounted) return;
        await ref.read(liveOrdersControllerProvider.notifier).refresh();
        if (mounted) _checkLiveOrdersForPendingAlert(force: true);
      });
    };
    _incomingOrderSub = NewOrderActionChannel.onIncomingOrder.listen(
      (orderId) => unawaited(_openIncomingOrder(orderId)),
    );

    // Cold start checks
    unawaited(_consumePendingIncomingOrder());
    unawaited(_consumePendingOrderAction());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(fcmServiceProvider).initForegroundHandling();
      _wireGlobalOrderAlerts();
    });
  }

  Future<void> _consumePendingIncomingOrder() async {
    final orderId = await NewOrderActionChannel.consumePendingIncomingOrderId();
    if (orderId == null || orderId.isEmpty) return;
    await _openIncomingOrder(orderId);
  }

  /// The outlet this session is signed in as. The live auth state is not yet set
  /// on a cold start from a notification, so fall back to what was stored.
  Future<String?> _activeOutletId() async {
    final auth = ref.read(authControllerProvider);
    if (auth is AuthAuthenticated) return auth.restaurant.id;
    try {
      return await ref.read(tokenStorageProvider).restaurantId;
    } catch (_) {
      return null;
    }
  }

  /// Sync version for places that cannot await; null when not signed in yet.
  String? get _activeOutletIdNow {
    final auth = ref.read(authControllerProvider);
    return auth is AuthAuthenticated ? auth.restaurant.id : null;
  }

  bool _isOtherOutlet(String? restaurantId, String? active) =>
      restaurantId != null &&
      restaurantId.isNotEmpty &&
      active != null &&
      active.isNotEmpty &&
      restaurantId != active;

  /// A new-order alert was tapped (or the app was opened on one).
  ///
  /// If the order belongs to another outlet of this owner, switch the app to that
  /// outlet first and land on its Orders section, then show the order there — the
  /// accept/reject calls are made as that outlet, so they work and nothing hangs.
  Future<void> _openIncomingOrder(String orderId) async {
    if (OrderResolutionTracker.isResolved(orderId)) return;

    final outletId = await NewOrderActionChannel.consumePendingIncomingOutlet();
    if (_isOtherOutlet(outletId, await _activeOutletId())) {
      try {
        await ref.read(authControllerProvider.notifier).switchOutlet(outletId!);
      } catch (_) {
        final ctx = rootNavigatorKey.currentContext;
        if (ctx != null && ctx.mounted) {
          ScaffoldMessenger.of(ctx).showSnackBar(
            const SnackBar(content: Text('Could not open that outlet. Please try again.')),
          );
        }
        return;
      }
      final ctx = rootNavigatorKey.currentContext;
      if (ctx != null && ctx.mounted) GoRouter.of(ctx).go('/orders');
    }

    NewOrderActionChannel.startSound(orderId);
    _showIncomingDialogWithRetry(orderId);
  }

  void _showIncomingDialogWithRetry(String orderId, [int attempt = 0]) {
    final navState = rootNavigatorKey.currentState;
    final ctx = navState?.overlay?.context ?? rootNavigatorKey.currentContext;
    if (ctx != null) {
      showIncomingOrderDialog(ctx, orderId: orderId);
    } else if (attempt < 8) {
      Future.delayed(Duration(milliseconds: 250 * (attempt + 1)), () {
        _showIncomingDialogWithRetry(orderId, attempt + 1);
      });
    }
  }

  void _wireGlobalOrderAlerts() {
    final socket = ref.read(socketServiceProvider);
    socket.connect();

    if (_socketAlertsWired) return;
    _socketAlertsWired = true;

    void handleOrderPayload(dynamic data) {
      ref.read(liveOrdersControllerProvider.notifier).refresh();
      try {
        String? orderId;
        String? displayId;
        // Another outlet's order: no dialog here (it could not be answered as this
        // outlet). The alert notification covers it; tapping switches outlets.
        if (data is Map &&
            _isOtherOutlet(
              (data['restaurantId'] is Map
                      ? data['restaurantId']['_id']
                      : data['restaurantId'])
                  ?.toString(),
              _activeOutletIdNow,
            )) {
          return;
        }
        if (data is Map) {
          orderId = (data['orderMongoId'] ??
                  data['_id'] ??
                  data['orderId'] ??
                  data['id'] ??
                  data['order_id'])
              ?.toString();
          displayId = (data['orderId'] ?? data['orderDisplayId'] ?? orderId)?.toString();
        }
        if (orderId != null && orderId.isNotEmpty && !OrderResolutionTracker.hasAlertedRecently(orderId)) {
          OrderResolutionTracker.markAlerted(orderId);
          final targetOrderId = orderId;
          NewOrderActionChannel.startSound(targetOrderId);
          _showIncomingDialogWithRetry(targetOrderId);
          // On Android, Native FCM service already displays the high-priority alert.
          // Don't post a duplicate system tray notification from socket handler on Android!
          if (defaultTargetPlatform != TargetPlatform.android) {
            LocalNotificationService.instance.show(
              title: 'New order received',
              body: displayId != null ? 'Order #$displayId is waiting for review.' : 'New order received',
              payload: '{"type":"new_order","orderId":"$orderId"}',
              isNewOrder: true,
              fullScreenIntent: false,
            );
          }
        }
      } catch (_) {}
    }

    void handleDiningPayload(dynamic data) {
      ref.read(diningControllerProvider.notifier).refresh();
      try {
        String title = 'New Dining Reservation Request 🍽️';
        String body = 'A new table reservation request has arrived.';
        if (data is Map) {
          final guestName = data['guestName']?.toString();
          final guests = data['guests']?.toString();
          final date = data['date']?.toString() ?? data['bookingDate']?.toString();
          final slotStart = data['slotStart']?.toString();
          if (guestName != null && guests != null) {
            body = '$guestName booked for $guests guests${date != null ? ' ($date $slotStart)' : ''}';
          }
        }
        LocalNotificationService.instance.show(
          title: title,
          body: body,
          payload: '{"type":"dining_booking"}',
          isNewOrder: false,
          fullScreenIntent: false,
        );
      } catch (_) {}
    }

    socket.on('new_order', handleOrderPayload);
    socket.on('new_order_available', handleOrderPayload);
    socket.on('new_dining_booking', handleDiningPayload);
    socket.on('dining_booking_updated', (_) {
      ref.read(diningControllerProvider.notifier).refresh();
    });

    socket.on('play_notification_sound', (data) {
      try {
        if (data is Map &&
            (data['type'] == 'new_order' || data['type'] == 'new_order_available')) {
          final orderId = (data['orderMongoId'] ??
                  data['_id'] ??
                  data['orderId'] ??
                  data['id'] ??
                  data['order_id'])
              ?.toString();
          if (orderId != null && orderId.isNotEmpty && !OrderResolutionTracker.hasAlertedRecently(orderId)) {
            OrderResolutionTracker.markAlerted(orderId);
            final targetOrderId = orderId;
            NewOrderActionChannel.startSound(targetOrderId);
            _showIncomingDialogWithRetry(targetOrderId);
          }
        }
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _orderActionSub?.cancel();
    _incomingOrderSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// [force]: right after a dialog closed - an order that came in while it was
  /// open was already "alerted" but its dialog could not open then.
  void _checkLiveOrdersForPendingAlert({bool force = false}) {
    final orders = ref.read(liveOrdersControllerProvider).value;
    if (orders == null || orders.isEmpty) return;
    final unaccepted = orders.where((o) =>
        !o.isCancelled &&
        !OrderResolutionTracker.isResolved(o.id) &&
        (o.orderStatus == 'created' ||
            o.orderStatus == 'placed' ||
            o.orderStatus == 'pending' ||
            o.restaurantBucket == 'new'));
    if (unaccepted.isNotEmpty) {
      final first = unaccepted.first;
      if (force || !OrderResolutionTracker.hasAlertedRecently(first.id)) {
        OrderResolutionTracker.markAlerted(first.id);
        NewOrderActionChannel.startSound(first.id);
        _showIncomingDialogWithRetry(first.id);
      }
    }
  }

  /// Carry out a decision made on the native new-order alert.
  ///
  /// Kotlin deliberately records the decision without acting on it: the status update
  /// needs the auth token, which lives on this side. This is the single place that
  /// turns a notification button press into a real accept or reject.
  Future<void> _handleOrderAction(NewOrderAction action) async {
    OrderResolutionTracker.markResolved(action.orderId);
    await submitOrderDecision(
      orderId: action.orderId,
      accepted: action.accepted,
    );
    // Clear the alert either way: on success it has been answered, and on failure
    // leaving it ringing invites a second press that would submit twice.
    await NewOrderActionChannel.stopSound(action.orderId);
    await NewOrderActionChannel.dismiss(action.orderId);
    await cancelFcmTrayCopy(action.orderId);

    // Show immediate confirmation notification on non-Android platforms
    // (on Android, Kotlin's NewOrderActionReceiver already displayed showActionFeedback)
    if (defaultTargetPlatform != TargetPlatform.android) {
      LocalNotificationService.instance.show(
        id: action.orderId.hashCode & 0x7fffffff,
        title: action.accepted ? 'Order Accepted ✅' : 'Order Rejected ❌',
        body: action.accepted
            ? 'Order #${action.orderId} accepted and confirmed.'
            : 'Order #${action.orderId} was rejected.',
        isNewOrder: false,
        fullScreenIntent: false,
      );
    }

    if (!mounted) return;
    ref.read(liveOrdersControllerProvider.notifier).refresh();
  }

  Future<void> _consumePendingOrderAction() async {
    final action = await NewOrderActionChannel.consumePendingAction();
    if (action == null) return;
    await _handleOrderAction(action);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(socketServiceProvider).connect();
      _wireGlobalOrderAlerts();
      ref.read(liveOrdersControllerProvider.notifier).refresh();
      unawaited(_consumePendingIncomingOrder());
      unawaited(_consumePendingOrderAction());
      unawaited(ref.read(fcmServiceProvider).saveTokenToServer());
      _checkLiveOrdersForPendingAlert();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authControllerProvider, (prev, next) {
      if (next is AuthAuthenticated) {
        ref.read(socketServiceProvider).connect();
        ref.read(fcmServiceProvider).initForegroundHandling();
        _wireGlobalOrderAlerts();
      }
    });

    ref.listen<AsyncValue<List<OrderModel>>>(liveOrdersControllerProvider, (prev, next) {
      if (next.hasValue) {
        final orders = next.value!;
        final active = _activeOutletIdNow;
        final unaccepted = orders.where((o) =>
            !_isOtherOutlet(o.restaurantId, active) &&
            !o.isCancelled &&
            !OrderResolutionTracker.isResolved(o.id) &&
            (o.orderStatus == 'created' ||
                o.orderStatus == 'placed' ||
                o.orderStatus == 'pending' ||
                o.restaurantBucket == 'new'));
        if (unaccepted.isNotEmpty) {
          final first = unaccepted.first;
          NewOrderActionChannel.startSound(first.id);
          _showIncomingDialogWithRetry(first.id);
        }
      }
    });

    final goRouter = ref.watch(goRouterProvider);
    final currentThemeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      // Name shown in the recent-apps switcher.
      title: 'Cravioo Restaurant',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: currentThemeMode,
      routerConfig: goRouter,
      builder: (context, child) {
        return Stack(
          children: [
            ?child,
            Consumer(
              builder: (context, ref, _) {
                final isOnline = ref.watch(networkControllerProvider);
                if (isOnline) return const SizedBox.shrink();
                return const NoNetworkOverlay();
              },
            ),
          ],
        );
      },
    );
  }
}

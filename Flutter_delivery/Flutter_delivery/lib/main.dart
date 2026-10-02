import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:food_user_application/core/error/result.dart';
import 'package:food_user_application/core/router/app_router.dart';
import 'package:food_user_application/core/services/fcm_service.dart';
import 'package:food_user_application/core/services/new_order_action_channel.dart';
import 'package:food_user_application/core/services/order_overlay_service.dart';
import 'package:food_user_application/core/services/referral_tracking_service.dart';
import 'package:food_user_application/core/theme/app_theme.dart';
import 'package:food_user_application/core/theme/theme_mode_provider.dart';
import 'package:food_user_application/features/orders/application/active_trip_visibility_controller.dart';
import 'package:food_user_application/features/orders/application/incoming_order_controller.dart';
import 'package:food_user_application/features/orders/application/orders_controller.dart';
import 'package:food_user_application/features/orders/application/orders_state.dart';
import 'package:food_user_application/core/services/order_resolution_tracker.dart';
import 'package:food_user_application/features/orders/application/pending_customer_rating_controller.dart';
import 'package:food_user_application/features/orders/data/models/delivery_order.dart';
import 'package:food_user_application/features/orders/data/orders_repository.dart';
import 'package:food_user_application/features/orders/presentation/screens/active_trip_screen.dart';
import 'package:food_user_application/features/orders/presentation/screens/incoming_order_screen.dart';
import 'package:food_user_application/core/presentation/widgets/no_network_overlay.dart';
import 'package:food_user_application/core/services/network_controller.dart';
import 'package:food_user_application/features/orders/presentation/screens/rate_customer_screen.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  runApp(const ProviderScope(child: FoodDeliveryApp()));
}

/// Entry point for the overlay bubble's separate Flutter engine — must stay
/// top-level in this file with this exact name/pragma, since the native
/// `OverlayService` resolves "overlayMain" from the app's default
/// entrypoint library (main.dart), not by scanning every file.
@pragma('vm:entry-point')
void overlayMain() {
  runApp(const OrderBubbleApp());
}

class FoodDeliveryApp extends ConsumerStatefulWidget {
  const FoodDeliveryApp({super.key});

  @override
  ConsumerState<FoodDeliveryApp> createState() => _FoodDeliveryAppState();
}

class _FoodDeliveryAppState extends ConsumerState<FoodDeliveryApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() async {
      NewOrderActionChannel.initialize();
      ref.read(fcmServiceProvider).initialize();
      unawaited(ref.read(fcmServiceProvider).registerToken());
      ReferralTrackingService.initialize();
      _consumePendingOverlayOrder();
      _consumePendingNativeOrderAction();
      _consumePendingIncomingOrder();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _consumePendingOverlayOrder();
      _consumePendingNativeOrderAction();
      _consumePendingIncomingOrder();
      // Re-checks full-screen-intent / overlay permissions on every resume,
      // not just cold start — catches a rider who dismissed the Settings
      // prompt the first time or toggled it manually while the app was
      // backgrounded (see FcmService.ensureAndroidAlertPermissions).
      ref.read(fcmServiceProvider).ensureAndroidAlertPermissions();

      // Re-register the push token on every resume, for the same reason.
      unawaited(ref.read(fcmServiceProvider).registerToken());

      // Refresh orders
      ref.read(ordersControllerProvider.notifier).refreshAll();
    }
  }

  Future<void> _consumePendingNativeOrderAction() async {
    final action = await NewOrderActionChannel.consumePendingAction();
    if (action == null || !mounted) return;
    if (action.accepted) {
      await ref.read(ordersControllerProvider.notifier).acceptOrder(action.orderId);
    } else {
      await ref.read(ordersControllerProvider.notifier).rejectOrder(action.orderId);
    }
  }

  Future<void> _consumePendingIncomingOrder() async {
    final orderId = await NewOrderActionChannel.consumePendingIncomingOrderId();
    if (orderId == null || orderId.isEmpty || !mounted) return;
    if (OrderResolutionTracker.isResolved(orderId)) return;
    final incomingController = ref.read(incomingOrderControllerProvider.notifier);
    final result = await ref.read(ordersRepositoryProvider).getOrderDetails(orderId);
    result.when(
      success: (order) {
        if (!OrderResolutionTracker.isResolved(order.id)) {
          incomingController.show(order);
        }
      },
      failure: (_) {
        incomingController.show(DeliveryOrder.fromRealtimePayload({'orderId': orderId}));
      },
    );
  }

  /// Surfaces an order that arrived as a home-screen bubble (app was
  /// backgrounded) into the same in-app IncomingOrderScreen shown for the
  /// foreground/socket path, and dismisses the bubble now that the app is
  /// in front.
  Future<void> _consumePendingOverlayOrder() async {
    await OrderOverlayService.close();
    final data = await OrderOverlayService.consumePendingOrder();
    if (data == null || !mounted) return;
    final order = DeliveryOrder.fromRealtimePayload(data);
    final incomingController = ref.read(
      incomingOrderControllerProvider.notifier,
    );

    incomingController.show(order);
    if (data['autoAccept'] == true) {
      incomingController.accept();
    }
  }

  @override
  Widget build(BuildContext context) {
    final goRouter = ref.watch(goRouterProvider);

    final themeMode = ref.watch(themeModeProvider);

    return ScreenUtilInit(
      designSize: const Size(375, 812), // Standard design size
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MaterialApp.router(
          title: 'Fodron Delivery',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeMode,
          routerConfig: goRouter,
          builder: (context, routedChild) {
            final isDarkMode = Theme.of(context).brightness == Brightness.dark;
            return AnnotatedRegion<SystemUiOverlayStyle>(
              value: isDarkMode
                  ? SystemUiOverlayStyle.light
                  : SystemUiOverlayStyle.dark,
              child: Stack(
                children: [
                  ?routedChild,
                  Consumer(
                    builder: (context, ref, _) {
                      final hasActiveOrder = ref.watch(
                        ordersControllerProvider.select(
                          (s) => s is OrdersLoaded && s.currentOrder != null,
                        ),
                      );
                      final showTrip = ref.watch(
                        activeTripVisibilityControllerProvider,
                      );
                      if (!hasActiveOrder || !showTrip) {
                        return const SizedBox.shrink();
                      }
                      return const ActiveTripScreen();
                    },
                  ),
                  Consumer(
                    builder: (context, ref, _) {
                      final incomingOrder = ref.watch(
                        incomingOrderControllerProvider,
                      );
                      if (incomingOrder == null) return const SizedBox.shrink();
                      return IncomingOrderScreen(
                        key: ValueKey(incomingOrder.id),
                        order: incomingOrder,
                      );
                    },
                  ),
                  Consumer(
                    builder: (context, ref, _) {
                      final pendingRating = ref.watch(
                        pendingCustomerRatingControllerProvider,
                      );
                      if (pendingRating == null) return const SizedBox.shrink();
                      return RateCustomerScreen(
                        key: ValueKey(pendingRating.id),
                        order: pendingRating,
                      );
                    },
                  ),
                  Consumer(
                    builder: (context, ref, _) {
                      final isOnline = ref.watch(networkControllerProvider);
                      if (isOnline) return const SizedBox.shrink();
                      return const NoNetworkOverlay();
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:food_user_application/core/router/app_router.dart';
import 'package:food_user_application/core/services/device_readiness_service.dart';
import 'package:food_user_application/core/services/fcm_service.dart';
import 'package:food_user_application/core/services/location_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:food_user_application/core/services/new_order_overlay_bridge.dart';
import 'package:food_user_application/core/services/referral_tracking_service.dart';
import 'package:food_user_application/core/theme/app_theme.dart';
import 'package:food_user_application/core/theme/theme_mode_provider.dart';
import 'package:food_user_application/features/orders/application/active_trip_visibility_controller.dart';
import 'package:food_user_application/features/orders/application/incoming_order_controller.dart';
import 'package:food_user_application/features/orders/application/orders_controller.dart';
import 'package:food_user_application/features/orders/application/orders_state.dart';
import 'package:food_user_application/features/orders/application/pending_customer_rating_controller.dart';
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

class FoodDeliveryApp extends ConsumerStatefulWidget {
  const FoodDeliveryApp({super.key});

  @override
  ConsumerState<FoodDeliveryApp> createState() => _FoodDeliveryAppState();
}

/// Bumped only if a future release needs to re-ask everyone.
const _permissionsAskedKey = 'permissions_requested_v1';

class _FoodDeliveryAppState extends ConsumerState<FoodDeliveryApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() async {
      ref.read(fcmServiceProvider).initialize();
      unawaited(ref.read(fcmServiceProvider).registerToken());
      ReferralTrackingService.initialize();
      await _requestFirstLaunchPermissions();
      _consumeOverlayHandoff();
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
      // Tapping the overlay resumes an already-running app rather than starting
      // it, so the handoff has to be picked up here as well as at launch.
      _consumeOverlayHandoff();
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

  /// Asks for everything the app needs, once, on the first launch after install.
  ///
  /// These used to be requested at the point of use — location when the rider
  /// tapped Go Online — which put a permission dialog in the middle of the one
  /// action that has to be instant. The flag is written BEFORE the prompts so a
  /// rider who dismisses one and kills the app is not re-prompted on every
  /// launch; anything still missing is surfaced by the readiness screen.
  Future<void> _requestFirstLaunchPermissions() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_permissionsAskedKey) == true) return;
    await prefs.setBool(_permissionsAskedKey, true);

    // Runtime dialogs first — they are quick and can be answered in place.
    await ref.read(fcmServiceProvider).ensureAndroidAlertPermissions();
    await ref.read(locationServiceProvider).ensurePermissions(requestExtras: true);

    // The two below throw the rider out to Settings screens, so they go last,
    // after everything that can be answered with a dialog.
    await DeviceReadinessService.fix('battery');
    if (!await NewOrderOverlayBridge.hasPermission()) {
      await NewOrderOverlayBridge.requestPermission();
    }
  }

  /// Picks up whatever the native overlay left for us: the order the rider
  /// tapped, and any they rejected while the app was not running.
  Future<void> _consumeOverlayHandoff() async {
    final controller = ref.read(incomingOrderControllerProvider.notifier);
    unawaited(controller.flushOverlayRejections());

    final handoff = await NewOrderOverlayBridge.consumeLaunchOrder();
    if (handoff == null || !mounted) return;
    await controller.showById(handoff.orderId, autoAccept: handoff.autoAccept);
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

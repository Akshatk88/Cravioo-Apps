import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:food_user_application/src/presentation/branding/app_colors.dart';
import 'package:food_user_application/src/presentation/branding/app_theme.dart';
import 'package:food_user_application/src/presentation/branding/locale_provider.dart';
import 'package:food_user_application/src/presentation/branding/theme_color_provider.dart';
import 'package:food_user_application/src/presentation/branding/theme_provider.dart';
import 'package:food_user_application/src/presentation/navigation/app_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../generated/l10n/app_localizations.dart';

import 'core/constants/app_constants.dart';
import 'di/push_providers.dart';
import 'platform/notifications/push_service.dart';
import 'presentation/auth/viewmodels/auth_viewmodel.dart';
import 'presentation/navigation/home_first_back_button_dispatcher.dart';
import 'di/location_providers.dart';

class FoodUserApplication extends ConsumerStatefulWidget {
  const FoodUserApplication({super.key});

  @override
  ConsumerState<FoodUserApplication> createState() => _FoodUserApplicationState();
}

class _FoodUserApplicationState extends ConsumerState<FoodUserApplication> {
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();
  final HomeFirstBackButtonDispatcher _backButtonDispatcher =
      HomeFirstBackButtonDispatcher();

  @override
  void initState() {
    super.initState();
    // Push listeners are wired once for the app's lifetime. Deep links are
    // handed to the router rather than the service touching navigation itself.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final pushService = ref.read(pushServiceProvider);
      await pushService.initialize(
        onDeepLink: _handleDeepLink,
        onPermanentlyDenied: _showPermissionExplanationDialog,
      );

      final user = ref.read(authViewModelProvider).value;
      await pushService.performAppStartCheck(
        isLoggedIn: user != null,
        user: user,
      );
    });
  }

  void _showPermissionExplanationDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Notifications Disabled'),
        content: const Text(
          'Notifications are required to receive real-time updates about your food orders (Order Accepted, Out for Delivery, Delivered, etc.). Please enable notifications in App Settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Later'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              openAppSettings();
            },
            child: const Text('Open Settings', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  /// Routes an order push to the tracking screen.
  void _handleDeepLink(PushDeepLink link) {
    final orderId = link.trackableOrderId;
    if (!link.isOrderEvent || orderId == null || orderId.isEmpty) return;
    // Route is declared as /orders/track/:id — a path param, not a query.
    ref.read(routerProvider).push('/orders/track/$orderId');
  }

  @override
  Widget build(BuildContext context) {
    final goRouter = ref.watch(routerProvider);

    // Register the device against the account on login; unregister on logout so
    // the next user of the device is not targeted.
    ref.listen(authViewModelProvider, (previous, next) {
      final was = previous?.value?.id;
      final now = next.value?.id;
      if (was == now && now != null) return;
      final push = ref.read(pushServiceProvider);
      if (now != null) {
        push.registerToken(user: next.value);
      } else if (previous?.value != null && now == null) {
        push.unregisterToken();
      }
    });

    // Rebuilds MaterialApp (and therefore every widget under it) whenever the
    // user picks a different app theme color — the single trigger that makes
    // the centralized ThemeColorNotifier's change reach the whole app.
    ref.watch(themeColorProvider);

    // Start resolving the user's coordinates at launch. The catalog
    // repositories read this synchronously (same pattern as the zone id), so
    // without warming it here the first restaurant fetch goes out with no
    // lat/lng and the backend returns no distanceInKm.
    ref.watch(userLatLngProvider);

    return ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      builder: (context, child) => MaterialApp.router(
        title: AppConstants.title,
        scaffoldMessengerKey: _scaffoldMessengerKey,
        debugShowCheckedModeBanner: false,
        // Tap anywhere that is not itself interactive to dismiss the keyboard.
        //
        // Sits here rather than per screen because it applies to every route:
        // fixing it screen by screen is how it ended up inconsistent, with the
        // keyboard trapped open over the field it was covering.
        //
        // translucent, not opaque: the detector joins hit-testing without
        // consuming the tap, so buttons and list items underneath still win the
        // gesture arena and fire normally. This only claims taps nothing else
        // wanted. FocusManager rather than FocusScope.of(context) because this
        // context sits above the Navigator and has no focus scope of its own.
        builder: (context, child) => GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: child,
        ),
        theme: buildLightTheme(),
        darkTheme: buildDarkTheme(),
        themeMode: ref.watch(themeProvider),
        locale: ref.watch(localeProvider),
        supportedLocales: supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        // Unpacked instead of `routerConfig: goRouter` so a custom
        // backButtonDispatcher can be supplied — MaterialApp.router asserts
        // routerConfig and backButtonDispatcher are mutually exclusive.
        routeInformationProvider: goRouter.routeInformationProvider,
        routeInformationParser: goRouter.routeInformationParser,
        routerDelegate: goRouter.routerDelegate,
        backButtonDispatcher: _backButtonDispatcher,
      ),
    );
  }
}


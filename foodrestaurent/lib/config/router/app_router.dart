import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:food_user_application/features/splash/presentation/views/splash_screen.dart';
import 'package:food_user_application/features/main_layout/presentation/views/main_layout_screen.dart';
import 'package:food_user_application/features/orders/presentation/views/orders_screen.dart';
import 'package:food_user_application/features/inventory/presentation/views/inventory_screen.dart';
import 'package:food_user_application/features/payouts/presentation/views/payouts_screen.dart';
import 'package:food_user_application/features/explore/presentation/views/explore_screen.dart';
import 'package:food_user_application/features/notifications/presentation/views/notifications_screen.dart';
import 'package:food_user_application/features/profile/presentation/views/restaurant_status_screen.dart';
import 'package:food_user_application/features/profile/presentation/views/outlet_timings_screen.dart';
import 'package:food_user_application/features/onboarding/presentation/views/onboarding_screen.dart';
import 'package:food_user_application/features/auth/presentation/views/login_screen.dart';
import 'package:food_user_application/features/explore/presentation/views/delivery_settings_screen.dart';
import 'package:food_user_application/features/orders/presentation/views/order_history_screen.dart';
import 'package:food_user_application/features/orders/presentation/views/order_details_screen.dart';
import 'package:food_user_application/features/explore/presentation/views/complaints_screen.dart';
import 'package:food_user_application/features/explore/presentation/views/support_screen.dart';
import 'package:food_user_application/features/explore/presentation/views/feedback_screen.dart';
import 'package:food_user_application/features/profile/presentation/views/outlet_info_screen.dart';
import 'package:food_user_application/features/inventory/presentation/views/menu_categories_screen.dart';
import 'package:food_user_application/features/explore/presentation/views/offers_screen.dart';
import 'package:food_user_application/features/explore/presentation/views/create_coupon_screen.dart';
import 'package:food_user_application/features/explore/presentation/views/zone_setup_screen.dart';
import 'package:food_user_application/features/profile/presentation/views/bank_details_screen.dart';
import 'package:food_user_application/features/auth/presentation/controllers/auth_controller.dart';
import 'package:food_user_application/features/auth/presentation/controllers/auth_state.dart';
import 'package:food_user_application/features/auth/presentation/views/application_status_screen.dart';
import 'package:food_user_application/features/registration/presentation/views/registration_screen.dart';
import 'package:food_user_application/features/registration/presentation/views/registration_success_screen.dart';
import 'package:food_user_application/features/dining/presentation/views/dining_bookings_screen.dart';
import 'package:food_user_application/features/dining/presentation/views/dining_management_screen.dart';
import 'package:food_user_application/features/dining/presentation/views/dining_request_screen.dart';
import 'package:food_user_application/features/dining/presentation/views/dining_slots_screen.dart';
import 'package:food_user_application/features/dining/presentation/views/dining_tables_screen.dart';

/// Notifies go_router to re-run [_redirect] on the current location whenever
/// auth state changes — without recreating the GoRouter instance itself
/// (which would reset the whole navigation stack back to initialLocation).
class _GoRouterRefreshNotifier extends ChangeNotifier {
  _GoRouterRefreshNotifier(Ref ref) {
    ref.listen(authControllerProvider, (previous, next) => notifyListeners());
  }
}

const _publicRoutes = {
  '/',
  '/onboarding',
  '/login',
  '/register',
  '/register/success',
  '/application-status',
};

/// Public so cross-cutting concerns (e.g. FCM notification-tap navigation)
/// can push routes without needing a `BuildContext` of their own.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _sectionANavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'sectionANav');
final GlobalKey<NavigatorState> _sectionBNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'sectionBNav');
final GlobalKey<NavigatorState> _sectionCNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'sectionCNav');
final GlobalKey<NavigatorState> _sectionDNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'sectionDNav');

final goRouterProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _GoRouterRefreshNotifier(ref);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final authState = ref.read(authControllerProvider);
      final location = state.matchedLocation;

      if (authState is AuthAuthenticated) {
        if (location == '/login' ||
            location == '/onboarding' ||
            location == '/') {
          return '/orders';
        }
        return null;
      }

      // Not authenticated (or still resolving at splash) — block deep links
      // straight into dashboard routes; the explicit navigation calls in
      // splash/login/registration handle the rest of the state machine.
      if (!_publicRoutes.contains(location)) {
        return '/login';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/register',
        builder: (context, state) {
          final extra = state.extra;
          String phone = '';
          String? token;
          if (extra is Map) {
            phone = extra['phone']?.toString() ?? '';
            token = extra['token']?.toString();
          } else if (extra is String) {
            phone = extra;
          }
          return RegistrationScreen(
            initialPhone: phone,
            initialToken: token,
          );
        },
      ),
      GoRoute(
        path: '/register/success',
        builder: (context, state) => const RegistrationSuccessScreen(),
      ),
      GoRoute(
        path: '/application-status',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return ApplicationStatusScreen(
            status: extra?['status']?.toString() ?? 'pending',
            message:
                extra?['message']?.toString() ??
                'Your restaurant registration is pending approval.',
          );
        },
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainLayoutScreen(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            navigatorKey: _sectionANavigatorKey,
            routes: [
              GoRoute(
                path: '/orders',
                builder: (context, state) => const OrdersScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _sectionBNavigatorKey,
            routes: [
              GoRoute(
                path: '/inventory',
                builder: (context, state) => const InventoryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _sectionCNavigatorKey,
            routes: [
              GoRoute(
                path: '/payouts',
                builder: (context, state) => PayoutsScreen(
                  initialTab: (state.extra as String?) ?? 'invoices',
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _sectionDNavigatorKey,
            routes: [
              GoRoute(
                path: '/explore',
                builder: (context, state) => const ExploreScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/restaurant-status',
        builder: (context, state) => const RestaurantStatusScreen(),
      ),
      GoRoute(
        path: '/outlet-timings',
        builder: (context, state) => const OutletTimingsScreen(),
      ),
      GoRoute(
        path: '/delivery-settings',
        builder: (context, state) => const DeliverySettingsScreen(),
      ),
      GoRoute(
        path: '/order-history',
        builder: (context, state) => const OrderHistoryScreen(),
      ),
      GoRoute(
        path: '/order-details/:id',
        builder: (context, state) =>
            OrderDetailsScreen(orderId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/complaints',
        builder: (context, state) => ComplaintsScreen(
          initialTab: (state.extra as String?) ?? 'complaints',
        ),
      ),
      GoRoute(
        path: '/support',
        builder: (context, state) => const SupportScreen(),
      ),
      GoRoute(
        path: '/feedback',
        builder: (context, state) => const FeedbackScreen(),
      ),
      GoRoute(
        path: '/outlet-info',
        builder: (context, state) => const OutletInfoScreen(),
      ),
      GoRoute(
        path: '/menu-categories',
        builder: (context, state) => const MenuCategoriesScreen(),
      ),
      GoRoute(
        path: '/offers',
        builder: (context, state) => const OffersScreen(),
      ),
      GoRoute(
        path: '/create-coupon',
        builder: (context, state) => const CreateCouponScreen(),
      ),
      GoRoute(
        path: '/zone-setup',
        builder: (context, state) => const ZoneSetupScreen(),
      ),
      GoRoute(
        path: '/bank-details',
        builder: (context, state) => const BankDetailsScreen(),
      ),
      GoRoute(
        path: '/dining',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const DiningManagementScreen(),
      ),
      GoRoute(
        path: '/dining-bookings',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const DiningBookingsScreen(),
      ),
      GoRoute(
        path: '/dining-request',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const DiningRequestScreen(),
      ),
      GoRoute(
        path: '/dining-tables',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const DiningTablesScreen(),
      ),
      GoRoute(
        path: '/dining-slots',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const DiningSlotsScreen(),
      ),
    ],
  );
});

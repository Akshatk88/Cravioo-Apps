import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_user_application/features/addons/presentation/controllers/addon_controller.dart';
import 'package:food_user_application/features/complaints/presentation/controllers/complaint_controller.dart';
import 'package:food_user_application/features/finance/presentation/controllers/finance_controller.dart';
import 'package:food_user_application/features/menu_categories/presentation/controllers/category_controller.dart';
import 'package:food_user_application/features/menu_items/presentation/controllers/menu_controller.dart';
import 'package:food_user_application/features/offers/presentation/controllers/offer_controller.dart';
import 'package:food_user_application/features/orders/presentation/controllers/live_orders_controller.dart';
import 'package:food_user_application/features/orders/presentation/controllers/order_history_controller.dart';
import 'package:food_user_application/features/restaurant_profile/presentation/controllers/restaurant_profile_controller.dart';
import 'package:food_user_application/features/support/presentation/controllers/support_controller.dart';
import 'package:food_user_application/features/zones/data/zone_repository.dart';

/// Every provider listed here caches data scoped to *one logged-in
/// restaurant*. None of them are `.autoDispose`, so Riverpod keeps them
/// alive for the whole app process — without this explicit reset, logging
/// out and back in as a different restaurant (without a full app restart)
/// would leave the previous restaurant's data on screen until something
/// happened to trigger a manual pull-to-refresh.
///
/// Call this whenever the authenticated identity changes: right before a
/// fresh login settles into [AuthAuthenticated], and on every logout path
/// (explicit logout and forced session-expiry alike).
void resetSessionScopedProviders(Ref ref) {
  ref.invalidate(restaurantProfileControllerProvider);
  ref.invalidate(categoryControllerProvider);
  ref.invalidate(menuControllerProvider);
  ref.invalidate(addonControllerProvider);
  ref.invalidate(offerControllerProvider);
  ref.invalidate(complaintControllerProvider);
  ref.invalidate(supportControllerProvider);
  ref.invalidate(financeControllerProvider);
  ref.invalidate(withdrawalsControllerProvider);
  ref.invalidate(subscriptionInvoicesControllerProvider);
  ref.invalidate(liveOrdersControllerProvider);
  ref.invalidate(orderHistoryControllerProvider);
  ref.invalidate(activeZonesProvider);
}

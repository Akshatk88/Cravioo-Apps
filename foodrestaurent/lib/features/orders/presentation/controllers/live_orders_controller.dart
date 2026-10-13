import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_user_application/core/providers/core_providers.dart';
import 'package:food_user_application/core/services/fcm_service.dart';
import 'package:food_user_application/core/services/new_order_action_channel.dart';
import 'package:food_user_application/core/services/order_resolution_tracker.dart';
import 'package:food_user_application/core/services/socket_service.dart';
import 'package:food_user_application/core/services/order_overlay_service.dart';
import 'package:food_user_application/features/orders/data/order_repository.dart';
import 'package:food_user_application/features/orders/domain/order_model.dart';
import 'package:food_user_application/features/outlets/presentation/controllers/outlets_controller.dart';

/// Backs the main Orders tab: one list of current orders, bucketed
/// client-side into the 7 status tabs (see [OrderModel.restaurantBucket]),
/// kept fresh by the `new_order` / `order_status_update` socket events.
///
/// Socket.IO never replays events missed while disconnected (app
/// backgrounded, brief network drop, etc.), so a status change like a
/// cancellation during that window would otherwise sit stale until a manual
/// pull-to-refresh — also refresh on reconnect and on app resume to close
/// that gap.
class LiveOrdersController extends AsyncNotifier<List<OrderModel>> {
  bool _socketWired = false;
  AppLifecycleListener? _lifecycleListener;

  @override
  Future<List<OrderModel>> build() async {
    // Riverpod re-runs build() on this SAME notifier instance after an
    // invalidate (login reset, outlet switch, scope toggle), so everything set
    // up here must be torn down and rebuilt each time. Keeping the old listener
    // (`??=`) or the old "already wired" flag left a disposed AppLifecycleListener
    // behind and a socket with its handlers removed.
    _lifecycleListener = AppLifecycleListener(
      onResume: () {
        // The restaurant is back in the app, so the floating alert has done its job.
        OrderOverlayService.close();
        refresh();
      },
    );
    ref.onDispose(() {
      _lifecycleListener?.dispose();
      _lifecycleListener = null;
      _socketWired = false;
    });
    await _wireSocket();
    return _fetch();
  }

  /// Read, not watched: a rebuild here would run the onDispose below and drop
  /// the socket handlers. The scope toggle invalidates this provider instead.
  Future<List<OrderModel>> _fetch() async {
    // The app builds this provider at launch, before anyone is signed in. A fetch
    // then is a guaranteed 401 ("Authentication token missing") that only burns
    // the server's per-IP rate limit and, on a 401, can wipe the session that a
    // login is creating at that very moment. Nothing to list when signed out.
    final token = await ref.read(tokenStorageProvider).accessToken;
    if (token == null || token.isEmpty) return const <OrderModel>[];
    final allOutlets = ref.read(ordersScopeProvider) == kOrdersScopeAll;
    return ref.read(orderRepositoryProvider).listCurrent(allOutlets: allOutlets);
  }

  Future<void> _wireSocket() async {
    if (_socketWired) return;
    _socketWired = true;
    final socket = ref.read(socketServiceProvider);
    await socket.connect();

    void onOrderEvent(dynamic _) => refresh();

    socket.on('new_order', onOrderEvent);
    socket.on('new_order_available', onOrderEvent);
    socket.on('order_status_update', onOrderEvent);
    socket.on('order_cancelled', onOrderEvent);
    socket.on('cancel_order', onOrderEvent);
    socket.on('order_accepted', onOrderEvent);
    socket.on('order_rejected', onOrderEvent);
    socket.on('connect', onOrderEvent);
    ref.onDispose(() {
      socket.off('new_order');
      socket.off('new_order_available');
      socket.off('order_status_update');
      socket.off('order_cancelled');
      socket.off('cancel_order');
      socket.off('order_accepted');
      socket.off('order_rejected');
      socket.off('connect');
    });
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(
      _fetch,
    );
  }

  Future<void> updateStatus(
    String orderId,
    String orderStatus, {
    String? note,
  }) async {
    OrderResolutionTracker.markResolved(orderId);
    await NewOrderActionChannel.stopSound(orderId);
    await NewOrderActionChannel.dismiss(orderId);
    await cancelFcmTrayCopy(orderId);
    await ref
        .read(orderRepositoryProvider)
        .updateStatus(orderId, orderStatus, note: note);
    if (orderStatus == 'ready_for_pickup') {
      try {
        await ref.read(orderRepositoryProvider).resendNotification(orderId);
      } catch (_) {}
    }
    await refresh();
  }

  Future<void> resendNotification(String orderId) async {
    await ref.read(orderRepositoryProvider).resendNotification(orderId);
  }
}

final liveOrdersControllerProvider =
    AsyncNotifierProvider<LiveOrdersController, List<OrderModel>>(
      LiveOrdersController.new,
    );

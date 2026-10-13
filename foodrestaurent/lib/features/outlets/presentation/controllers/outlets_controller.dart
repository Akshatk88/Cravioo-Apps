import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:food_user_application/features/outlets/data/outlet_repository.dart';

/// Every outlet under the signed-in owner account, plus which one this
/// session is currently acting as.
class OutletsController extends AsyncNotifier<OutletList> {
  @override
  Future<OutletList> build() => ref.read(outletRepositoryProvider).list();

  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () => ref.read(outletRepositoryProvider).list(),
    );
  }

  /// Returns what the server did with each name so the UI can report partial
  /// failures (e.g. a duplicate outlet name) without losing the ones that worked.
  Future<AddOutletsResult> addOutlets(List<String> names) async {
    final result = await ref.read(outletRepositoryProvider).add(names);
    await refresh();
    return result;
  }
}

final outletsControllerProvider =
    AsyncNotifierProvider<OutletsController, OutletList>(OutletsController.new);

/// Which orders the Orders tab lists: just the active outlet, or every outlet
/// of the owner. Mirrors the web dashboard's "This outlet / All outlets" toggle.
const kOrdersScopeOutlet = 'outlet';
const kOrdersScopeAll = 'all';
const _ordersScopeKey = 'restaurant_orders_scope';

class OrdersScopeController extends Notifier<String> {
  @override
  String build() {
    _restore();
    return kOrdersScopeOutlet;
  }

  /// True once the restaurant has picked a view themselves; until then the
  /// default follows how many outlets they have.
  bool _hasChosen = false;

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_ordersScopeKey);
      if (saved != null) {
        _hasChosen = true;
        if (saved != state) state = saved;
      }
    } catch (_) {
      // Storage unavailable: fall back to the per-outlet view.
    }
  }

  /// With several outlets, an order placed at ANY of them has to show up here as
  /// it arrives — a list limited to the active outlet hides every sibling's order,
  /// which looks exactly like the request never came. So multi-outlet owners start
  /// on "All outlets"; a choice they make themselves is never overridden. Returns
  /// true when the view changed, so the caller can reload the list.
  bool applyDefault({required bool hasMultipleOutlets}) {
    if (_hasChosen || !hasMultipleOutlets || state == kOrdersScopeAll) {
      return false;
    }
    state = kOrdersScopeAll;
    return true;
  }

  Future<void> set(String scope) async {
    final next = scope == kOrdersScopeAll ? kOrdersScopeAll : kOrdersScopeOutlet;
    _hasChosen = true;
    if (next == state) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_ordersScopeKey, next);
      } catch (_) {}
      return;
    }
    state = next;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_ordersScopeKey, next);
    } catch (_) {}
  }
}

final ordersScopeProvider = NotifierProvider<OrdersScopeController, String>(
  OrdersScopeController.new,
);

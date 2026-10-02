import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_user_application/features/orders/data/order_repository.dart';

class OrderHistoryController extends AsyncNotifier<OrderListPage> {
  String _search = '';

  @override
  Future<OrderListPage> build() {
    return ref.read(orderRepositoryProvider).list(search: _search);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(orderRepositoryProvider).list(search: _search),
    );
  }

  Future<void> search(String query) async {
    _search = query;
    await refresh();
  }
}

final orderHistoryControllerProvider =
    AsyncNotifierProvider<OrderHistoryController, OrderListPage>(
      OrderHistoryController.new,
    );

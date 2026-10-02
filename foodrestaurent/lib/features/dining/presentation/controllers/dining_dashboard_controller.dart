import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_user_application/core/services/socket_service.dart';
import 'package:food_user_application/features/dining/data/dining_repository.dart';
import 'package:food_user_application/features/dining/domain/dining_dashboard_model.dart';

class DiningDashboardController extends AsyncNotifier<DiningDashboardModel> {
  bool _socketWired = false;
  AppLifecycleListener? _lifecycleListener;

  @override
  Future<DiningDashboardModel> build() async {
    await _wireSocket();
    _lifecycleListener ??= AppLifecycleListener(onResume: refresh);
    ref.onDispose(() => _lifecycleListener?.dispose());
    return _fetch();
  }

  Future<void> _wireSocket() async {
    if (_socketWired) return;
    _socketWired = true;
    final socket = ref.read(socketServiceProvider);
    await socket.connect();
    socket.on('new_dining_booking', (_) => refresh());
    socket.on('dining_booking_updated', (_) => refresh());
  }

  Future<DiningDashboardModel> _fetch() async {
    final repo = ref.read(diningRepositoryProvider);
    return repo.getDashboard();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetch());
  }

  Future<bool> toggleOnline(bool isOnline) async {
    try {
      final repo = ref.read(diningRepositoryProvider);
      final updatedProfile = await repo.updateSettings({'isOnline': isOnline});
      final current = state.value;
      if (current != null) {
        state = AsyncValue.data(current.copyWith(profile: updatedProfile));
      } else {
        await refresh();
      }
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> updateSettings({
    bool? autoConfirm,
    int? bookingWindowDays,
    int? slotDurationMins,
    int? maxGuestsPerBooking,
    int? minAdvanceMins,
  }) async {
    try {
      final repo = ref.read(diningRepositoryProvider);
      final body = <String, dynamic>{};
      if (autoConfirm != null) body['autoConfirm'] = autoConfirm;
      if (bookingWindowDays != null) body['bookingWindowDays'] = bookingWindowDays;
      if (slotDurationMins != null) body['slotDurationMins'] = slotDurationMins;
      if (maxGuestsPerBooking != null) body['maxGuestsPerBooking'] = maxGuestsPerBooking;
      if (minAdvanceMins != null) body['minAdvanceMins'] = minAdvanceMins;

      final updatedProfile = await repo.updateSettings(body);
      final current = state.value;
      if (current != null) {
        state = AsyncValue.data(current.copyWith(profile: updatedProfile));
      } else {
        await refresh();
      }
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final diningDashboardControllerProvider =
    AsyncNotifierProvider<DiningDashboardController, DiningDashboardModel>(
  DiningDashboardController.new,
);

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_user_application/core/services/socket_service.dart';
import 'package:food_user_application/features/dining/data/dining_repository.dart';
import 'package:food_user_application/features/dining/domain/dining_booking_model.dart';

/// Holds bookings per status tab so each tab has its own complete dataset
/// instead of client-side filtering a single limited fetch.
class DiningBookingsState {
  final List<DiningBookingModel> pending;
  final List<DiningBookingModel> confirmed;
  final List<DiningBookingModel> seated;
  final List<DiningBookingModel> history;
  final bool isLoading;
  final String? error;

  const DiningBookingsState({
    this.pending = const [],
    this.confirmed = const [],
    this.seated = const [],
    this.history = const [],
    this.isLoading = false,
    this.error,
  });
}

class DiningController extends AsyncNotifier<DiningBookingsState> {
  bool _socketWired = false;
  AppLifecycleListener? _lifecycleListener;

  @override
  Future<DiningBookingsState> build() async {
    await _wireSocket();
    _lifecycleListener ??= AppLifecycleListener(onResume: refresh);
    ref.onDispose(() => _lifecycleListener?.dispose());
    return _fetchAll();
  }

  Future<void> _wireSocket() async {
    if (_socketWired) return;
    _socketWired = true;
    final socket = ref.read(socketServiceProvider);
    await socket.connect();
    socket.on('new_dining_booking', (_) => refresh());
    socket.on('dining_booking_updated', (_) => refresh());
  }

  Future<DiningBookingsState> _fetchAll() async {
    final repo = ref.read(diningRepositoryProvider);
    try {
      final results = await Future.wait([
        repo.listBookings(status: 'pending'),
        repo.listBookings(status: 'confirmed'),
        repo.listBookings(status: 'seated'),
        repo.listBookings(status: 'all'),
      ]);

      var pending = results[0];
      var confirmed = results[1];
      var seated = results[2];
      final all = results[3];

      // Fallback: if bucket fetch was empty but 'all' has items with that status, use them
      if (pending.isEmpty && all.any((b) => b.isPending)) {
        pending = all.where((b) => b.isPending).toList();
      }
      if (confirmed.isEmpty && all.any((b) => b.isConfirmed)) {
        confirmed = all.where((b) => b.isConfirmed).toList();
      }
      if (seated.isEmpty && all.any((b) => b.isSeated)) {
        seated = all.where((b) => b.isSeated).toList();
      }

      // History is all past/inactive bookings
      final history = all.where((b) =>
        b.isCompleted || b.isCancelled || b.isRejected || b.isNoShow
      ).toList();

      return DiningBookingsState(
        pending: pending,
        confirmed: confirmed,
        seated: seated,
        history: history,
      );
    } catch (_) {
      try {
        final all = await repo.listBookings(status: 'all');
        return DiningBookingsState(
          pending: all.where((b) => b.isPending).toList(),
          confirmed: all.where((b) => b.isConfirmed).toList(),
          seated: all.where((b) => b.isSeated).toList(),
          history: all.where((b) => b.isCompleted || b.isCancelled || b.isRejected || b.isNoShow).toList(),
        );
      } catch (_) {
        return const DiningBookingsState();
      }
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchAll());
  }

  Future<bool> updateStatus(
    String bookingId,
    String newStatus, {
    String? note,
    List<String>? tableIds,
  }) async {
    try {
      final safeNote = (note != null && note.isNotEmpty)
          ? note
          : (newStatus == 'rejected'
              ? 'Restaurant unavailable / fully booked'
              : (newStatus == 'cancelled' ? 'Cancelled by restaurant' : null));
      await ref
          .read(diningRepositoryProvider)
          .updateBookingStatus(
            bookingId,
            newStatus,
            note: safeNote,
            tableIds: tableIds,
          );
      await refresh();
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final diningControllerProvider =
    AsyncNotifierProvider<DiningController, DiningBookingsState>(
  DiningController.new,
);

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/datasources/dining_remote_datasource.dart';
import '../../../data/models/dining_model.dart';
import '../../../di/dining_providers.dart';
import 'dining_bookings_state.dart';

final diningBookingsViewModelProvider =
    NotifierProvider<DiningBookingsViewModel, DiningBookingsState>(() {
  return DiningBookingsViewModel();
});

/// Dedicated provider for the latest upcoming active booking (for DiningScreen banner)
final latestUpcomingDiningBookingProvider = Provider<DiningUserBookingModel?>((ref) {
  final state = ref.watch(diningBookingsViewModelProvider);
  return state.latestUpcomingBooking;
});

class DiningBookingsViewModel extends Notifier<DiningBookingsState> {
  late final DiningRemoteDataSource _dataSource;

  @override
  DiningBookingsState build() {
    _dataSource = ref.watch(diningRemoteDataSourceProvider);
    Future.microtask(() => loadBookings());
    return const DiningBookingsState(isLoading: true);
  }

  Future<void> loadBookings() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final list = await _dataSource.getMyBookings();
      state = state.copyWith(
        isLoading: false,
        bookings: list,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load reservations: $e',
      );
    }
  }

  void addBooking(DiningUserBookingModel booking) {
    final updated = [booking, ...state.bookings.where((b) => b.id != booking.id)];
    state = state.copyWith(bookings: updated);
  }

  void setFilter(DiningBookingsFilter filter) {
    state = state.copyWith(filter: filter);
  }

  Future<bool> cancelBooking(String bookingId, String reason) async {
    state = state.copyWith(isCancelling: true);
    try {
      final ok = await _dataSource.cancelBooking(bookingId, reason: reason);
      if (ok) {
        await loadBookings();
      }
      state = state.copyWith(isCancelling: false);
      return ok;
    } catch (e) {
      state = state.copyWith(
        isCancelling: false,
        errorMessage: 'Failed to cancel reservation: $e',
      );
      return false;
    }
  }

  Future<bool> rateBooking(String bookingId, int rating, String review) async {
    try {
      final ok = await _dataSource.rateBooking(bookingId, rating: rating, review: review);
      if (ok) {
        await loadBookings();
      }
      return ok;
    } catch (e) {
      return false;
    }
  }
}

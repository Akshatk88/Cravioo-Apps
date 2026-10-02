import '../../../data/models/dining_model.dart';

enum DiningBookingsFilter {
  all,
  upcoming,
  completed,
  cancelled,
}

class DiningBookingsState {
  final bool isLoading;
  final String? errorMessage;
  final List<DiningUserBookingModel> bookings;
  final DiningBookingsFilter filter;
  final bool isCancelling;
  final String? actionMessage;

  const DiningBookingsState({
    this.isLoading = false,
    this.errorMessage,
    this.bookings = const [],
    this.filter = DiningBookingsFilter.all,
    this.isCancelling = false,
    this.actionMessage,
  });

  List<DiningUserBookingModel> get filteredBookings {
    switch (filter) {
      case DiningBookingsFilter.all:
        return bookings;
      case DiningBookingsFilter.upcoming:
        return bookings.where((b) => b.isUpcoming).toList();
      case DiningBookingsFilter.completed:
        return bookings.where((b) => b.isCompleted).toList();
      case DiningBookingsFilter.cancelled:
        return bookings.where((b) => b.isCancelled).toList();
    }
  }

  int get upcomingCount => bookings.where((b) => b.isUpcoming).length;
  int get completedCount => bookings.where((b) => b.isCompleted).length;
  int get cancelledCount => bookings.where((b) => b.isCancelled).length;
  int get allCount => bookings.length;

  DiningUserBookingModel? get latestUpcomingBooking {
    final upcoming = bookings.where((b) => b.isUpcoming).toList();
    if (upcoming.isEmpty) return null;
    return upcoming.first;
  }

  DiningBookingsState copyWith({
    bool? isLoading,
    String? errorMessage,
    List<DiningUserBookingModel>? bookings,
    DiningBookingsFilter? filter,
    bool? isCancelling,
    String? actionMessage,
    bool clearError = false,
  }) {
    return DiningBookingsState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      bookings: bookings ?? this.bookings,
      filter: filter ?? this.filter,
      isCancelling: isCancelling ?? this.isCancelling,
      actionMessage: actionMessage,
    );
  }
}

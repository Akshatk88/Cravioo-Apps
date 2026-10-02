import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/datasources/dining_remote_datasource.dart';
import '../../../di/dining_providers.dart';
import '../../../di/location_providers.dart';
import 'dining_state.dart';

final diningViewModelProvider =
    NotifierProvider<DiningViewModel, DiningState>(() {
  return DiningViewModel();
});

class DiningViewModel extends Notifier<DiningState> {
  late final DiningRemoteDataSource _dataSource;

  @override
  DiningState build() {
    _dataSource = ref.watch(diningRemoteDataSourceProvider);
    Future.microtask(() => loadInitialData());
    return const DiningState(isLoading: true);
  }

  Future<void> loadInitialData() async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final loc = ref.read(userLatLngProvider).value;
      final categoriesFuture = _dataSource.getCategories();
      final bannersFuture = _dataSource.getBanners();
      final restaurantsFuture = _dataSource.getRestaurants(
        lat: loc?.lat,
        lng: loc?.lng,
      );

      final results = await Future.wait([
        categoriesFuture,
        bannersFuture,
        restaurantsFuture,
      ]);

      state = state.copyWith(
        isLoading: false,
        categories: results[0] as dynamic,
        banners: results[1] as dynamic,
        restaurants: results[2] as dynamic,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load dining options: $e',
      );
    }
  }

  Future<void> selectCategory(String categoryId) async {
    if (state.selectedCategoryId == categoryId) {
      state = state.copyWith(selectedCategoryId: 'all');
    } else {
      state = state.copyWith(selectedCategoryId: categoryId);
    }
    await _filterRestaurants();
  }

  Future<void> setSortBy(String sortBy) async {
    state = state.copyWith(sortBy: sortBy);
    await _filterRestaurants();
  }

  Future<void> setSearchQuery(String query) async {
    state = state.copyWith(searchQuery: query);
    await _filterRestaurants();
  }

  Future<void> _filterRestaurants() async {
    try {
      final loc = ref.read(userLatLngProvider).value;
      final list = await _dataSource.getRestaurants(
        categoryId: state.selectedCategoryId == 'all' ? null : state.selectedCategoryId,
        search: state.searchQuery.isEmpty ? null : state.searchQuery,
        sortBy: state.sortBy,
        lat: loc?.lat,
        lng: loc?.lng,
      );
      state = state.copyWith(restaurants: list);
    } catch (_) {}
  }

  /// Fetch real availability (slots) for a restaurant on a given date.
  Future<void> loadAvailability({
    required String restaurantId,
    required String date,
    int guests = 2,
  }) async {
    state = state.copyWith(
      isLoadingAvailability: true,
      clearAvailability: true,
    );
    try {
      final availability = await _dataSource.getAvailability(
        restaurantId: restaurantId,
        date: date,
        guests: guests,
      );
      state = state.copyWith(
        isLoadingAvailability: false,
        availability: availability,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingAvailability: false,
        availabilityError: e.toString(),
      );
    }
  }

  /// Book a table with all required fields the backend expects.
  Future<DiningBookingResult> bookTable({
    required String restaurantId,
    required String date,
    required String slotStart,
    required int guests,
    required String guestName,
    required String guestPhone,
    String? occasion,
    String? specialRequest,
    String paymentMethod = 'free',
    String? transactionId,
  }) async {
    state = state.copyWith(isBooking: true);
    try {
      final result = await _dataSource.bookTable(
        restaurantId: restaurantId,
        date: date,
        slotStart: slotStart,
        guests: guests,
        guestName: guestName,
        guestPhone: guestPhone,
        occasion: occasion,
        specialRequest: specialRequest,
        paymentMethod: paymentMethod,
        transactionId: transactionId,
      );
      state = state.copyWith(isBooking: false);
      return result;
    } catch (e) {
      state = state.copyWith(isBooking: false);
      return DiningBookingResult(
        success: false,
        message: 'Booking failed: $e',
        errorMessage: e.toString(),
      );
    }
  }
}

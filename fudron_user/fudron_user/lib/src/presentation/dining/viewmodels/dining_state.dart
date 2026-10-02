import '../../../data/models/dining_model.dart';

class DiningState {
  final bool isLoading;
  final String? errorMessage;
  final List<DiningCategoryModel> categories;
  final List<DiningBannerModel> banners;
  final List<DiningRestaurantModel> restaurants;
  final String selectedCategoryId;
  final String searchQuery;
  final String sortBy;
  final bool isBooking;

  // Availability state for the booking sheet
  final bool isLoadingAvailability;
  final DiningAvailabilityModel? availability;
  final String? availabilityError;

  const DiningState({
    this.isLoading = false,
    this.errorMessage,
    this.categories = const [],
    this.banners = const [],
    this.restaurants = const [],
    this.selectedCategoryId = 'all',
    this.searchQuery = '',
    this.sortBy = 'popular',
    this.isBooking = false,
    this.isLoadingAvailability = false,
    this.availability,
    this.availabilityError,
  });

  DiningState copyWith({
    bool? isLoading,
    String? errorMessage,
    List<DiningCategoryModel>? categories,
    List<DiningBannerModel>? banners,
    List<DiningRestaurantModel>? restaurants,
    String? selectedCategoryId,
    String? searchQuery,
    String? sortBy,
    bool? isBooking,
    bool? isLoadingAvailability,
    DiningAvailabilityModel? availability,
    String? availabilityError,
    bool clearAvailability = false,
  }) {
    return DiningState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      categories: categories ?? this.categories,
      banners: banners ?? this.banners,
      restaurants: restaurants ?? this.restaurants,
      selectedCategoryId: selectedCategoryId ?? this.selectedCategoryId,
      searchQuery: searchQuery ?? this.searchQuery,
      sortBy: sortBy ?? this.sortBy,
      isBooking: isBooking ?? this.isBooking,
      isLoadingAvailability: isLoadingAvailability ?? this.isLoadingAvailability,
      availability: clearAvailability ? null : (availability ?? this.availability),
      availabilityError: clearAvailability ? null : (availabilityError ?? this.availabilityError),
    );
  }
}

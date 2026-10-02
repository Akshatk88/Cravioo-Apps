import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/datasources/catalog_remote_datasource.dart';
import '../../../data/models/restaurant_model.dart';
import '../../../di/catalog_providers.dart';
import '../../../di/location_providers.dart';
import '../../address/viewmodels/address_viewmodel.dart';
import '../../../platform/location/location_service.dart';

class NearYouState {
  final AsyncValue<List<RestaurantModel>> restaurants;
  final UserLocationResult? location;

  const NearYouState({
    required this.restaurants,
    this.location,
  });

  NearYouState copyWith({
    AsyncValue<List<RestaurantModel>>? restaurants,
    UserLocationResult? location,
  }) {
    return NearYouState(
      restaurants: restaurants ?? this.restaurants,
      location: location ?? this.location,
    );
  }
}

final nearYouViewModelProvider = NotifierProvider<NearYouViewModel, NearYouState>(() {
  return NearYouViewModel();
});

class NearYouViewModel extends Notifier<NearYouState> {
  late final LocationService _locationService;
  late final CatalogRemoteDataSource _catalogDataSource;

  @override
  NearYouState build() {
    _locationService = ref.watch(locationServiceProvider);
    _catalogDataSource = ref.watch(catalogRemoteDataSourceProvider);
    Future.microtask(() => loadNearbyRestaurants());
    return const NearYouState(restaurants: AsyncValue.loading());
  }

  Future<void> loadNearbyRestaurants({bool isRefresh = false}) async {
    if (!isRefresh) {
      state = state.copyWith(restaurants: const AsyncValue.loading());
    }

    try {
      // 1. Fetch current GPS location
      final locResult = await _locationService.getCurrentLocationAndAddress();
      double? lat = locResult.latitude;
      double? lng = locResult.longitude;

      // 2. Without coordinates the backend cannot measure distance and omits
      //    distanceInKm entirely, so every card reads 0 km. GPS legitimately
      //    fails — permission refused, location off, fix timed out — so fall
      //    back to the delivery address before giving up on distance. For a
      //    delivery app that address is arguably the better origin anyway:
      //    it is where the food is actually going.
      if (lat == null || lng == null) {
        final addresses = ref.read(addressViewModelProvider.notifier);
        // AddressViewModel.build() returns an empty list and fetches in the
        // background, and this runs at startup — so without awaiting the load
        // defaultAddress is always null here and the fallback never fires.
        if (ref.read(addressViewModelProvider).isEmpty) {
          await addresses.load();
        }
        final saved = addresses.defaultAddress;
        if (saved?.latitude != null && saved?.longitude != null) {
          lat = saved!.latitude;
          lng = saved.longitude;
        }
      }

      // 3. Query backend API with real latitude & longitude
      final list = await _catalogDataSource.getRestaurants(
        lat: lat,
        lng: lng,
        limit: 50,
      );

      // Filter list to valid restaurants
      state = state.copyWith(
        restaurants: AsyncValue.data(list),
        location: locResult,
      );
    } catch (e, st) {
      state = state.copyWith(
        restaurants: AsyncValue.error(e, st),
      );
    }
  }
}

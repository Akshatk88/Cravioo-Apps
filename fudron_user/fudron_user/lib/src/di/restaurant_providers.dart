import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repository/restaurant_repository_impl.dart';
import '../domain/repository/restaurant_repository.dart';
import '../domain/service/restaurant_service.dart';
import '../presentation/home/viewmodels/zone_viewmodel.dart';
import 'catalog_providers.dart';
import 'location_providers.dart';

final restaurantRepositoryProvider = Provider<RestaurantRepository>((ref) {
  return RestaurantRepositoryImpl(
    ref.watch(catalogRemoteDataSourceProvider),
    // Read (not watch) through a callback so a zone arriving later is picked up
    // on the next call without rebuilding the repository mid-flight.
    () => ref.read(currentZoneIdProvider),
    // Same read-through-a-callback reasoning: the fix resolves asynchronously,
    // so this picks it up on the next call rather than caching a null.
    () => ref.read(userLatLngProvider).value,
  );
});

final restaurantServiceProvider = Provider<RestaurantService>((ref) {
  return RestaurantService(ref.watch(restaurantRepositoryProvider));
});

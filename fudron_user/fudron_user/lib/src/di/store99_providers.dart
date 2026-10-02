import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repository/store99_repository_impl.dart';
import '../domain/repository/store99_repository.dart';
import '../domain/service/store99_service.dart';
import '../presentation/home/viewmodels/zone_viewmodel.dart';
import 'catalog_providers.dart';
import 'location_providers.dart';

final store99RepositoryProvider = Provider<Store99Repository>((ref) {
  return Store99RepositoryImpl(
    ref.watch(catalogRemoteDataSourceProvider),
    () => ref.read(currentZoneIdProvider),
    // Same read-through-a-callback reasoning: the fix resolves asynchronously,
    // so this picks it up on the next call rather than caching a null.
    () => ref.read(userLatLngProvider).value,
  );
});

final store99ServiceProvider = Provider<Store99Service>((ref) {
  return Store99Service(ref.watch(store99RepositoryProvider));
});

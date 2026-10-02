import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/datasources/favorites_remote_datasource.dart';
import '../data/repository/favorites_repository_impl.dart';
import '../domain/repository/favorites_repository.dart';
import 'network_providers.dart';

final favoritesRemoteDataSourceProvider = Provider<FavoritesRemoteDataSource>((ref) {
  return FavoritesRemoteDataSource(ref.watch(apiClientProvider));
});

final favoritesRepositoryProvider = Provider<FavoritesRepository>((ref) {
  final remote = ref.watch(favoritesRemoteDataSourceProvider);
  return FavoritesRepositoryImpl(remote);
});


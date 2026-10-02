import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/datasources/search_local_datasource.dart';
import '../data/datasources/search_remote_datasource.dart';
import '../data/repository/search_repository_impl.dart';
import '../domain/repository/search_repository.dart';
import '../domain/service/search_service.dart';
import '../platform/speech/speech_service.dart';
import 'catalog_providers.dart';
import '../presentation/home/viewmodels/zone_viewmodel.dart';

final speechServiceProvider = Provider<SpeechService>((ref) {
  return SpeechService();
});

final searchLocalDataSourceProvider = Provider<SearchLocalDataSource>((ref) {
  return SearchLocalDataSourceImpl();
});

final searchRemoteDataSourceProvider = Provider<SearchRemoteDataSource>((ref) {
  return SearchRemoteDataSourceImpl(
    ref.watch(catalogRemoteDataSourceProvider),
    () => ref.read(currentZoneIdProvider),
  );
});

final searchRepositoryProvider = Provider<SearchRepository>((ref) {
  final remote = ref.watch(searchRemoteDataSourceProvider);
  final local = ref.watch(searchLocalDataSourceProvider);
  return SearchRepositoryImpl(
    remoteDataSource: remote,
    localDataSource: local,
  );
});

final searchServiceProvider = Provider<SearchService>((ref) {
  final repository = ref.watch(searchRepositoryProvider);
  return SearchService(repository);
});

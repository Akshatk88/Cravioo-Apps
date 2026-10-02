import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/datasources/dining_remote_datasource.dart';
import 'network_providers.dart';

final diningRemoteDataSourceProvider = Provider<DiningRemoteDataSource>((ref) {
  return DiningRemoteDataSource(ref.watch(apiClientProvider));
});

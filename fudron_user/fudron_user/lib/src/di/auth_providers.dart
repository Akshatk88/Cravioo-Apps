import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/datasources/auth_remote_datasource.dart';
import '../data/repository/auth_repository_impl.dart';
import '../domain/repository/auth_repository.dart';
import 'network_providers.dart';

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  return AuthRemoteDataSource(ref.watch(apiClientProvider));
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    ref.watch(authRemoteDataSourceProvider),
    ref.watch(tokenStorageProvider),
  );
});

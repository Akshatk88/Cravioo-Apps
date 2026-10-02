import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/datasources/account_remote_datasource.dart';
import 'network_providers.dart';

final accountRemoteDataSourceProvider = Provider<AccountRemoteDataSource>((ref) {
  return AccountRemoteDataSource(
    ref.watch(apiClientProvider),
    ref.watch(tokenStorageProvider),
  );
});

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/datasources/address_remote_datasource.dart';
import 'network_providers.dart';

final addressRemoteDataSourceProvider = Provider<AddressRemoteDataSource>((ref) {
  return AddressRemoteDataSource(ref.watch(apiClientProvider));
});

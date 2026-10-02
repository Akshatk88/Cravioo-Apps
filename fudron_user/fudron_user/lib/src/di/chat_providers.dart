import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/datasources/chat_remote_datasource.dart';
import 'network_providers.dart';

final chatRemoteDataSourceProvider = Provider<ChatRemoteDataSource>((ref) {
  return ChatRemoteDataSource(ref.watch(apiClientProvider));
});

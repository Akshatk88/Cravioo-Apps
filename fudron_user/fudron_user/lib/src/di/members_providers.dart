import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/datasources/members_remote_datasource.dart';
import 'network_providers.dart';

final membersRemoteDataSourceProvider = Provider<MembersRemoteDataSource>((ref) {
  return MembersRemoteDataSource(ref.watch(apiClientProvider));
});

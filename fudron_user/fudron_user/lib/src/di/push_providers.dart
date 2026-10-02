import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../platform/notifications/push_service.dart';
import 'account_providers.dart';

final pushServiceProvider = Provider<PushService>((ref) {
  final service = PushService(ref.watch(accountRemoteDataSourceProvider));
  ref.onDispose(service.dispose);
  return service;
});

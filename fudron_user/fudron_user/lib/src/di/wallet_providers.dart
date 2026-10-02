import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repository/wallet_repository_impl.dart';
import '../domain/repository/wallet_repository.dart';
import '../domain/service/wallet_service.dart';
import 'account_providers.dart';

final walletRepositoryProvider = Provider<WalletRepository>((ref) {
  final remote = ref.watch(accountRemoteDataSourceProvider);
  return WalletRepositoryImpl(remote);
});

final walletServiceProvider = Provider<WalletService>((ref) {
  final repository = ref.watch(walletRepositoryProvider);
  return WalletService(repository);
});

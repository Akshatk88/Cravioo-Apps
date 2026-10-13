import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/result.dart';
import '../../../core/router/app_router.dart';
import '../../../core/ui/app_messenger.dart';
import '../../main/presentation/screens/main_screen.dart';
import '../../wallet/data/wallet_repository.dart';

/// Warns the rider when the cash they are holding has reached (or nearly
/// reached) the admin-set COD cash limit. Once it is reached the backend
/// refuses every COD order ("Please deposit cash first"), so the rider must
/// be told before they keep tapping Accept with nothing happening.
///
/// Uses GET /food/delivery/wallet: cashInHand, totalCashLimit,
/// availableCashLimit (all computed server-side).
class CashLimitGuard {
  CashLimitGuard(this._ref);

  final Ref _ref;

  DateTime? _lastShownAt;
  bool _showing = false;

  /// Warn once the remaining limit drops under this share of the total.
  static const _nearShare = 0.10;

  /// Don't nag on every resume; a forced check (e.g. a refused COD accept)
  /// ignores this.
  static const _cooldown = Duration(minutes: 15);

  /// A failed accept: a cash-limit refusal gets the full popup (with the way
  /// to deposit), anything else a red message.
  void handleAcceptError(String message) {
    if (isCashLimitError(message)) {
      check(force: true);
    } else {
      showAppMessage(message, isError: true);
    }
  }

  Future<void> check({bool force = false}) async {
    if (_showing) return;
    if (!force &&
        _lastShownAt != null &&
        DateTime.now().difference(_lastShownAt!) < _cooldown) {
      return;
    }

    final result = await _ref.read(walletRepositoryProvider).getWallet();
    final wallet = result.when(
      success: (data) => (data['wallet'] as Map<String, dynamic>?) ?? data,
      failure: (_) => null,
    );
    if (wallet == null) return;

    final limit = _num(wallet['totalCashLimit']);
    if (limit <= 0) return; // no limit configured
    final inHand = _num(wallet['cashInHand']);
    final available = wallet.containsKey('availableCashLimit')
        ? _num(wallet['availableCashLimit'])
        : (limit - inHand).clamp(0, limit).toDouble();

    final reached = available <= 0;
    final near = available < limit * _nearShare;
    if (!reached && !near && !force) return;

    await _show(
      inHand: inHand,
      limit: limit,
      available: available,
      reached: reached,
      near: near,
    );
  }

  Future<void> _show({
    required double inHand,
    required double limit,
    required double available,
    required bool reached,
    required bool near,
  }) async {
    final router = _ref.read(goRouterProvider);
    final context = router.routerDelegate.navigatorKey.currentContext;
    if (context == null || !context.mounted) return;

    _showing = true;
    _lastShownAt = DateTime.now();
    final goDeposit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: Icon(
          Icons.account_balance_wallet_rounded,
          color: reached ? const Color(0xFFD64545) : const Color(0xFFE08A00),
          size: 40,
        ),
        title: Text(
          reached
              ? 'Cash limit reached'
              : (near ? 'Cash limit almost reached' : 'Cash limit too low for this order'),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Cash in hand: ₹${inHand.toStringAsFixed(0)} / ₹${limit.toStringAsFixed(0)}\n'
              'Remaining limit: ₹${available.toStringAsFixed(0)}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Text(
              reached
                  ? 'You cannot accept cash (COD) orders until you deposit the '
                      'cash you are holding. Deposit now from Pocket to keep '
                      'receiving orders and to withdraw your earnings.'
                  : 'Deposit the cash you are holding soon. Once the limit is '
                      'reached you will not be able to accept cash (COD) orders.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Later'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF1FA84F),
              minimumSize: const Size(0, 44),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Deposit now'),
          ),
        ],
      ),
    );
    _showing = false;

    if (goDeposit == true) {
      // Pocket tab hosts deposit and withdrawal.
      _ref.read(mainTabIndexProvider.notifier).setIndex(1);
      router.go('/main');
    }
  }

  static double _num(Object? v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0;
  }
}

final cashLimitGuardProvider = Provider<CashLimitGuard>(CashLimitGuard.new);

/// True for the backend's refusal of a COD accept over the cash limit.
bool isCashLimitError(String message) {
  final m = message.toLowerCase();
  return m.contains('cash limit') || m.contains('deposit cash');
}

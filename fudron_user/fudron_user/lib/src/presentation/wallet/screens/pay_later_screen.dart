import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/haptics.dart';
import '../../../di/payment_providers.dart';
import '../../auth/viewmodels/auth_viewmodel.dart';
import '../../branding/app_colors.dart';
import '../../common_widgets/app_refresh_indicator.dart';
import '../../common_widgets/app_snackbar.dart';
import '../viewmodels/pay_later_viewmodel.dart';
import '../../../../generated/l10n/app_localizations.dart';

class PayLaterScreen extends ConsumerStatefulWidget {
  const PayLaterScreen({super.key});

  @override
  ConsumerState<PayLaterScreen> createState() => _PayLaterScreenState();
}

class _PayLaterScreenState extends ConsumerState<PayLaterScreen> {
  bool _isRepaying = false;

  Future<void> _repayFromWallet() async {
    setState(() => _isRepaying = true);
    final error = await ref.read(payLaterViewModelProvider.notifier).repayFromWallet();
    if (!mounted) return;
    setState(() => _isRepaying = false);
    if (error != null) {
      AppSnackbar.error(context, error);
    } else {
      Haptics.success();
      AppSnackbar.success(context, 'Pay Later due cleared from your wallet.');
    }
  }

  Future<void> _repayWithRazorpay() async {
    setState(() => _isRepaying = true);
    final data = await ref.read(payLaterViewModelProvider.notifier).startRazorpayRepayment();
    if (data == null) {
      if (!mounted) return;
      setState(() => _isRepaying = false);
      AppSnackbar.error(context, ref.read(payLaterViewModelProvider).errorMessage ?? 'Could not start repayment.');
      return;
    }

    final user = ref.read(authViewModelProvider).value;
    final result = await ref.read(paymentGatewayProvider).repayPayLater(
          razorpay: data,
          customerName: user?.displayName ?? 'Customer',
          customerPhone: user?.phone ?? '',
          customerEmail: user?.email,
        );

    if (!mounted) return;
    setState(() => _isRepaying = false);
    if (result.isSuccess) {
      Haptics.success();
      AppSnackbar.success(context, result.message);
      unawaited(ref.read(payLaterViewModelProvider.notifier).refresh());
    } else if (result.outcome.name != 'cancelled') {
      AppSnackbar.error(context, result.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(payLaterViewModelProvider);
    final viewModel = ref.read(payLaterViewModelProvider.notifier);

    final textColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final cardColor = isDark ? AppColors.cardDark : AppColors.cardLight;
    final backgroundColor = isDark ? AppColors.backgroundDark : AppColors.backgroundLight;

    final account = state.account;
    final hasDue = account.amountDue > 0;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 20),
          onPressed: () {
            Haptics.light();
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/profile');
            }
          },
        ),
        title: Text(AppLocalizations.of(context)!.payLater, style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: AppRefreshIndicator(
          onRefresh: viewModel.refresh,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (!account.eligible)
                _InfoCard(
                  cardColor: cardColor,
                  textColor: textColor,
                  secondaryColor: secondaryColor,
                  icon: Icons.lock_clock_outlined,
                  title: 'Not eligible yet',
                  body:
                      'Pay Later unlocks automatically once you have 3 delivered orders with a clean payment history.',
                )
              else ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: hasDue ? AppColors.error.withValues(alpha: 0.08) : cardColor,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: hasDue ? AppColors.error.withValues(alpha: 0.3) : AppColors.borderLight,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Amount due', style: TextStyle(fontSize: 13, color: secondaryColor, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Text(
                        '₹${account.amountDue.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: hasDue ? AppColors.error : textColor,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _StatChip(
                              label: 'Credit limit',
                              value: '₹${account.limit.toStringAsFixed(0)}',
                              textColor: textColor,
                              secondaryColor: secondaryColor,
                            ),
                          ),
                          Expanded(
                            child: _StatChip(
                              label: 'Available',
                              value: '₹${account.availableCredit.toStringAsFixed(0)}',
                              textColor: textColor,
                              secondaryColor: secondaryColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (hasDue) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Your due must be cleared before placing any new order.',
                    style: TextStyle(fontSize: 13, color: secondaryColor),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _isRepaying ? null : _repayFromWallet,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.account_balance_wallet_outlined, color: Colors.white),
                      label: Text(
                        'Pay from Fudron Wallet',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: _isRepaying ? null : _repayWithRazorpay,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.credit_card_outlined),
                      label: const Text('Pay Online (UPI / Card)', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ] else
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      'You have no outstanding due. Choose Pay Later at checkout to order on credit, up to your limit.',
                      style: TextStyle(fontSize: 13, color: secondaryColor),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color textColor;
  final Color secondaryColor;

  const _StatChip({required this.label, required this.value, required this.textColor, required this.secondaryColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: secondaryColor)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textColor)),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  final Color cardColor;
  final Color textColor;
  final Color secondaryColor;
  final IconData icon;
  final String title;
  final String body;

  const _InfoCard({
    required this.cardColor,
    required this.textColor,
    required this.secondaryColor,
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 32, color: AppColors.primary),
          const SizedBox(height: 12),
          Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 6),
          Text(body, style: TextStyle(fontSize: 13, color: secondaryColor, height: 1.4)),
        ],
      ),
    );
  }
}

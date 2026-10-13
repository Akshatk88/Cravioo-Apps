import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:food_user_application/config/theme/app_colors.dart';
import 'package:food_user_application/features/wallet/domain/withdrawal_record_model.dart';
import 'package:food_user_application/features/wallet/presentation/controllers/wallet_controller.dart';
import 'package:food_user_application/features/wallet/presentation/widgets/money_ui.dart';

enum _Tab { pending, successful, rejected }

/// Withdrawal history with Pending / Successful / Rejected tabs and the
/// ability to cancel a pending request.
class WithdrawalHistoryScreen extends ConsumerStatefulWidget {
  const WithdrawalHistoryScreen({super.key});

  @override
  ConsumerState<WithdrawalHistoryScreen> createState() =>
      _WithdrawalHistoryScreenState();
}

class _WithdrawalHistoryScreenState
    extends ConsumerState<WithdrawalHistoryScreen> {
  _Tab _tab = _Tab.pending;
  String? _cancellingId;

  bool _matches(WithdrawalRecord r) {
    switch (_tab) {
      case _Tab.pending:
        return r.isPending;
      case _Tab.successful:
        return r.isApproved;
      case _Tab.rejected:
        return r.isRejectedOrCancelled;
    }
  }

  Future<void> _cancel(WithdrawalRecord r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel withdrawal?'),
        content: Text('Cancel this pending request of ${formatInr(r.amount)}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Cancel request')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _cancellingId = r.id);
    try {
      await ref.read(withdrawalHistoryControllerProvider.notifier).cancel(r.id);
      if (mounted) showMoneySnack(context, 'Withdrawal cancelled');
    } catch (e) {
      if (mounted) {
        showMoneySnack(context, moneyErrorMessage(e, 'Failed to cancel withdrawal'),
            error: true);
      }
    } finally {
      if (mounted) setState(() => _cancellingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = MoneyColors(isDarkMode(context));
    final async = ref.watch(withdrawalHistoryControllerProvider);

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.surface,
        foregroundColor: c.text,
        elevation: 0,
        title: const Text('Withdrawal History'),
      ),
      body: Column(
        children: [
          Container(
            color: c.surface,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                for (final t in _Tab.values)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: ChoiceChip(
                        showCheckmark: false,
                        label: SizedBox(
                          width: double.infinity,
                          child: Text(
                            switch (t) {
                              _Tab.pending => 'Pending',
                              _Tab.successful => 'Successful',
                              _Tab.rejected => 'Rejected',
                            },
                            textAlign: TextAlign.center,
                          ),
                        ),
                        selected: _tab == t,
                        selectedColor: c.primary,
                        labelStyle: TextStyle(
                          color: _tab == t ? Colors.white : c.text,
                          fontWeight: FontWeight.w600,
                        ),
                        onSelected: (_) => setState(() => _tab = t),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => MoneyErrorView(
                message: moneyErrorMessage(e, 'Failed to load withdrawals'),
                onRetry: () => ref
                    .read(withdrawalHistoryControllerProvider.notifier)
                    .refresh(),
              ),
              data: (all) {
                final list = all.where(_matches).toList();
                return RefreshIndicator(
                  onRefresh: () => ref
                      .read(withdrawalHistoryControllerProvider.notifier)
                      .refresh(),
                  child: list.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(
                              height: 320,
                              child: MoneyEmptyView(
                                icon: Icons.account_balance_wallet_outlined,
                                message: switch (_tab) {
                                  _Tab.pending => 'No pending withdrawal requests',
                                  _Tab.successful => 'No successful withdrawals',
                                  _Tab.rejected =>
                                    'No rejected or cancelled withdrawals',
                                },
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          itemCount: list.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (_, i) => _WithdrawalCard(
                            record: list[i],
                            c: c,
                            cancelling: _cancellingId == list[i].id,
                            onCancel: () => _cancel(list[i]),
                          ),
                        ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _WithdrawalCard extends StatelessWidget {
  const _WithdrawalCard({
    required this.record,
    required this.c,
    required this.cancelling,
    required this.onCancel,
  });

  final WithdrawalRecord record;
  final MoneyColors c;
  final bool cancelling;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = record.isApproved
        ? (AppColors.successLight, const Color(0xFF166534))
        : record.isPending
            ? (AppColors.warningLight, const Color(0xFF92400E))
            : (AppColors.errorLight, const Color(0xFF991B1B));
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(formatInr(record.amount),
                    style: TextStyle(
                        color: c.text,
                        fontSize: 18,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text('Requested: ${formatDateTime(record.requestedAt)}',
                    style: TextStyle(color: c.subtext, fontSize: 12)),
                if (record.processedAt != null && !record.isPending)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text('Processed: ${formatDateTime(record.processedAt)}',
                        style: TextStyle(color: c.subtext, fontSize: 12)),
                  ),
                if (record.isRejectedOrCancelled &&
                    record.rejectionReason.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(record.rejectionReason,
                        style: const TextStyle(
                            color: AppColors.error, fontSize: 12)),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: bg, borderRadius: BorderRadius.circular(20)),
                child: Text(record.statusLabel,
                    style: TextStyle(
                        color: fg, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
              if (record.isCancellable)
                TextButton(
                  onPressed: cancelling ? null : onCancel,
                  style: TextButton.styleFrom(
                      foregroundColor: AppColors.error,
                      padding: const EdgeInsets.symmetric(horizontal: 4)),
                  child: Text(cancelling ? 'Cancelling...' : 'Cancel',
                      style: const TextStyle(fontSize: 12)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

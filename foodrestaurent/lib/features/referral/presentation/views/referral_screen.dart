import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_user_application/config/theme/app_colors.dart';
import 'package:food_user_application/core/network/api_exception.dart';
import 'package:food_user_application/features/referral/domain/referral_model.dart';
import 'package:food_user_application/features/referral/presentation/controllers/referral_controller.dart';

class ReferralScreen extends ConsumerWidget {
  const ReferralScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.backgroundDark : AppColors.backgroundLight;
    final textPrimary =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final card = isDark ? AppColors.cardDark : AppColors.cardLight;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;
    final async = ref.watch(referralControllerProvider);

    Widget tile(String label, String value, IconData icon) => Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: textSecondary),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: textPrimary,
              ),
            ),
            Text(label, style: TextStyle(fontSize: 11, color: textSecondary)),
          ],
        ),
      ),
    );

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        foregroundColor: textPrimary,
        title: Text(
          'Refer & Earn',
          style: TextStyle(fontWeight: FontWeight.w700, color: textPrimary),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(referralControllerProvider.notifier).refresh(),
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            children: [
              const SizedBox(height: 120),
              Icon(Icons.error_outline, size: 48, color: textSecondary),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  e is ApiException
                      ? e.message
                      : 'Failed to load referral details',
                  style: TextStyle(color: textSecondary),
                ),
              ),
              Center(
                child: TextButton(
                  onPressed: () =>
                      ref.read(referralControllerProvider.notifier).refresh(),
                  child: const Text('Retry'),
                ),
              ),
            ],
          ),
          data: (d) {
            final s = d.stats;
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Invite other restaurants to join and earn rewards when they get approved.',
                        style: TextStyle(color: textSecondary),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _pair(
                            'Reward per referral',
                            _money(s.rewardAmount),
                            AppColors.primaryButton,
                            textSecondary,
                          ),
                          const SizedBox(width: 8),
                          _pair(
                            'Total earned',
                            _money(s.totalReferralEarnings),
                            AppColors.primaryButton,
                            textSecondary,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Your referral code',
                        style: TextStyle(fontSize: 12, color: textSecondary),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: SelectableText(
                                d.referralCode.isEmpty
                                    ? 'Unavailable'
                                    : d.referralCode,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1,
                                  color: textPrimary,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Copy code',
                              onPressed: d.referralCode.isEmpty
                                  ? null
                                  : () => _copy(
                                      context,
                                      d.referralCode,
                                      'Referral code copied',
                                    ),
                              icon: const Icon(Icons.copy, size: 18),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primaryButton,
                          ),
                          onPressed: d.referralCode.isEmpty
                              ? null
                              : () => _copy(
                                  context,
                                  'Join Cravioo as a Restaurant Partner${s.rewardAmount > 0 ? ' and earn ${_money(s.rewardAmount)}' : ''} on approval! Use my referral code: ${d.referralCode}',
                                  'Invite message copied. Paste it to share.',
                                ),
                          icon: const Icon(Icons.share),
                          label: const Text('Copy invite message'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    tile('Invited', '${s.totalInvited}', Icons.group),
                    const SizedBox(width: 8),
                    tile('Approved', '${s.creditedCount}', Icons.check_circle),
                    const SizedBox(width: 8),
                    tile('Pending', '${s.pendingCount}', Icons.schedule),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Referred restaurants',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                if (d.referred.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'No referrals yet. Share your code to start inviting!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: textSecondary),
                      ),
                    ),
                  )
                else
                  ...d.referred.map(
                    (r) => _ReferredTile(
                      r: r,
                      card: card,
                      border: border,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  static String _money(double v) =>
      '₹${v == v.roundToDouble() ? v.toInt() : v.toStringAsFixed(2)}';

  static Widget _pair(String label, String value, Color c, Color secondary) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: secondary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 11, color: secondary)),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: c,
                ),
              ),
            ],
          ),
        ),
      );

  static Future<void> _copy(
    BuildContext context,
    String text,
    String message,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: text));
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ReferredTile extends StatelessWidget {
  const _ReferredTile({
    required this.r,
    required this.card,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
  });

  final ReferredRestaurant r;
  final Color card;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (r.status) {
      'credited' => ('Credited', Colors.green),
      'rejected' => ('Rejected', Colors.red),
      _ => ('Pending approval', Colors.orange),
    };
    final d = r.invitedAt?.toLocal();
    final date = d == null ? '-' : '${d.day}/${d.month}/${d.year}';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  r.phone.isEmpty ? 'Phone hidden' : r.phone,
                  style: TextStyle(fontSize: 12, color: textSecondary),
                ),
                const SizedBox(height: 2),
                Text(
                  'Joined on $date',
                  style: TextStyle(fontSize: 11, color: textSecondary),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '+${ReferralScreen._money(r.earnedAmount)}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

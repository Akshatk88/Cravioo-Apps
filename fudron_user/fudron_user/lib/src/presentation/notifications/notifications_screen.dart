import '../common_widgets/app_refresh_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../navigation/back_navigation.dart';
import '../../core/utils/haptics.dart';
import '../../data/models/wallet_model.dart';
import '../../di/account_providers.dart';
import '../branding/app_colors.dart';
import '../navigation/route_names.dart';
import '../auth/viewmodels/auth_viewmodel.dart';
import '../common_widgets/empty_state_widget.dart';
import '../common_widgets/skeleton_loading.dart';

final notificationsInboxProvider = FutureProvider.autoDispose<
    ({List<AppNotification> items, int unreadCount, int totalPages})>((ref) async {
  final account = ref.watch(accountRemoteDataSourceProvider);
  return account.getInbox(page: 1, limit: 50);
});

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final secondaryColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    final isLoggedIn = ref.watch(authViewModelProvider).value != null;

    if (!isLoggedIn) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: textColor),
            onPressed: () => context.backOr(),
          ),
          title: Text(
            'Notifications',
            style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              const Expanded(
                child: EmptyStateWidget(
                  title: 'Login to View Notifications',
                  subtitle: 'Please log in to receive updates on your orders and exclusive offers.',
                  icon: Icons.notifications_none_rounded,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                    ),
                    onPressed: () {
                      Haptics.light();
                      context.push('${RouteNames.login}?from=${Uri.encodeComponent(RouteNames.orders)}');
                    },
                    child: const Text(
                      'LOG IN TO CONTINUE',
                      style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final inboxAsync = ref.watch(notificationsInboxProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textColor),
          onPressed: () => context.backOr(),
        ),
        title: Text(
          'Notifications',
          style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: inboxAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(20),
            child: SkeletonNotificationList(count: 5),
          ),
          error: (err, _) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded, size: 48, color: Colors.redAccent),
                const SizedBox(height: 12),
                Text('Could not load notifications', style: TextStyle(color: textColor, fontSize: 16)),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => ref.invalidate(notificationsInboxProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
          data: (inbox) {
            final items = inbox.items;
            if (items.isEmpty) {
              return const EmptyStateWidget(
                title: "You're all caught up! 🎉",
                subtitle: 'No notifications at this time. Check back later for updates.',
                icon: Icons.notifications_off_outlined,
              );
            }

            return AppRefreshIndicator(
              onRefresh: () async => ref.invalidate(notificationsInboxProvider),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Notifications', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor)),
                          const SizedBox(height: 4),
                          Text('Stay updated with your orders & offers', style: TextStyle(fontSize: 13, color: secondaryColor)),
                        ],
                      ),
                      if (items.isNotEmpty)
                        TextButton(
                          onPressed: () async {
                            Haptics.light();
                            try {
                              await ref.read(accountRemoteDataSourceProvider).clearInbox();
                              ref.invalidate(notificationsInboxProvider);
                            } catch (_) {}
                          },
                          child: Text('Clear All', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  for (final item in items)
                    _NotificationCard(
                      item: item,
                      isDark: isDark,
                      onTap: () async {
                        Haptics.light();
                        if (!item.isRead) {
                          await ref.read(accountRemoteDataSourceProvider).markRead(item.id);
                          ref.invalidate(notificationsInboxProvider);
                        }
                      },
                      onDelete: () async {
                        Haptics.light();
                        await ref.read(accountRemoteDataSourceProvider).deleteNotification(item.id);
                        ref.invalidate(notificationsInboxProvider);
                      },
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final AppNotification item;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _NotificationCard({
    required this.item,
    required this.isDark,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final secondaryColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    final isUnread = !item.isRead;

    return Dismissible(
      key: Key(item.id),
      onDismissed: (_) => onDelete(),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.redAccent.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isUnread
                ? AppColors.primaryAlpha(isDark ? 0.14 : 0.08)
                : (isDark ? AppColors.cardDark : Colors.white),
            borderRadius: BorderRadius.circular(18),
            boxShadow: isDark || isUnread
                ? []
                : [BoxShadow(color: AppColors.shadow1, blurRadius: 16, offset: const Offset(0, 6))],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primaryAlpha(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.notifications_active_rounded, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textColor),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          item.createdAt != null ? item.createdAt!.toString().substring(0, 10) : '',
                          style: TextStyle(fontSize: 11, color: secondaryColor),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.message,
                      style: TextStyle(fontSize: 12.5, color: secondaryColor, height: 1.3),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


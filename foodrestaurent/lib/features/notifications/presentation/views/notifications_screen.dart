import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:food_user_application/config/theme/app_colors.dart';
import 'package:food_user_application/core/network/api_exception.dart';
import 'package:food_user_application/core/widgets/app_refresh_indicator.dart';
import 'package:food_user_application/features/notifications/domain/notification_model.dart';
import 'package:food_user_application/features/notifications/presentation/controllers/notifications_controller.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final notificationsAsync = ref.watch(notificationsControllerProvider);

    final backgroundColor = isDarkMode
        ? AppColors.backgroundDark
        : AppColors.backgroundLight;

    final primaryTextColor = isDarkMode
        ? AppColors.textPrimaryDark
        : AppColors.textPrimaryLight;

    final secondaryTextColor = isDarkMode
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    return Scaffold(
      backgroundColor: backgroundColor,

      // ============================================================
      // APP BAR
      // ============================================================
      appBar: AppBar(
        backgroundColor: backgroundColor,
        foregroundColor: primaryTextColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,

        leading: IconButton(
          onPressed: () => context.pop(),
          icon: Icon(
            Icons.arrow_back_rounded,
            color: primaryTextColor,
            size: 25,
          ),
        ),

        title: Text(
          'Notifications',
          style: TextStyle(
            color: primaryTextColor,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),

        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () {
              ref.read(notificationsControllerProvider.notifier).refresh();
            },
            icon: Icon(
              Icons.refresh_rounded,
              color: AppColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),

      // ============================================================
      // BODY
      // ============================================================
      body: notificationsAsync.when(
        // ==========================================================
        // LOADING
        // ==========================================================

        loading: () => const Center(
          child: CircularProgressIndicator(
            color: AppColors.primary,
            strokeWidth: 2.5,
          ),
        ),

        // ==========================================================
        // ERROR
        // ==========================================================
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? AppColors.error.withValues(alpha: 0.14)
                        : AppColors.errorLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.error_outline_rounded,
                    color: AppColors.error,
                    size: 36,
                  ),
                ),

                const SizedBox(height: 18),

                Text(
                  error is ApiException
                      ? error.message
                      : 'Failed to load notifications.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: primaryTextColor,
                    fontSize: 14,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                const SizedBox(height: 20),

                ElevatedButton(
                  onPressed: () {
                    ref
                        .read(notificationsControllerProvider.notifier)
                        .refresh();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryButton,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 13,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Try again',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ==========================================================
        // DATA
        // ==========================================================
        data: (state) => AppRefreshIndicator(
          onRefresh: () {
            return ref.read(notificationsControllerProvider.notifier).refresh();
          },

          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),

            child: Column(
              children: [
                // ==================================================
                // SUMMARY CARD
                // ==================================================

                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: _buildSummaryCard(isDarkMode, state),
                ),

                // ==================================================
                // CLEAR ALL
                // ==================================================
                if (state.items.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            _confirmClearAll(context, ref);
                          },

                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            size: 18,
                          ),

                          label: const Text('Clear all'),

                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.error,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // ==================================================
                // EMPTY / LIST
                // ==================================================
                state.items.isEmpty
                    ? _buildEmptyState(
                        isDarkMode,
                        primaryTextColor,
                        secondaryTextColor,
                      )
                    : _buildNotificationList(isDarkMode, state.items),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==============================================================
  // SUMMARY CARD
  // ==============================================================

  Widget _buildSummaryCard(bool isDarkMode, NotificationsState state) {
    final cardColor = isDarkMode
        ? AppColors.surfaceDark
        : AppColors.surfaceLight;

    final primaryText = isDarkMode
        ? AppColors.textPrimaryDark
        : AppColors.textPrimaryLight;

    final secondaryText = isDarkMode
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),

      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),

        border: Border.all(
          color: isDarkMode ? AppColors.borderDark : AppColors.borderLight,
          width: 1,
        ),

        boxShadow: [
          if (!isDarkMode)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.045),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
        ],
      ),

      child: Row(
        children: [
          // ========================================================
          // ICON
          // ========================================================

          Container(
            width: 52,
            height: 52,

            decoration: BoxDecoration(
              color: isDarkMode
                  ? AppColors.primary.withValues(alpha: 0.16)
                  : AppColors.primaryTint,
              borderRadius: BorderRadius.circular(15),
            ),

            child: Icon(
              Icons.notifications_none_rounded,
              color: isDarkMode
                  ? AppColors.primaryLight
                  : AppColors.primaryButton,
              size: 29,
            ),
          ),

          const SizedBox(width: 14),

          // ========================================================
          // TEXT
          // ========================================================
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Inbox',
                  style: TextStyle(
                    color: secondaryText,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  '${state.total} Notification${state.total == 1 ? '' : 's'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: primaryText,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          // ========================================================
          // UNREAD
          // ========================================================
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),

            decoration: BoxDecoration(
              color: isDarkMode
                  ? AppColors.primary.withValues(alpha: 0.16)
                  : AppColors.primaryTint,
              borderRadius: BorderRadius.circular(20),
            ),

            child: Text(
              'Unread: ${state.unreadCount}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,

              style: TextStyle(
                color: isDarkMode
                    ? AppColors.primaryLight
                    : AppColors.primaryDeep,
                fontWeight: FontWeight.w800,
                fontSize: 11.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==============================================================
  // EMPTY STATE
  // ==============================================================

  Widget _buildEmptyState(
    bool isDarkMode,
    Color primaryText,
    Color secondaryText,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 75, horizontal: 24),

      child: Column(
        children: [
          Container(
            width: 86,
            height: 86,

            decoration: BoxDecoration(
              color: isDarkMode
                  ? AppColors.primary.withValues(alpha: 0.15)
                  : AppColors.primaryTint,
              shape: BoxShape.circle,
            ),

            child: Icon(
              Icons.notifications_none_rounded,
              color: isDarkMode
                  ? AppColors.primaryLight
                  : AppColors.primaryButton,
              size: 44,
            ),
          ),

          const SizedBox(height: 20),

          Text(
            'No notifications yet',
            style: TextStyle(
              color: primaryText,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 7),

          Text(
            'You are all caught up!',
            textAlign: TextAlign.center,
            style: TextStyle(color: secondaryText, fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }

  // ==============================================================
  // NOTIFICATION LIST
  // ==============================================================

  Widget _buildNotificationList(
    bool isDarkMode,
    List<NotificationModel> items,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),

      child: Column(
        children: [
          for (final notification in items) ...[
            _NotificationCard(
              notification: notification,
              isDarkMode: isDarkMode,
            ),

            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  // ==============================================================
  // CLEAR ALL DIALOG
  // ==============================================================

  Future<void> _confirmClearAll(BuildContext context, WidgetRef ref) async {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final confirmed = await showDialog<bool>(
      context: context,

      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode
            ? AppColors.surfaceDark
            : AppColors.surfaceLight,

        surfaceTintColor: Colors.transparent,

        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),

        title: Text(
          'Clear all notifications?',
          style: TextStyle(
            color: isDarkMode
                ? AppColors.textPrimaryDark
                : AppColors.textPrimaryLight,
            fontWeight: FontWeight.w800,
          ),
        ),

        content: Text(
          'This removes every notification from your inbox.',
          style: TextStyle(
            color: isDarkMode
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
            height: 1.4,
          ),
        ),

        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context, false);
            },

            child: Text(
              'Cancel',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),

          TextButton(
            onPressed: () {
              Navigator.pop(context, true);
            },

            child: const Text(
              'Clear all',
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(notificationsControllerProvider.notifier).dismissAll();
    }
  }
}

// ==================================================================
// NOTIFICATION CARD
// ==================================================================

class _NotificationCard extends ConsumerWidget {
  const _NotificationCard({
    required this.notification,
    required this.isDarkMode,
  });

  final NotificationModel notification;
  final bool isDarkMode;

  // ==============================================================
  // ICON
  // ==============================================================

  IconData get _icon {
    switch (notification.source) {
      case 'FSSAI_EXPIRY':
        return Icons.warning_amber_rounded;

      case 'SUPPORT_RESPONSE':
        return Icons.support_agent_outlined;

      case 'ADMIN_BROADCAST':
      default:
        return Icons.campaign_outlined;
    }
  }

  // ==============================================================
  // ICON COLOR
  // ==============================================================

  Color get _iconColor {
    switch (notification.source) {
      case 'FSSAI_EXPIRY':
        return AppColors.error;

      case 'SUPPORT_RESPONSE':
        return AppColors.primaryLight;

      case 'ADMIN_BROADCAST':
      default:
        return AppColors.primary;
    }
  }

  // ==============================================================
  // TAG BACKGROUND
  // ==============================================================

  Color get _tagColor {
    switch (notification.source) {
      case 'FSSAI_EXPIRY':
        return isDarkMode
            ? AppColors.error.withValues(alpha: 0.14)
            : AppColors.errorLight;

      case 'SUPPORT_RESPONSE':
        return isDarkMode
            ? AppColors.primary.withValues(alpha: 0.15)
            : AppColors.primaryTint;

      case 'ADMIN_BROADCAST':
      default:
        return isDarkMode
            ? AppColors.primary.withValues(alpha: 0.15)
            : AppColors.primaryTint;
    }
  }

  // ==============================================================
  // TAG TEXT COLOR
  // ==============================================================

  Color get _tagTextColor {
    switch (notification.source) {
      case 'FSSAI_EXPIRY':
        return AppColors.error;

      case 'SUPPORT_RESPONSE':
        return isDarkMode ? AppColors.primaryLight : AppColors.primaryDeep;

      case 'ADMIN_BROADCAST':
      default:
        return isDarkMode ? AppColors.primaryLight : AppColors.primaryDeep;
    }
  }

  // ==============================================================
  // BUILD
  // ==============================================================

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRead = notification.isRead;

    // ============================================================
    // CARD COLORS
    // ============================================================

    final cardColor = isDarkMode
        ? (isRead ? AppColors.surfaceDark : AppColors.surfaceVariantDark)
        : (isRead ? AppColors.surfaceLight : AppColors.surfaceVariantLight);

    final borderColor = isDarkMode
        ? (isRead
              ? AppColors.borderDark
              : AppColors.primary.withValues(alpha: 0.42))
        : (isRead
              ? AppColors.borderLight
              : AppColors.primary.withValues(alpha: 0.28));

    final textColor = isDarkMode
        ? AppColors.textPrimaryDark
        : AppColors.textPrimaryLight;

    final secondaryTextColor = isDarkMode
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    return Dismissible(
      key: ValueKey(notification.id),

      direction: DismissDirection.endToStart,

      // ==========================================================
      // DELETE BACKGROUND
      // ==========================================================
      background: Container(
        alignment: Alignment.centerRight,

        padding: const EdgeInsets.symmetric(horizontal: 20),

        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(17),
        ),

        child: const Icon(
          Icons.delete_outline_rounded,
          color: Colors.white,
          size: 25,
        ),
      ),

      onDismissed: (_) {
        ref
            .read(notificationsControllerProvider.notifier)
            .dismiss(notification.id);
      },

      // ==========================================================
      // CARD
      // ==========================================================
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,

        onTap: () {
          ref
              .read(notificationsControllerProvider.notifier)
              .markRead(notification.id);
        },

        child: Container(
          width: double.infinity,

          padding: const EdgeInsets.all(16),

          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(17),

            border: Border.all(color: borderColor, width: isRead ? 1 : 1.2),

            boxShadow: [
              if (!isDarkMode)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.035),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
            ],
          ),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              // ==================================================
              // TOP ROW
              // ==================================================

              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,

                    decoration: BoxDecoration(
                      color: _tagColor,
                      borderRadius: BorderRadius.circular(10),
                    ),

                    child: Icon(_icon, size: 19, color: _iconColor),
                  ),

                  const SizedBox(width: 9),

                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),

                      decoration: BoxDecoration(
                        color: _tagColor,
                        borderRadius: BorderRadius.circular(10),
                      ),

                      child: Text(
                        notification.tag,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,

                        style: TextStyle(
                          color: _tagTextColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // ==================================================
                  // CLOSE
                  // ==================================================
                  SizedBox(
                    width: 30,
                    height: 30,

                    child: IconButton(
                      onPressed: () {
                        ref
                            .read(notificationsControllerProvider.notifier)
                            .dismiss(notification.id);
                      },

                      padding: EdgeInsets.zero,

                      constraints: const BoxConstraints(
                        minWidth: 30,
                        minHeight: 30,
                        maxWidth: 30,
                        maxHeight: 30,
                      ),

                      icon: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: secondaryTextColor,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // ==================================================
              // TITLE
              // ==================================================
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  if (!isRead) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 6),

                      child: Container(
                        width: 8,
                        height: 8,

                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),

                    const SizedBox(width: 7),
                  ],

                  Expanded(
                    child: Text(
                      notification.title,

                      maxLines: 3,

                      overflow: TextOverflow.ellipsis,

                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        height: 1.25,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 7),

              // ==================================================
              // MESSAGE
              // ==================================================
              Text(
                notification.message,

                style: TextStyle(
                  color: secondaryTextColor,
                  fontSize: 13,
                  height: 1.45,
                ),
              ),

              const SizedBox(height: 13),

              // ==================================================
              // DATE
              // ==================================================
              Row(
                children: [
                  Icon(
                    Icons.access_time_rounded,
                    size: 14,
                    color: secondaryTextColor,
                  ),

                  const SizedBox(width: 5),

                  Expanded(
                    child: Text(
                      DateFormat(
                        'd MMM, h:mm a',
                      ).format(notification.createdAt.toLocal()),

                      maxLines: 1,

                      overflow: TextOverflow.ellipsis,

                      style: TextStyle(
                        color: secondaryTextColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

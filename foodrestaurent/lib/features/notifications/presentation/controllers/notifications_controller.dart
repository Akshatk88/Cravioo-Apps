import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_user_application/features/notifications/data/notification_repository.dart';
import 'package:food_user_application/features/notifications/domain/notification_model.dart';

class NotificationsState {
  NotificationsState({
    required this.items,
    required this.unreadCount,
    required this.total,
  });

  final List<NotificationModel> items;
  final int unreadCount;
  final int total;
}

/// Backs the Notifications screen and the unread badge on the Orders app
/// bar — one shared source of truth so marking/dismissing in the list
/// updates the badge immediately without a second round-trip.
class NotificationsController extends AsyncNotifier<NotificationsState> {
  @override
  Future<NotificationsState> build() => _fetch();

  Future<NotificationsState> _fetch() async {
    final page = await ref.read(notificationRepositoryProvider).getInbox();
    return NotificationsState(
      items: page.items,
      unreadCount: page.unreadCount,
      total: page.total,
    );
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(_fetch);
  }

  Future<void> markRead(String id) async {
    final current = state.value;
    if (current == null) return;
    final target = current.items.where((n) => n.id == id);
    if (target.isEmpty || target.first.isRead) return;

    state = AsyncData(
      NotificationsState(
        items: current.items
            .map((n) => n.id == id ? n.copyWith(isRead: true) : n)
            .toList(),
        unreadCount: (current.unreadCount - 1).clamp(0, current.unreadCount),
        total: current.total,
      ),
    );
    try {
      await ref.read(notificationRepositoryProvider).markRead(id);
    } catch (_) {
      await refresh();
    }
  }

  Future<void> dismiss(String id) async {
    final current = state.value;
    if (current == null) return;
    final target = current.items.where((n) => n.id == id);
    if (target.isEmpty) return;
    final wasUnread = !target.first.isRead;

    state = AsyncData(
      NotificationsState(
        items: current.items.where((n) => n.id != id).toList(),
        unreadCount: wasUnread
            ? (current.unreadCount - 1).clamp(0, current.unreadCount)
            : current.unreadCount,
        total: (current.total - 1).clamp(0, current.total),
      ),
    );
    try {
      await ref.read(notificationRepositoryProvider).dismiss(id);
    } catch (_) {
      await refresh();
    }
  }

  Future<void> dismissAll() async {
    final current = state.value;
    if (current == null || current.items.isEmpty) return;

    state = AsyncData(
      NotificationsState(items: const [], unreadCount: 0, total: 0),
    );
    try {
      await ref.read(notificationRepositoryProvider).dismissAll();
    } catch (_) {
      await refresh();
    }
  }
}

final notificationsControllerProvider =
    AsyncNotifierProvider<NotificationsController, NotificationsState>(
      NotificationsController.new,
    );

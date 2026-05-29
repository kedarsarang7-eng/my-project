import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dukanx_shared/dukanx_shared.dart';
import '../../data/notifications_repository.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          notifications.whenData((list) {
            final unread = list.where((n) => !n.isRead).length;
            if (unread == 0) return const SizedBox.shrink();
            return TextButton(
              onPressed: () =>
                  ref.read(notificationsRepositoryProvider).markAllRead(),
              child: const Text('Mark all read'),
            );
          }).valueOrNull ?? const SizedBox.shrink(),
        ],
      ),
      body: notifications.when(
        data: (list) => list.isEmpty
            ? const EmptyStateWidget(
                icon: Icons.notifications_none_rounded,
                title: 'No notifications',
                subtitle: 'You\'re all caught up!',
              )
            : RefreshIndicator(
                onRefresh: () async =>
                    ref.invalidate(notificationsProvider),
                child: ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, indent: 72),
                  itemBuilder: (_, i) => _NotificationTile(
                    notification: list[i],
                    onTap: () async {
                      if (!list[i].isRead) {
                        await ref
                            .read(notificationsRepositoryProvider)
                            .markRead(list[i].id);
                        ref.invalidate(notificationsProvider);
                      }
                    },
                  ),
                ),
              ),
        loading: () => const ListLoadingShimmer(itemHeight: 72),
        error: (e, _) => ErrorStateWidget(
          message: 'Could not load notifications',
          onRetry: () => ref.invalidate(notificationsProvider),
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final CustomerNotification notification;
  final VoidCallback onTap;

  const _NotificationTile({
    required this.notification,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _iconForCategory(notification.category);
    final isUnread = !notification.isRead;

    return ListTile(
      tileColor: isUnread
          ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.2)
          : null,
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        notification.title,
        style: TextStyle(
          fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(notification.body, maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(
            DateFormatter.timeAgo(notification.createdAt),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
      onTap: onTap,
      trailing: isUnread
          ? Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
            )
          : null,
    );
  }

  static (IconData, Color) _iconForCategory(NotificationCategory cat) {
    switch (cat) {
      case NotificationCategory.invoice:
        return (Icons.receipt_long_rounded, const Color(0xFF1565C0));
      case NotificationCategory.payment:
        return (Icons.payments_rounded, const Color(0xFF43A047));
      case NotificationCategory.due:
        return (Icons.warning_amber_rounded, const Color(0xFFE53935));
      case NotificationCategory.promotion:
        return (Icons.local_offer_rounded, const Color(0xFFE91E63));
      case NotificationCategory.system:
        return (Icons.info_outline_rounded, const Color(0xFF757575));
    }
  }
}

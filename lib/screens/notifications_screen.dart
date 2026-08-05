import 'package:ballys_reservation_app/models/Guest/guest_booking.dart';
import 'package:ballys_reservation_app/models/app_notification.dart';
import 'package:ballys_reservation_app/providers/app_notifications_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    // Opening the list counts as seeing them — clears the bell badge.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(appNotificationsProvider.notifier).markAllRead();
    });
  }

  String _formatReceivedAt(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('yyyy-MM-dd hh:mm a').format(date);
  }

  IconData _iconFor(AppNotification notification) {
    switch (notification.msgType) {
      case '35':
        return Icons.hotel;
      default:
        return Icons.notifications_active;
    }
  }

  void _handleTap(AppNotification notification) {
    ref.read(appNotificationsProvider.notifier).markRead(notification.id);

    // Guest booking notification — open the booking it refers to.
    if (notification.msgType == '35') {
      final booking = GuestBooking(
        idNo: 0,
        mid: notification.data['MID'] ?? '',
        pkgStart: notification.data['Pkg_Start'] ?? '',
        pkgEnd: notification.data['Pkg_End'] ?? '',
        insertDate: notification.data['InsertDate'] ?? '',
        pkgStatus: false,
      );

      context.push(
        '/guest-bookings/view-booking',
        extra: {'booking': booking, 'isPending': true},
      );
    }
  }

  Future<void> _confirmClearAll() async {
    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear notifications'),
        content: const Text('Remove all notifications from this list?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (shouldClear == true) {
      await ref.read(appNotificationsProvider.notifier).clearAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifications = ref.watch(appNotificationsProvider);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'Notifications',
          style: TextStyle(fontSize: 16, fontFamily: 'ABCArizonaFlare'),
        ),
        actions: [
          if (notifications.isNotEmpty)
            IconButton(
              tooltip: 'Clear all',
              icon: const Icon(Icons.delete_outline),
              onPressed: _confirmClearAll,
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(appNotificationsProvider.notifier).load(),
        child: notifications.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                  Center(
                    child: Icon(
                      Icons.notifications_none,
                      size: 64,
                      color: Colors.grey.shade400,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      'No notifications yet',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                ],
              )
            : ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: notifications.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final notification = notifications[index];

                  return Dismissible(
                    key: ValueKey(notification.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      color: Colors.red.shade400,
                      padding: const EdgeInsets.only(right: 20),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    onDismissed: (_) => ref
                        .read(appNotificationsProvider.notifier)
                        .remove(notification.id),
                    child: ListTile(
                      onTap: () => _handleTap(notification),
                      leading: CircleAvatar(
                        backgroundColor: notification.isRead
                            ? Colors.grey.shade300
                            : const Color(0xFFDAB066),
                        child: Icon(
                          _iconFor(notification),
                          color: notification.isRead
                              ? Colors.grey.shade700
                              : Colors.white,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        notification.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: notification.isRead
                              ? FontWeight.w500
                              : FontWeight.bold,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (notification.body.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              notification.body,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ],
                          const SizedBox(height: 4),
                          Text(
                            _formatReceivedAt(notification.receivedAt),
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      trailing: notification.msgType == '35'
                          ? const Icon(Icons.chevron_right, size: 20)
                          : null,
                    ),
                  );
                },
              ),
      ),
    );
  }
}

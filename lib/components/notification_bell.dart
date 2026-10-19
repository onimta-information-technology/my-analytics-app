import 'package:ballys_reservation_app/providers/app_notifications_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Bell in the app bar with a red badge showing how many notifications
/// arrived since the list was last opened.
class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key, this.route = '/home/notifications'});

  /// Route pushed when the bell is tapped.
  final String route;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(unreadNotificationCountProvider);
    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          padding: const EdgeInsets.all(10.0),
          tooltip: 'Notifications',
          icon: const Icon(Icons.notifications_none, size: 30),
          onPressed: () => context.push(route),
        ),
        if (unreadCount > 0)
          Positioned(
            top: 6,
            right: 4,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.rectangle,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: Text(
                  unreadCount > 99 ? '99+' : '$unreadCount',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    height: 1.1,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

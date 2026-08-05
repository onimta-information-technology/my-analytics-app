import 'package:ballys_reservation_app/data/services/notification_store.dart';
import 'package:ballys_reservation_app/models/app_notification.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppNotificationsNotifier extends StateNotifier<List<AppNotification>> {
  AppNotificationsNotifier() : super(const []) {
    load();
  }

  /// Re-reads history from storage — also picks up notifications written by the
  /// FCM background isolate while the app was closed.
  Future<void> load() async {
    state = await NotificationStore.load();
  }

  Future<void> addFromMessage(RemoteMessage message) async {
    final updated = await NotificationStore.add(message);
    if (updated != null) state = updated;
  }

  Future<void> markAllRead() async {
    state = await NotificationStore.markAllRead();
  }

  Future<void> markRead(String id) async {
    state = await NotificationStore.markRead(id);
  }

  Future<void> remove(String id) async {
    state = await NotificationStore.remove(id);
  }

  Future<void> clearAll() async {
    state = await NotificationStore.clear();
  }
}

final appNotificationsProvider =
    StateNotifierProvider<AppNotificationsNotifier, List<AppNotification>>(
      (ref) => AppNotificationsNotifier(),
    );

/// Unread count shown on the home screen bell badge.
final unreadNotificationCountProvider = Provider<int>((ref) {
  return ref.watch(appNotificationsProvider).where((e) => !e.isRead).length;
});

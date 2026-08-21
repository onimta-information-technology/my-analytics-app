import 'dart:convert';

import 'package:ballys_reservation_app/models/app_notification.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists received push notifications so the home screen bell can show them
/// even after the app is killed and relaunched.
///
/// Safe to call from the FCM background isolate — every read calls
/// [SharedPreferences.reload] first so the main isolate picks up whatever the
/// background isolate wrote.
class NotificationStore {
  static const String _key = 'app_notification_history';
  static const int _maxStored = 100;

  /// Pings that only tell the client a thread changed — an edited message, a
  /// reaction — and carry no body of their own. They must never raise a
  /// banner or bump the badge: nothing new was said.
  static bool isSilentThreadUpdate(RemoteMessage message) {
    final type = (message.data['msg_type'] ?? message.data['type'])?.toString();
    return type == 'message_edit' ||
        type == 'message_edited' ||
        type == 'message_reaction';
  }

  /// Chat pushes are handled by the chat screens, so they never enter history.
  static bool isChatMessage(RemoteMessage message) {
    final data = message.data;

    if (data['msg_type']?.toString() == '11') return true;
    if (data['screen']?.toString() == 'chat') return true;
    if (data['chatId'] != null || data['chat_id'] != null) return true;

    final details = data['Details']?.toString();
    if (details != null && details.isNotEmpty) {
      try {
        final decoded = json.decode(details);
        if (decoded is Map && decoded['chatId'] != null) return true;
      } catch (_) {
        // Not JSON — fall through, treat as non-chat.
      }
    }

    return false;
  }

  static AppNotification? fromRemoteMessage(RemoteMessage message) {
    if (isChatMessage(message)) return null;

    final data = message.data;
    final title =
        data['title'] ?? message.notification?.title ?? 'New Notification';
    final body = data['body'] ?? message.notification?.body ?? '';

    return AppNotification(
      id:
          message.messageId ??
          '${DateTime.now().microsecondsSinceEpoch}_${title.hashCode}',
      title: title,
      body: body,
      msgType: data['msg_type']?.toString() ?? '',
      data: data.map(
        (key, value) => MapEntry(key.toString(), value?.toString() ?? ''),
      ),
      receivedAt: DateTime.now(),
    );
  }

  static Future<SharedPreferences> _prefs() async {
    final prefs = await SharedPreferences.getInstance();
    // Pull in writes made by the background isolate.
    await prefs.reload();
    return prefs;
  }

  static Future<List<AppNotification>> load() async {
    try {
      final prefs = await _prefs();
      final raw = prefs.getStringList(_key) ?? [];
      final items = raw
          .map((e) {
            try {
              return AppNotification.fromJson(json.decode(e));
            } catch (_) {
              return null;
            }
          })
          .whereType<AppNotification>()
          .toList();

      items.sort((a, b) => b.receivedAt.compareTo(a.receivedAt));
      return items;
    } catch (e) {
      print('Error loading notification history: $e');
      return [];
    }
  }

  static Future<void> save(List<AppNotification> items) async {
    try {
      final prefs = await _prefs();
      final trimmed = items.take(_maxStored).toList();
      await prefs.setStringList(
        _key,
        trimmed.map((e) => json.encode(e.toJson())).toList(),
      );
    } catch (e) {
      print('Error saving notification history: $e');
    }
  }

  /// Adds a notification to history. Returns the updated list, or null when the
  /// message was a chat push (nothing stored) or a duplicate.
  static Future<List<AppNotification>?> add(RemoteMessage message) async {
    final notification = fromRemoteMessage(message);
    if (notification == null) return null;

    final existing = await load();
    if (existing.any((e) => e.id == notification.id)) return null;

    final updated = [notification, ...existing];
    await save(updated);
    return updated;
  }

  static Future<List<AppNotification>> markAllRead() async {
    final updated = (await load()).map((e) => e.copyWith(isRead: true)).toList();
    await save(updated);
    return updated;
  }

  static Future<List<AppNotification>> markRead(String id) async {
    final updated = (await load())
        .map((e) => e.id == id ? e.copyWith(isRead: true) : e)
        .toList();
    await save(updated);
    return updated;
  }

  static Future<List<AppNotification>> remove(String id) async {
    final updated = (await load()).where((e) => e.id != id).toList();
    await save(updated);
    return updated;
  }

  static Future<List<AppNotification>> clear() async {
    await save([]);
    return [];
  }
}

import 'package:ballys_reservation_app/components/badge_service.dart';
import 'package:ballys_reservation_app/data/services/firebase_api_service.dart';
import 'package:ballys_reservation_app/models/chat_contact.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';

class BadgeSyncHelper {
  /// Fetch actual unread count from server and update badge
  static Future<void> syncBadgeWithServer() async {
    try {
      print('🔄 Syncing badge with server...');
      
      // Get current user name
      final userName = await StorageUtil.getUserName();
      if (userName == null) {
        print('❌ No user name found, cannot sync badge');
        return;
      }

      // Fetch chats from server
      final chatData = await FirebaseApiService.fetchUserChats();
      final userData = await FirebaseApiService.fetchAllUsers();

      if (chatData['chats'] != null) {
        final List<dynamic> chats = chatData['chats'];

        // Extract device ID
        String? actualDeviceId;
        if (chats.isNotEmpty) {
          final firstChat = chats[0];
          final participants = firstChat['participants'] as List<dynamic>? ?? [];

          for (var participant in participants) {
            final uuid = participant['user_uuid'] as String?;
            final name = participant['name'] as String?;

            if (name == userName && uuid != null && uuid != name) {
              actualDeviceId = uuid;
              break;
            }
          }
        }

        final String userIdentifier = actualDeviceId ?? userName;

        // Build user details map
        Map<String, dynamic> userDetailsMap = {};
        if (userData['users'] != null) {
          final List<dynamic> users = userData['users'];
          for (var user in users) {
            final uName = user['name'] ?? user['id'] ?? '';
            userDetailsMap[uName] = user;
          }
        }

        // Parse contacts and calculate unread count
        final contacts = chats
            .map((chat) => ChatContact.fromChatApiJson(
                  chat,
                  userIdentifier,
                  participantDetails: userDetailsMap,
                ))
            .toList();

        final totalUnread = contacts.fold(
          0,
          (sum, contact) => sum + contact.unreadCount,
        );

        // Update badge with actual count
        await BadgeService().updateBadge(totalUnread);
        print('✅ Badge synced: $totalUnread unread messages');
      }
    } catch (e) {
      print('❌ Error syncing badge with server: $e');
    }
  }
}
import 'package:ballys_reservation_app/components/badge_service.dart';
import 'package:ballys_reservation_app/data/services/firebase_api_service.dart';
import 'package:ballys_reservation_app/models/chat_contact.dart';
import 'package:ballys_reservation_app/utils/device_id.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';

class BadgeSyncHelper {
  /// Fetch actual unread count from server and update badge
  static Future<void> syncBadgeWithServer() async {
    try {
      // Get current user name
      final userName = await StorageUtil.getUserName();
      if (userName == null) {
       
        return;
      }

      // Fetch chats from server
      final chatData = await FirebaseApiService.fetchUserChats();
      final userData = await FirebaseApiService.fetchAllUsers();

      if (chatData['chats'] != null) {
        final List<dynamic> chats = chatData['chats'];

        // Participants are keyed by device id, so that identifies "you".
        final String userIdentifier = await DeviceId.get();

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
                  currentUserName: userName,
                  participantDetails: userDetailsMap,
                ))
            .toList();

        final totalUnread = contacts.fold(
          0,
          (sum, contact) => sum + contact.unreadCount,
        );

        // Update badge with actual count
        await BadgeService().updateBadge(totalUnread);
        
      }
    } catch (e) {
     
    }
  }
}
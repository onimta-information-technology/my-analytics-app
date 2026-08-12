import 'package:ballys_reservation_app/data/services/firebase_api_service.dart';
import 'package:ballys_reservation_app/models/chat_contact.dart';
import 'package:ballys_reservation_app/models/chat_group.dart';
import 'package:ballys_reservation_app/providers/font_settings_provider.dart';
import 'package:flutter/material.dart';

/// Group info sheet: name, settings and the member list with their roles.
///
/// Shared by the chat list and the group conversation screen, which know the
/// group by different models — so it takes only what it needs to render before
/// `GET /api/groups/:groupId` comes back.
void showGroupDetailsSheet({
  required BuildContext context,
  required String groupId,
  required Color avatarColor,
  required FontSettings fontSettings,
  String? currentUserUuid,
}) {
  final detailsFuture = FirebaseApiService.fetchGroupDetails(groupId);

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) {
      return SizedBox(
        height: MediaQuery.of(sheetContext).size.height * 0.7,
        child: FutureBuilder<Map<String, dynamic>>(
          future: detailsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.green),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 44,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Could not load group details',
                        style: TextStyle(
                          fontSize: fontSettings.fontSize,
                          color: Colors.red,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }

            final details = GroupDetails.fromApiJson(snapshot.data ?? {});
            // Admins first, then everyone else in the order the API returned.
            final members = [
              ...details.members.where((m) => m.isAdmin),
              ...details.members.where((m) => !m.isAdmin),
            ];

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: avatarColor,
                        backgroundImage: details.groupAvatarUrl != null
                            ? NetworkImage(details.groupAvatarUrl!)
                            : null,
                        child: details.groupAvatarUrl == null
                            ? Text(
                                ChatContact.generateInitials(
                                  details.groupName,
                                ),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: fontSettings.fontSize,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              details.groupName,
                              style: TextStyle(
                                fontSize: fontSettings.fontSize + 2,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${members.length} member${members.length == 1 ? '' : 's'}'
                              '${details.adminOnlyMessaging ? ' • Only admins can message' : ''}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: fontSettings.fontSize - 3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text(
                    'Members',
                    style: TextStyle(
                      fontSize: fontSettings.fontSize - 2,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
                Expanded(
                  child: members.isEmpty
                      ? Center(
                          child: Text(
                            'No members',
                            style: TextStyle(
                              fontSize: fontSettings.fontSize - 2,
                              color: Colors.grey,
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: members.length,
                          itemBuilder: (context, index) {
                            final member = members[index];
                            final bool isMe =
                                member.userUuid == currentUserUuid;

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: member.avatarColor,
                                child: Text(
                                  member.initials,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: fontSettings.fontSize - 4,
                                  ),
                                ),
                              ),
                              title: Text(
                                isMe ? '${member.name} (You)' : member.name,
                                style: TextStyle(
                                  fontSize: fontSettings.fontSize,
                                  fontWeight: fontSettings.fontWeight,
                                ),
                              ),
                              subtitle:
                                  member.userUuid == details.createdByUuid
                                  ? Text(
                                      'Created this group',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: fontSettings.fontSize - 4,
                                      ),
                                    )
                                  : null,
                              trailing: member.isAdmin
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(
                                          10,
                                        ),
                                      ),
                                      child: Text(
                                        'Admin',
                                        style: TextStyle(
                                          color: Colors.green[800],
                                          fontSize: fontSettings.fontSize - 5,
                                        ),
                                      ),
                                    )
                                  : null,
                            );
                          },
                        ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        child: Text(
                          'Close',
                          style: TextStyle(
                            fontSize: fontSettings.fontSize - 2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );
    },
  );
}

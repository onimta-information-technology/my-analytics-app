import 'package:flutter/material.dart';
import 'package:ballys_reservation_app/models/chat_contact.dart';

/// A member of a group, as returned inside `GET /api/groups/:groupId`.
class GroupMember {
  final String userUuid;
  final String name;
  final String firstName;
  final String role;
  final int appType;
  final Color avatarColor;
  final String initials;

  /// The member's own profile picture, when they have uploaded one. Null
  /// otherwise, which falls back to the coloured initials.
  final String? avatarUrl;

  GroupMember({
    required this.userUuid,
    required this.name,
    this.firstName = '',
    this.role = 'member',
    this.appType = 1,
    required this.avatarColor,
    required this.initials,
    this.avatarUrl,
  });

  bool get isAdmin => role.toLowerCase() == 'admin';

  static GroupMember fromApiJson(Map<String, dynamic> json) {
    final String name = json['name']?.toString() ?? 'Unknown';

    return GroupMember(
      userUuid: json['userUuid']?.toString() ?? '',
      name: name,
      firstName: json['firstName']?.toString() ?? '',
      role: json['role']?.toString() ?? 'member',
      appType: ChatContact.parseAppType(json['appType']),
      avatarColor: ChatContact.generateColorFromName(name),
      initials: ChatContact.generateInitials(name),
      avatarUrl: ChatContact.parseAvatarUrl(json),
    );
  }
}

/// Full group payload from `GET /api/groups/:groupId`, including its members.
class GroupDetails {
  final String groupId;
  final String groupName;
  final String? groupAvatarUrl;
  final bool adminOnlyMessaging;
  final String createdByUuid;
  final int createdByAppType;
  final List<GroupMember> members;

  GroupDetails({
    required this.groupId,
    required this.groupName,
    this.groupAvatarUrl,
    this.adminOnlyMessaging = false,
    this.createdByUuid = '',
    this.createdByAppType = 1,
    this.members = const [],
  });

  /// Role of [userUuid] in this group, or null when they are not a member.
  String? roleOf(String userUuid) {
    for (final member in members) {
      if (member.userUuid == userUuid) return member.role;
    }
    return null;
  }

  bool isAdmin(String userUuid) => roleOf(userUuid)?.toLowerCase() == 'admin';

  static GroupDetails fromApiJson(Map<String, dynamic> json) {
    final rawMembers = json['members'];
    final avatarUrl = json['groupAvatarUrl']?.toString();

    return GroupDetails(
      groupId: json['groupId']?.toString() ?? json['id']?.toString() ?? '',
      groupName: json['groupName']?.toString() ?? 'Unnamed group',
      groupAvatarUrl:
          (avatarUrl == null || avatarUrl.isEmpty) ? null : avatarUrl,
      adminOnlyMessaging: json['adminOnlyMessaging'] == true,
      createdByUuid: json['createdByUuid']?.toString() ?? '',
      createdByAppType: ChatContact.parseAppType(json['createdByAppType']),
      members: rawMembers is List
          ? rawMembers
              .whereType<Map<String, dynamic>>()
              .map(GroupMember.fromApiJson)
              .toList()
          : const [],
    );
  }
}

/// A chat group as returned by `GET /api/groups/user/:userId`.
class ChatGroup {
  final String id;
  final String groupId;
  final String groupName;
  final String? groupAvatarUrl;
  final bool adminOnlyMessaging;
  final String lastMessage;
  final DateTime? lastMessageTime;
  final String? lastMessageSender;
  final String role;
  final int memberCount;
  final Color avatarColor;
  final String initials;

  ChatGroup({
    required this.id,
    required this.groupId,
    required this.groupName,
    this.groupAvatarUrl,
    this.adminOnlyMessaging = false,
    this.lastMessage = '',
    this.lastMessageTime,
    this.lastMessageSender,
    this.role = 'member',
    this.memberCount = 0,
    required this.avatarColor,
    required this.initials,
  });

  bool get isAdmin => role.toLowerCase() == 'admin';

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  /// Relative time for the last message, reusing the chat list formatting.
  String get time => lastMessageTime == null
      ? ''
      : ChatContact.getTimeAgo(lastMessageTime);

  static ChatGroup fromApiJson(Map<String, dynamic> json) {
    final String groupId =
        json['groupId']?.toString() ?? json['id']?.toString() ?? '';
    final String name = json['groupName']?.toString() ?? 'Unnamed group';

    // lastMessageTime comes back as an ISO string; tolerate nulls/garbage so a
    // single bad row does not blow up the whole list.
    DateTime? lastMessageTime;
    final rawTime = json['lastMessageTime'];
    if (rawTime != null && rawTime.toString().isNotEmpty) {
      lastMessageTime = DateTime.tryParse(rawTime.toString());
    }

    final avatarUrl = json['groupAvatarUrl']?.toString();

    return ChatGroup(
      id: json['id']?.toString() ?? groupId,
      groupId: groupId,
      groupName: name,
      groupAvatarUrl: (avatarUrl == null || avatarUrl.isEmpty) ? null : avatarUrl,
      adminOnlyMessaging: json['adminOnlyMessaging'] == true,
      lastMessage: json['lastMessage']?.toString() ?? '',
      lastMessageTime: lastMessageTime,
      lastMessageSender: json['lastMessageSender']?.toString(),
      role: json['role']?.toString() ?? 'member',
      memberCount: _parseInt(json['memberCount']),
      avatarColor: ChatContact.generateColorFromName(name),
      initials: ChatContact.generateInitials(name),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'groupId': groupId,
        'groupName': groupName,
        'groupAvatarUrl': groupAvatarUrl,
        'adminOnlyMessaging': adminOnlyMessaging,
        'lastMessage': lastMessage,
        'lastMessageTime': lastMessageTime?.toIso8601String(),
        'lastMessageSender': lastMessageSender,
        'role': role,
        'memberCount': memberCount,
      };
}

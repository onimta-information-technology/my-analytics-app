import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:ballys_reservation_app/data/services/firebase_api_service.dart';

class ChatContact {
  final String id;
  final String chatUuid;
  final String userUuid;
  final String name;
  final String firstName;
  final String lastMessage;
  final String time;
  final bool isOnline;
  final Color avatarColor;
  final String initials;
  final int unreadCount;
  final DateTime? lastMessageTime;
  final String? lastMessageSender;
  final List<String> participants;
  final DateTime createdAt;
  final String? lastMessageSenderName;
  final int appType;
  /// Remote picture for this row: the group's photo for a group, and the
  /// other participant's profile picture for a 1:1 chat. Null when nobody has
  /// uploaded one, which falls back to the coloured initials.
  final String? avatarUrl;
  final bool lastMessageRead;

  /// WhatsApp-style pin. Pinned rows are kept at the top of the list, newest
  /// pin first; [pinnedAt] is null whenever [isPinned] is false.
  final bool isPinned;
  final DateTime? pinnedAt;

  ChatContact({
    required this.id,
    required this.chatUuid,
    String? userUuid,
    required this.name,
    this.firstName = '',
    required this.lastMessage,
    required this.time,
    this.isOnline = false,
    required this.avatarColor,
    required this.initials,
    this.unreadCount = 0,
    this.lastMessageTime,
    this.lastMessageSender,
    required this.participants,
    required this.createdAt,
    required this.lastMessageSenderName,
    this.appType = 1,
    this.avatarUrl,
    this.lastMessageRead = true,
    this.isPinned = false,
    this.pinnedAt,
  }) : userUuid = userUuid ?? id;

  /// Copy with a few fields changed — the row is rebuilt in place whenever a
  /// pin is toggled or a new message lands.
  ChatContact copyWith({
    String? lastMessage,
    String? time,
    DateTime? lastMessageTime,
    String? lastMessageSender,
    String? chatUuid,
    String? firstName,
    int? unreadCount,
    bool? isPinned,
    DateTime? pinnedAt,
  }) => ChatContact(
    id: id,
    chatUuid: chatUuid ?? this.chatUuid,
    userUuid: userUuid,
    name: name,
    firstName: firstName ?? this.firstName,
    lastMessage: lastMessage ?? this.lastMessage,
    time: time ?? this.time,
    isOnline: isOnline,
    avatarColor: avatarColor,
    initials: initials,
    unreadCount: unreadCount ?? this.unreadCount,
    lastMessageTime: lastMessageTime ?? this.lastMessageTime,
    lastMessageSender: lastMessageSender ?? this.lastMessageSender,
    participants: participants,
    createdAt: createdAt,
    lastMessageSenderName: lastMessageSenderName,
    appType: appType,
    avatarUrl: avatarUrl,
    lastMessageRead: lastMessageRead,
    isPinned: isPinned ?? this.isPinned,
    // Unpinning clears the timestamp, so it is not carried over.
    pinnedAt: (isPinned ?? this.isPinned) ? (pinnedAt ?? this.pinnedAt) : null,
  );

  // Backend sends appType as a string (e.g. "2") in some responses and an
  // int in others, so parse defensively rather than casting directly.
  static int parseAppType(dynamic value, {int fallback = 1}) {
    if (value == null) return fallback;
    if (value is int) return value;
    return int.tryParse(value.toString()) ?? fallback;
  }

  /// Reads a profile picture off a chat-backend payload.
  ///
  /// The participant entries in `/api/chats/user/:id` use snake_case while the
  /// user and member endpoints use camelCase, so accept both, and treat an
  /// empty string as "no picture" so callers only have to null-check.
  static String? parseAvatarUrl(Map<String, dynamic> json) {
    final raw = (json['profileImageUrl'] ?? json['profile_image_url'])
        ?.toString()
        .trim();
    return (raw == null || raw.isEmpty) ? null : raw;
  }

  /// `pinnedAt` comes back as an ISO string, and as null for an unpinned row.
  static DateTime? parsePinnedAt(Map<String, dynamic> json) {
    final raw = json['pinnedAt']?.toString();
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'chatUuid': chatUuid,
    'userUuid': userUuid,
    'name': name,
    'firstName': firstName,
    'lastMessage': lastMessage,
    'time': time,
    'isOnline': isOnline,
    'avatarColor': avatarColor.value,
    'initials': initials,
    'unreadCount': unreadCount,
    'lastMessageTime': lastMessageTime?.millisecondsSinceEpoch,
    'lastMessageSender': lastMessageSender,
    'participants': participants,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'lastMessageSenderName': lastMessageSenderName,
    'appType': appType,
    'avatarUrl': avatarUrl,
    'lastMessageRead': lastMessageRead,
    'isPinned': isPinned,
    'pinnedAt': pinnedAt?.millisecondsSinceEpoch,
  };

  static ChatContact fromJson(Map<String, dynamic> json) => ChatContact(
    id: json['id'],
    chatUuid: json['chatUuid'],
    userUuid: json['userUuid'],
    name: json['name'],
    firstName: json['firstName'] ?? '',
    lastMessage: json['lastMessage'],
    time: json['time'],
    isOnline: json['isOnline'] ?? false,
    avatarColor: Color(json['avatarColor']),
    initials: json['initials'],
    unreadCount: json['unreadCount'] ?? 0,
    lastMessageTime: json['lastMessageTime'] != null
        ? DateTime.fromMillisecondsSinceEpoch(json['lastMessageTime'])
        : null,
    lastMessageSender: json['lastMessageSender'],
    participants: List<String>.from(json['participants'] ?? []),
    createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt']),
    lastMessageSenderName: json['lastMessageSenderName'],
    appType: parseAppType(json['appType']),
    avatarUrl: json['avatarUrl']?.toString(),
    lastMessageRead: json['lastMessageRead'] ?? true,
    isPinned: json['isPinned'] == true,
    pinnedAt: json['pinnedAt'] != null
        ? DateTime.fromMillisecondsSinceEpoch(json['pinnedAt'])
        : null,
  );

  /// Builds a 1:1 row, which is titled after the *other* participant.
  ///
  /// [currentUserDeviceId] is the chat backend's key for "you" (participants
  /// are stored under the device id). [currentUserName] is only a second
  /// guard: when the device id is missing or stale the uuid comparison used to
  /// match nothing, so the first participant won — often the current user, and
  /// the row rendered with the user's own name.
  ///
  /// The device id alone does not identify "you": one phone carrying both apps
  /// registers the same uuid under both appTypes, so both participants of that
  /// 1:1 chat would match and the title would fall back to whichever entry the
  /// payload happened to list first. Identity is the `(uuid, appType)` pair.
  static ChatContact fromChatApiJson(
    Map<String, dynamic> json,
    String currentUserDeviceId, {
    String? currentUserName,
    Map<String, dynamic>? participantDetails,
    int currentAppType = FirebaseApiService.appType,
  }) {
    final List<dynamic> participantsData = json['participants'] ?? [];

    bool isCurrentUser(dynamic participant) {
      final String uuid = participant['user_uuid'] ?? '';
      final String name = participant['name'] ?? '';
      final int appType = parseAppType(
        participant['appType'] ?? participant['app_type'],
        fallback: currentAppType,
      );

      if (currentUserDeviceId.isNotEmpty && uuid == currentUserDeviceId) {
        return appType == currentAppType;
      }
      return currentUserName != null &&
          currentUserName.isNotEmpty &&
          name == currentUserName &&
          appType == currentAppType;
    }

    String otherParticipantUuid = '';
    String otherParticipantName = '';
    dynamic otherParticipantAppType;
    String? otherParticipantAvatar;

    for (var participant in participantsData) {
      if (isCurrentUser(participant)) continue;

      otherParticipantUuid = participant['user_uuid'] ?? '';
      otherParticipantName = participant['name'] ?? '';
      otherParticipantAppType =
          participant['appType'] ?? participant['app_type'];
      otherParticipantAvatar = parseAvatarUrl(
        Map<String, dynamic>.from(participant as Map),
      );
      if (otherParticipantName.isNotEmpty) break;
    }

    // Every participant is the current user (self chat), or the payload has no
    // usable name — fall back to the first entry so the row is not blank.
    if (otherParticipantName.isEmpty && participantsData.isNotEmpty) {
      otherParticipantUuid = participantsData[0]['user_uuid'] ?? '';
      otherParticipantName = participantsData[0]['name'] ?? 'Unknown';
      otherParticipantAppType =
          participantsData[0]['appType'] ?? participantsData[0]['app_type'];
      otherParticipantAvatar = parseAvatarUrl(
        Map<String, dynamic>.from(participantsData[0] as Map),
      );
    }

    final String name = otherParticipantName.isNotEmpty
        ? otherParticipantName
        : 'Unknown User';
    final String actualUserUuid = otherParticipantUuid;

    // Extract firstName from the name
    String firstName = '';
    if (name.isNotEmpty) {
      final nameParts = name.trim().split(' ');
      if (nameParts.length > 1) {
        firstName = nameParts.last;
      } else {
        firstName = name;
      }
    }

    final String initials = generateInitials(name);
    final Color avatarColor = generateColorFromName(name);

    final DateTime? lastMessageTime = json['lastMessageTime'] != null
        ? DateTime.parse(json['lastMessageTime'])
        : null;
    final String timeAgo = getTimeAgo(lastMessageTime);

    final String lastMessage = json['lastMessage'] ?? 'No messages yet';

    final List<String> participantsList = participantsData
        .map<String>((p) => p['user_uuid'] as String? ?? '')
        .where((uuid) => uuid.isNotEmpty)
        .toList();

    // The chats payload carries the picture on the participant entry; the
    // user directory is the fallback for older rows that come back without
    // one, the same way appType is resolved below.
    final Map<String, dynamic>? otherUserDetails =
        participantDetails?[otherParticipantName] is Map
        ? Map<String, dynamic>.from(
            participantDetails![otherParticipantName] as Map,
          )
        : null;
    final String? avatarUrl =
        otherParticipantAvatar ??
        (otherUserDetails == null ? null : parseAvatarUrl(otherUserDetails));

    final int appType = parseAppType(
      otherParticipantAppType ??
          participantDetails?[otherParticipantName]?['appType'] ??
          json['appType'],
    );

    return ChatContact(
      id: json['id'] ?? '',
      chatUuid: json['chatUuid'] ?? json['id'] ?? '',
      userUuid: actualUserUuid,
      name: name,
      firstName: firstName,
      lastMessage: lastMessage,
      time: timeAgo,
      isOnline: json['isOnline'] ?? false,
      avatarColor: avatarColor,
      initials: initials,
      unreadCount: json['unreadCount'] ?? 0,
      lastMessageTime: lastMessageTime,
      lastMessageSender: json['lastMessageSender'],
      participants: participantsList,
      createdAt: DateTime.parse(json['createdAt']),
      lastMessageSenderName: json['lastMessageSenderName'],
      appType: appType,
      avatarUrl: avatarUrl,
      lastMessageRead: json['lastMessageRead'] ?? true,
      isPinned: json['isPinned'] == true,
      pinnedAt: parsePinnedAt(json),
    );
  }

  static String generateInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return 'U';

    if (parts.length == 1) {
      return parts[0].isNotEmpty ? parts[0][0].toUpperCase() : 'U';
    } else {
      final first = parts[0].isNotEmpty ? parts[0][0] : '';
      final last = parts[parts.length - 1].isNotEmpty
          ? parts[parts.length - 1][0]
          : '';
      return (first + last).toUpperCase();
    }
  }

  static Color generateColorFromName(String name) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.red,
      Colors.purple,
      Colors.orange,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
      Colors.cyan,
      Colors.amber,
    ];

    final int hash = name.hashCode;
    return colors[hash.abs() % colors.length];
  }

  // static String getTimeAgo(DateTime? dateTime) {
  //   if (dateTime == null) return 'Unknown';

  //   final now = DateTime.now();
  //   final difference = now.difference(dateTime);

  //   if (difference.inMinutes < 1) {
  //     return 'now';
  //   } else if (difference.inMinutes < 60) {
  //     return '${difference.inMinutes}m ago';
  //   } else if (difference.inHours < 24) {
  //     return '${difference.inHours}h ago';
  //   } else if (difference.inDays < 7) {
  //     return '${difference.inDays}d ago';
  //   } else {
  //     return '${(difference.inDays / 7).floor()}w ago';
  //   }
  // }
  static String getTimeAgo(DateTime? dateTime) {
  if (dateTime == null) return 'Unknown';

  final now = DateTime.now();

  // The API sends an explicit UTC offset (e.g. +05:30), which DateTime.parse
  // already resolves, so just move it onto the device timezone.
  final messageTime = dateTime.toLocal();

  final difference = now.difference(messageTime);

  // Handle negative differences or very recent messages
  if (difference.isNegative || difference.inSeconds < 5) {
    return 'now';
  }

  if (difference.inSeconds < 60) {
    return '${difference.inSeconds}s ago';
  } else if (difference.inMinutes < 60) {
    return '${difference.inMinutes}m ago';
  } else if (difference.inHours < 24) {
    return '${difference.inHours}h ago';
  } else if (difference.inDays < 7) {
    return '${difference.inDays}d ago';
  } else if (difference.inDays < 30) {
    return '${(difference.inDays / 7).floor()}w ago';
  } else {
    return '${(difference.inDays / 30).floor()}mo ago';
  }
}
}

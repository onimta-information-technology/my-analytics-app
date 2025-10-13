import 'dart:ui';
import 'package:flutter/material.dart';

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
  }) : userUuid = userUuid ?? id;

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
  );

  // Fixed: Now accepts currentUserDeviceId instead of currentUserName
  static ChatContact fromChatApiJson(
    Map<String, dynamic> json,
    String currentUserDeviceId, { // Changed parameter name to be clearer
    Map<String, dynamic>? participantDetails,
  }) {
    final List<dynamic> participantsData = json['participants'] ?? [];

    print('=== DEBUG fromChatApiJson ===');
    print('Current User Device ID: $currentUserDeviceId');
    print('Participants Data: $participantsData');
    print('isOnline value: ${json['isOnline']}');
    print('isOnline type: ${json['isOnline'].runtimeType}');
    //print('Raw isOnline value from API: ${json['email']}');
    String otherParticipantUuid = '';
    String otherParticipantName = '';

    // Find the participant that is NOT the current user (by device ID)
    for (var participant in participantsData) {
      final String participantUuid = participant['user_uuid'] ?? '';
      final String participantName = participant['name'] ?? '';

      print(
        'Checking participant: UUID=$participantUuid, Name=$participantName',
      );

      // Compare with device ID, not name
      if (participantUuid != currentUserDeviceId) {
        otherParticipantUuid = participantUuid;
        otherParticipantName = participantName;
        print('Found other participant: $participantName');
        break;
      } else {
        print('Skipping current user: $participantName');
      }
    }

    // Fallback if no other participant found
    if (otherParticipantName.isEmpty && participantsData.isNotEmpty) {
      // Try to find any participant that's not the current user
      for (var participant in participantsData) {
        final String participantUuid = participant['user_uuid'] ?? '';
        final String participantName = participant['name'] ?? '';

        if (participantUuid != currentUserDeviceId) {
          otherParticipantUuid = participantUuid;
          otherParticipantName = participantName;
          break;
        }
      }

      // If still empty, use the first participant (shouldn't happen in normal cases)
      if (otherParticipantName.isEmpty) {
        otherParticipantUuid = participantsData[0]['user_uuid'] ?? '';
        otherParticipantName = participantsData[0]['name'] ?? 'Unknown';
      }
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

  static String getTimeAgo(DateTime? dateTime) {
    if (dateTime == null) return 'Unknown';

    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${(difference.inDays / 7).floor()}w ago';
    }
  }
}

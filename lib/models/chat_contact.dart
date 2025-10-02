import 'dart:ui';

import 'package:flutter/material.dart';

class ChatContact {
  final String id;
  final String chatUuid;
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

  ChatContact({
    required this.id,
    required this.chatUuid,
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
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'chatUuid': chatUuid,
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
  };

  static ChatContact fromJson(Map<String, dynamic> json) => ChatContact(
    id: json['id'],
    chatUuid: json['chatUuid'],
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
  );

  // Factory constructor to create ChatContact from chat API response
  static ChatContact fromChatApiJson(
    Map<String, dynamic> json,
    String currentUserName, {
    Map<String, dynamic>? participantDetails,
  }) {
    final List<String> participants = List<String>.from(
      json['participants'] ?? [],
    );

    // Get the other participant's name (not the current user)
    final String otherParticipant = participants.firstWhere(
      (participant) => participant != currentUserName,
      orElse: () => participants.isNotEmpty ? participants[0] : 'Unknown',
    );

    final String name = otherParticipant;

    // Extract firstName from participantDetails if available
    String firstName = '';
    if (participantDetails != null &&
        participantDetails.containsKey(otherParticipant)) {
      firstName = participantDetails[otherParticipant]['firstName'] ?? '';
    }

    // If firstName is still empty, try to extract it from the name
    if (firstName.isEmpty) {
      // For names like "Mr Prathap", extract "Prathap"
      final nameParts = name.trim().split(' ');
      if (nameParts.length > 1) {
        firstName = nameParts.last; // Take the last part as firstName
      } else {
        firstName = name; // Use the full name if no spaces
      }
    }

    final String initials = generateInitials(name);
    final Color avatarColor = generateColorFromName(name);

    // Parse lastMessageTime to generate relative time
    final DateTime? lastMessageTime = json['lastMessageTime'] != null
        ? DateTime.parse(json['lastMessageTime'])
        : null;
    final String timeAgo = getTimeAgo(lastMessageTime);

    final String lastMessage = json['lastMessage'] ?? 'No messages yet';

    return ChatContact(
      id: json['id'] ?? '',
      chatUuid: json['chatUuid'] ?? json['id'] ?? '',
      name: name,
      firstName: firstName,
      lastMessage: lastMessage,
      time: timeAgo,
      isOnline: participantDetails?[otherParticipant]?['isOnline'] ?? false,
      avatarColor: avatarColor,
      initials: initials,
      unreadCount: json['unreadCount'] ?? 0,
      lastMessageTime: lastMessageTime,
      lastMessageSender: json['lastMessageSender'],
      participants: participants,
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  // Made public - removed underscore prefix
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

  // Made public - removed underscore prefix
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

  // Made public - removed underscore prefix
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
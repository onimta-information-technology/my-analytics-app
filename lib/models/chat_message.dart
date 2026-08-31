import 'package:ballys_reservation_app/data/services/firebase_api_service.dart';
import 'package:ballys_reservation_app/models/chat_contact.dart';

/// A single attachment item (used inside groupedAttachments).
class AttachmentItem {
  final String? url;        // remote URL
  final String? localPath;  // local file path (pre-upload)
  final String? fileName;
  final String? mimeType;   // e.g. 'image/jpeg'
  final String? messageId;  // server-assigned messageId after upload

  const AttachmentItem({
    this.url,
    this.localPath,
    this.fileName,
    this.mimeType,
    this.messageId,
  });

  bool get isImage =>
      (mimeType ?? '').startsWith('image/') ||
      _isImageExtension(localPath ?? url ?? '');

  static bool _isImageExtension(String path) {
    final ext = path.split('.').last.toLowerCase();
    return ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext);
  }

  AttachmentItem copyWith({
    String? url,
    String? localPath,
    String? fileName,
    String? mimeType,
    String? messageId,
  }) =>
      AttachmentItem(
        url: url ?? this.url,
        localPath: localPath ?? this.localPath,
        fileName: fileName ?? this.fileName,
        mimeType: mimeType ?? this.mimeType,
        messageId: messageId ?? this.messageId,
      );

  Map<String, dynamic> toJson() => {
        'url': url,
        'localPath': localPath,
        'fileName': fileName,
        'mimeType': mimeType,
        'messageId': messageId,
      };

  static AttachmentItem fromJson(Map<String, dynamic> j) => AttachmentItem(
        url: j['url'],
        localPath: j['localPath'],
        fileName: j['fileName'],
        mimeType: j['mimeType'],
        messageId: j['messageId'],
      );
}

// ---------------------------------------------------------------------------

/// Someone named with an @ in a message, as sent in `mentionedUserIds` and
/// returned in `mentions`.
///
/// The uuid alone does not identify a person — the same uuid can exist under
/// another app — so [appType] is part of the identity.
class MessageMention {
  final String userUuid;
  final int appType;

  const MessageMention({required this.userUuid, required this.appType});

  /// uuids arrive in mixed case (an Android device id versus an iOS vendor
  /// uuid), so compare case-insensitively.
  bool matches(String? userUuid, int appType) =>
      userUuid != null &&
      userUuid.toLowerCase() == this.userUuid.toLowerCase() &&
      appType == this.appType;

  Map<String, dynamic> toJson() => {'userUuid': userUuid, 'appType': appType};

  static MessageMention fromJson(Map<String, dynamic> json) => MessageMention(
        userUuid: json['userUuid']?.toString() ?? '',
        appType: ChatContact.parseAppType(json['appType']),
      );

  /// Tolerates a null, a non-list, or rows that are not objects — a malformed
  /// mentions field must not take out the whole message list.
  static List<MessageMention> listFrom(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(MessageMention.fromJson)
        .where((m) => m.userUuid.isNotEmpty)
        .toList();
  }
}

/// One person's reaction to a message, as returned in `reactions` and sent to
/// POST /api/chats/:chatId/messages/:messageId/react.
///
/// The backend keeps **at most one** reaction per user per message: sending
/// the emoji someone already has removes it, a different one replaces it. As
/// with [MessageMention], the uuid alone does not identify a person, so
/// [appType] is part of the identity.
class MessageReaction {
  final String userUuid;
  final int appType;
  final String emoji;

  const MessageReaction({
    required this.userUuid,
    required this.appType,
    required this.emoji,
  });

  /// uuids arrive in mixed case (an Android device id versus an iOS vendor
  /// uuid), so compare case-insensitively.
  bool matches(String? userUuid, int appType) =>
      userUuid != null &&
      userUuid.toLowerCase() == this.userUuid.toLowerCase() &&
      appType == this.appType;

  Map<String, dynamic> toJson() =>
      {'userUuid': userUuid, 'appType': appType, 'emoji': emoji};

  static MessageReaction fromJson(Map<String, dynamic> json) => MessageReaction(
        userUuid: json['userUuid']?.toString() ?? '',
        appType: ChatContact.parseAppType(json['appType']),
        emoji: json['emoji']?.toString() ?? '',
      );

  /// Tolerates a null, a non-list, or rows that are not objects — a malformed
  /// reactions field must not take out the whole message list.
  static List<MessageReaction> listFrom(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(MessageReaction.fromJson)
        .where((r) => r.userUuid.isNotEmpty && r.emoji.isNotEmpty)
        .toList();
  }
}

class ChatMessage {
  final String id;
  final String text;
  final bool isMe;
  final DateTime timestamp;
  final String? apiMessageId;
  final String? apiChatId;
  final bool? isRead;

  // Who sent it. Only meaningful for group chats, where several different
  // people appear on the incoming side.
  final String? senderId;
  final String? senderName;

  // Single-attachment fields (kept for backwards compat)
  final String? filePath;
  final String? fileType;
  final String? fileName;
  final String? attachmentUrl;
  final String? attachmentType;

  // Forwarded: set by the backend on messages produced by
  // POST /api/chats/:chatId/messages/:messageId/forward, so the bubble can
  // show a "Forwarded" tag naming whoever sent the original.
  final bool isForwarded;
  final String? forwardedFromSenderName;

  // Reply: set when this message quotes another one in the same chat. The
  // text and sender name are a snapshot taken at send time, so the quoted
  // preview survives the original being deleted.
  final String? replyToMessageId;
  final String? replyToText;
  final String? replyToSenderName;

  // Multi-attachment: when non-empty, render as image grid
  final List<AttachmentItem> groupedAttachments;

  // People @-mentioned in this message. Empty on messages with no mentions.
  final List<MessageMention> mentions;

  // Emoji reactions, one entry per person who reacted. Empty when nobody has.
  final List<MessageReaction> reactions;

  // Edited: the sender corrected the text after sending. [editedAt] is when
  // the last edit landed, and is null on a message that was never edited.
  final bool isEdited;
  final DateTime? editedAt;

  // System: not written by anyone, but generated by the backend to narrate
  // something that happened to the chat itself — someone added or removed,
  // the group renamed, admin-only messaging toggled. Rendered as a centered
  // notice instead of a bubble, and it takes part in none of the message
  // actions (reply, forward, react, select, delete).
  final bool isSystem;
  final String? systemEvent;

  ChatMessage({
    required this.id,
    required this.text,
    required this.isMe,
    required this.timestamp,
    this.apiMessageId,
    this.apiChatId,
    this.filePath,
    this.fileType,
    this.fileName,
    this.isRead,
    this.attachmentUrl,
    this.attachmentType,
    this.senderId,
    this.senderName,
    this.isForwarded = false,
    this.forwardedFromSenderName,
    this.replyToMessageId,
    this.replyToText,
    this.replyToSenderName,
    List<AttachmentItem>? groupedAttachments,
    List<MessageMention>? mentions,
    List<MessageReaction>? reactions,
    this.isEdited = false,
    this.editedAt,
    this.isSystem = false,
    this.systemEvent,
  })  : groupedAttachments = groupedAttachments ?? const [],
        mentions = mentions ?? const [],
        reactions = reactions ?? const [];

  bool get hasMentions => mentions.isNotEmpty;

  /// True when [userUuid]/[appType] is one of the people named in this
  /// message — i.e. "this one is for you".
  bool mentionsUser(String? userUuid, int appType) =>
      mentions.any((m) => m.matches(userUuid, appType));

  bool get hasReactions => reactions.isNotEmpty;

  /// The emoji [userUuid]/[appType] currently has on this message, or null if
  /// they have not reacted. At most one, by the backend's toggle rule.
  String? reactionOf(String? userUuid, int appType) {
    for (final r in reactions) {
      if (r.matches(userUuid, appType)) return r.emoji;
    }
    return null;
  }

  /// Reactions collapsed into `emoji -> count`, in the order each emoji was
  /// first used, so the summary bar does not reshuffle as people react.
  Map<String, int> get reactionCounts {
    final counts = <String, int>{};
    for (final r in reactions) {
      counts[r.emoji] = (counts[r.emoji] ?? 0) + 1;
    }
    return counts;
  }

  /// How long after sending the backend still accepts an edit. Rejected
  /// server-side past this, so the client only hides the action early enough
  /// to keep the user from writing a correction that would bounce.
  static const Duration editWindow = Duration(minutes: 15);

  /// Only a plain text message of the user's own can be edited: attachments
  /// have no text to correct, and one still on its way to the server has no
  /// id to address.
  bool get isEditable =>
      isMe &&
      !isSystem &&
      apiMessageId != null &&
      apiChatId != null &&
      fileType == null &&
      !hasGroupedAttachments &&
      text.trim().isNotEmpty;

  /// Whether the 15-minute window is still open, as of [now].
  bool isWithinEditWindow([DateTime? now]) =>
      (now ?? DateTime.now()).difference(timestamp) < editWindow;

  /// What is left of the edit window, or [Duration.zero] once it has closed.
  Duration editWindowRemaining([DateTime? now]) {
    final left = timestamp.add(editWindow).difference(now ?? DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  bool get hasGroupedAttachments => groupedAttachments.isNotEmpty;

  bool get isImageGroup =>
      hasGroupedAttachments && groupedAttachments.every((a) => a.isImage);

  ChatMessage copyWith({
    String? id,
    String? text,
    bool? isMe,
    DateTime? timestamp,
    String? apiMessageId,
    String? apiChatId,
    String? filePath,
    String? fileType,
    String? fileName,
    bool? isRead,
    String? attachmentUrl,
    String? attachmentType,
    String? senderId,
    String? senderName,
    bool? isForwarded,
    String? forwardedFromSenderName,
    String? replyToMessageId,
    String? replyToText,
    String? replyToSenderName,
    List<AttachmentItem>? groupedAttachments,
    List<MessageMention>? mentions,
    List<MessageReaction>? reactions,
    bool? isEdited,
    DateTime? editedAt,
    bool? isSystem,
    String? systemEvent,
  }) =>
      ChatMessage(
        id: id ?? this.id,
        text: text ?? this.text,
        isMe: isMe ?? this.isMe,
        timestamp: timestamp ?? this.timestamp,
        apiMessageId: apiMessageId ?? this.apiMessageId,
        apiChatId: apiChatId ?? this.apiChatId,
        filePath: filePath ?? this.filePath,
        fileType: fileType ?? this.fileType,
        fileName: fileName ?? this.fileName,
        isRead: isRead ?? this.isRead,
        attachmentUrl: attachmentUrl ?? this.attachmentUrl,
        attachmentType: attachmentType ?? this.attachmentType,
        senderId: senderId ?? this.senderId,
        senderName: senderName ?? this.senderName,
        isForwarded: isForwarded ?? this.isForwarded,
        forwardedFromSenderName:
            forwardedFromSenderName ?? this.forwardedFromSenderName,
        replyToMessageId: replyToMessageId ?? this.replyToMessageId,
        replyToText: replyToText ?? this.replyToText,
        replyToSenderName: replyToSenderName ?? this.replyToSenderName,
        groupedAttachments: groupedAttachments ?? this.groupedAttachments,
        mentions: mentions ?? this.mentions,
        reactions: reactions ?? this.reactions,
        isEdited: isEdited ?? this.isEdited,
        editedAt: editedAt ?? this.editedAt,
        isSystem: isSystem ?? this.isSystem,
        systemEvent: systemEvent ?? this.systemEvent,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'isMe': isMe,
        'timestamp': timestamp.millisecondsSinceEpoch,
        'apiMessageId': apiMessageId,
        'apiChatId': apiChatId,
        'filePath': filePath,
        'fileType': fileType,
        'fileName': fileName,
        'isRead': isRead,
        'attachmentUrl': attachmentUrl,
        'attachmentType': attachmentType,
        'senderId': senderId,
        'senderName': senderName,
        'isForwarded': isForwarded,
        'forwardedFromSenderName': forwardedFromSenderName,
        'replyToMessageId': replyToMessageId,
        'replyToText': replyToText,
        'replyToSenderName': replyToSenderName,
        'groupedAttachments':
            groupedAttachments.map((a) => a.toJson()).toList(),
        'mentions': mentions.map((m) => m.toJson()).toList(),
        'reactions': reactions.map((r) => r.toJson()).toList(),
        'isEdited': isEdited,
        'editedAt': editedAt?.millisecondsSinceEpoch,
        'isSystem': isSystem,
        'systemEvent': systemEvent,
      };

  static ChatMessage fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'],
        text: json['text'],
        isMe: json['isMe'],
        timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp']),
        apiMessageId: json['apiMessageId'],
        apiChatId: json['apiChatId'],
        filePath: json['filePath'],
        fileType: json['fileType'],
        fileName: json['fileName'],
        isRead: json['isRead'],
        attachmentUrl: json['attachmentUrl'],
        attachmentType: json['attachmentType'],
        senderId: json['senderId'],
        senderName: json['senderName'],
        isForwarded: json['isForwarded'] == true,
        forwardedFromSenderName: json['forwardedFromSenderName'],
        replyToMessageId: json['replyToMessageId'],
        mentions: MessageMention.listFrom(json['mentions']),
        reactions: MessageReaction.listFrom(json['reactions']),
        replyToText: json['replyToText'],
        replyToSenderName: json['replyToSenderName'],
        groupedAttachments: (json['groupedAttachments'] as List<dynamic>?)
                ?.map((e) => AttachmentItem.fromJson(e))
                .toList() ??
            [],
        isEdited: json['isEdited'] == true,
        isSystem: json['isSystem'] == true || json['isSystem'] == 1,
        systemEvent: json['systemEvent'],
        editedAt: json['editedAt'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(json['editedAt']),
      );

  /// Create ChatMessage from API response.
  ///
  /// A uuid alone does not identify a person: the same device id exists under
  /// both appTypes when one phone has both apps installed, so "mine" is the
  /// `(senderId, senderAppType)` pair — matching how mentions and reactions
  /// already compare identity.
  static ChatMessage fromApiResponse(
    Map<String, dynamic> json,
    String currentUserID, {
    int currentAppType = FirebaseApiService.appType,
  }) {
    final senderID = json['senderId'] ?? '';
    final senderAppType = ChatContact.parseAppType(
      json['senderAppType'],
      fallback: currentAppType,
    );
    final isMe = senderID == currentUserID && senderAppType == currentAppType;

    String? attachmentUrl;
    String? attachmentType;
    String? fileType;
    String? fileName;

    final attachment = json['attachment'] as Map<String, dynamic>?;
    if (attachment != null) {
      attachmentUrl = attachment['url'] as String?;
      attachmentType = attachment['type'] as String?;
      fileName = attachment['filename'] as String?;
      final mime = attachmentType ?? '';
      fileType = mime.startsWith('image/') ? 'image' : 'document';
    }

    return ChatMessage(
      id: json['id'] ?? json['messageUuid'],
      text: json['text'] ?? '',
      isMe: isMe,
      timestamp: DateTime.parse(json['timestamp']).toLocal(),
      apiMessageId: json['messageUuid'],
      apiChatId: json['chatUuid'],
      isRead: json['read'] == 1,
      attachmentUrl: attachmentUrl,
      attachmentType: attachmentType,
      fileType: fileType,
      fileName: fileName,
      senderId: senderID.toString().isEmpty ? null : senderID.toString(),
      senderName: json['senderName'] as String?,
      // The backend sends these as 1/0 on some rows and true/false on others.
      isForwarded: json['isForwarded'] == true || json['isForwarded'] == 1,
      forwardedFromSenderName: json['forwardedFromSenderName'] as String?,
      // Null on every message that is not a reply.
      replyToMessageId: json['replyToMessageId'] as String?,
      replyToText: json['replyToText'] as String?,
      replyToSenderName: json['replyToSenderName'] as String?,
      mentions: MessageMention.listFrom(json['mentions']),
      reactions: MessageReaction.listFrom(json['reactions']),
      // As with isForwarded, this arrives as 1/0 on some rows.
      isEdited: json['isEdited'] == true || json['isEdited'] == 1,
      editedAt: _parseTimestamp(json['editedAt']),
      // Same 1/0-or-boolean tolerance. `systemEvent` names which change it
      // narrates (member_added, group_renamed, …); `text` is the sentence the
      // backend already phrased for display.
      isSystem: json['isSystem'] == true || json['isSystem'] == 1,
      systemEvent: json['systemEvent'] as String?,
    );
  }

  /// A nullable ISO timestamp from the API. A malformed one is treated as
  /// absent rather than taking out the whole message list.
  static DateTime? _parseTimestamp(dynamic raw) {
    if (raw is! String || raw.isEmpty) return null;
    return DateTime.tryParse(raw)?.toLocal();
  }

  // ---------------------------------------------------------------------------
  // Group consecutive same-sender image messages (same upload batch) into a
  // single ChatMessage with groupedAttachments. Call after building the list.
  // ---------------------------------------------------------------------------
  static List<ChatMessage> groupImageMessages(List<ChatMessage> messages) {
    final result = <ChatMessage>[];
    int i = 0;

    while (i < messages.length) {
      final msg = messages[i];

      if (!msg.isSystem &&
          msg.fileType == 'image' &&
          msg.attachmentUrl != null) {
        final group = <AttachmentItem>[
          AttachmentItem(
            url: msg.attachmentUrl,
            fileName: msg.fileName,
            mimeType: msg.attachmentType,
            messageId: msg.apiMessageId,
          ),
        ];

        // Collect consecutive image msgs from same sender within 30 seconds
        int j = i + 1;
        while (j < messages.length) {
          final next = messages[j];
          final sameWindow =
              next.timestamp.difference(msg.timestamp).abs() <
                  const Duration(seconds: 30);
          if (!next.isSystem &&
              next.fileType == 'image' &&
              next.attachmentUrl != null &&
              next.isMe == msg.isMe &&
              sameWindow) {
            group.add(AttachmentItem(
              url: next.attachmentUrl,
              fileName: next.fileName,
              mimeType: next.attachmentType,
              messageId: next.apiMessageId,
            ));
            j++;
          } else {
            break;
          }
        }

        result.add(ChatMessage(
          id: msg.id,
          text: '',
          isMe: msg.isMe,
          timestamp: msg.timestamp,
          apiMessageId: msg.apiMessageId,
          apiChatId: msg.apiChatId,
          isRead: msg.isRead,
          senderId: msg.senderId,
          senderName: msg.senderName,
          isForwarded: msg.isForwarded,
          forwardedFromSenderName: msg.forwardedFromSenderName,
          replyToMessageId: msg.replyToMessageId,
          replyToText: msg.replyToText,
          replyToSenderName: msg.replyToSenderName,
          mentions: msg.mentions,
          reactions: msg.reactions,
          isEdited: msg.isEdited,
          editedAt: msg.editedAt,
          groupedAttachments: group,
        ));
        i = j;
      } else {
        result.add(msg);
        i++;
      }
    }

    return result;
  }
}
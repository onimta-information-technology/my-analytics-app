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

class ChatMessage {
  final String id;
  final String text;
  final bool isMe;
  final DateTime timestamp;
  final String? apiMessageId;
  final String? apiChatId;
  final bool? isRead;

  // Single-attachment fields (kept for backwards compat)
  final String? filePath;
  final String? fileType;
  final String? fileName;
  final String? attachmentUrl;
  final String? attachmentType;

  // Multi-attachment: when non-empty, render as image grid
  final List<AttachmentItem> groupedAttachments;

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
    List<AttachmentItem>? groupedAttachments,
  }) : groupedAttachments = groupedAttachments ?? const [];

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
    List<AttachmentItem>? groupedAttachments,
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
        groupedAttachments: groupedAttachments ?? this.groupedAttachments,
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
        'groupedAttachments':
            groupedAttachments.map((a) => a.toJson()).toList(),
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
        groupedAttachments: (json['groupedAttachments'] as List<dynamic>?)
                ?.map((e) => AttachmentItem.fromJson(e))
                .toList() ??
            [],
      );

  /// Create ChatMessage from API response.
  static ChatMessage fromApiResponse(
    Map<String, dynamic> json,
    String currentUserID,
  ) {
    final senderID = json['senderId'] ?? '';
    final isMe = senderID == currentUserID;

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
    );
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

      if (msg.fileType == 'image' && msg.attachmentUrl != null) {
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
          if (next.fileType == 'image' &&
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
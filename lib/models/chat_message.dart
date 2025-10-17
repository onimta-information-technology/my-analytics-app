class ChatMessage {
  final String id;
  final String text;
  final bool isMe;
  final DateTime timestamp;
  final String? apiMessageId;
  final String? apiChatId;
  final String? filePath;
  final String? fileType; // 'image', 'document', etc.
  final String? fileName;
  final bool? isRead;

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
  });

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
  }) {
    return ChatMessage(
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
    );
  }

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
  );

  // Create ChatMessage from API response
  static ChatMessage fromApiResponse(
    Map<String, dynamic> json,
    String currentUserID,
  ) {
    final senderID = json['senderId'] ?? '';
    final isMe = senderID == currentUserID;

    return ChatMessage(
      id: json['id'] ?? json['messageUuid'],
      text: json['text'] ?? '',
      isMe: isMe,
      timestamp: DateTime.parse(json['timestamp']),
      apiMessageId: json['messageUuid'],
      apiChatId: json['chatUuid'],
      isRead: json['read'] == 1,
    );
  }
}

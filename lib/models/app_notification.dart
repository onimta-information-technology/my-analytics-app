/// A push notification that was received by the app and kept in local history.
///
/// Chat notifications are intentionally NOT stored here — they live in the
/// chat screens. Only non-chat notifications (guest bookings, announcements,
/// etc.) reach this model.
class AppNotification {
  final String id;
  final String title;
  final String body;
  final String msgType;
  final Map<String, String> data;
  final DateTime receivedAt;
  final bool isRead;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.msgType,
    required this.data,
    required this.receivedAt,
    this.isRead = false,
  });

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      title: title,
      body: body,
      msgType: msgType,
      data: data,
      receivedAt: receivedAt,
      isRead: isRead ?? this.isRead,
    );
  }

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      msgType: json['msgType']?.toString() ?? '',
      data: (json['data'] as Map?)?.map(
            (key, value) => MapEntry(key.toString(), value?.toString() ?? ''),
          ) ??
          <String, String>{},
      receivedAt:
          DateTime.tryParse(json['receivedAt']?.toString() ?? '') ??
          DateTime.now(),
      isRead: json['isRead'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'msgType': msgType,
      'data': data,
      'receivedAt': receivedAt.toIso8601String(),
      'isRead': isRead,
    };
  }
}

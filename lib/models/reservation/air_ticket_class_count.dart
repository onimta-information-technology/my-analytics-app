/// One cabin class booked on a ticket, together with how many seats are taken
/// in it. A ticket can carry several — e.g. Economy x2 plus Business x1 — so a
/// flight holds a list of these rather than a single class.
class AirTicketClassCount {
  final int id;
  final String name;

  /// Seats booked in this class. Always at least 1 — a class with no seats is
  /// simply not on the ticket.
  final int count;

  const AirTicketClassCount({
    required this.id,
    required this.name,
    this.count = 1,
  });

  AirTicketClassCount copyWith({int? id, String? name, int? count}) {
    return AirTicketClassCount(
      id: id ?? this.id,
      name: name ?? this.name,
      count: count ?? this.count,
    );
  }

  /// Accepts both our own payload keys and the flattened ones the back office
  /// uses for the single-class fields, so a row written either way reads back.
  factory AirTicketClassCount.fromJson(Map<String, dynamic> json) {
    final byLowerKey = <String, dynamic>{
      for (final entry in json.entries) entry.key.toLowerCase(): entry.value,
    };
    dynamic read(List<String> names) {
      for (final name in names) {
        final value = byLowerKey[name.toLowerCase()];
        if (value != null) return value;
      }
      return null;
    }

    return AirTicketClassCount(
      id: _toInt(read(['air_ticket_class', 'id', 'class_id'])),
      name: read(['air_ticket_class_name', 'name', 'type', 'class_name'])
              ?.toString() ??
          '',
      count: _toInt(read(['count', 'ticket_count', 'seat_count']), fallback: 1),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'air_ticket_class': id,
      'air_ticket_class_name': name,
      'count': count,
    };
  }

  /// The list off a flight payload. Anything that is not a usable row — no
  /// class picked, or a zero count — is dropped.
  static List<AirTicketClassCount> listFrom(dynamic value) {
    if (value is! List) return const [];
    final classes = <AirTicketClassCount>[];
    for (final item in value) {
      Map<String, dynamic>? map;
      if (item is Map<String, dynamic>) {
        map = item;
      } else if (item is Map) {
        map = item.map((k, v) => MapEntry(k.toString(), v));
      }
      if (map == null) continue;
      final entry = AirTicketClassCount.fromJson(map);
      if (entry.id == 0 || entry.count < 1) continue;
      classes.add(entry);
    }
    return classes;
  }

  /// "Economy x2, Business x1" — how a ticket's classes read on a card.
  static String summary(List<AirTicketClassCount> classes) {
    return classes
        .map((c) => c.count > 1 ? "${c.name} x${c.count}" : c.name)
        .join(', ');
  }

  static int _toInt(dynamic value, {int fallback = 0}) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim()) ?? fallback;
    return fallback;
  }

  @override
  bool operator ==(Object other) =>
      other is AirTicketClassCount &&
      other.id == id &&
      other.name == name &&
      other.count == count;

  @override
  int get hashCode => Object.hash(id, name, count);
}

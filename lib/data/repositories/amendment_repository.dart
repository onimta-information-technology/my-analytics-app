import 'package:ballys_reservation_app/data/services/api_service.dart';
import 'package:ballys_reservation_app/models/amendment_ballys.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';

/// Reads the raised amendments back from the two Ballys feeds.
///
/// Both endpoints answer flat: a `master` list plus child lists that reference
/// their parent by row id. This repository does the joining, so callers get one
/// [AmendmentBallys] per request with its rows already attached.
class AmendmentRepository {
  final ApiService apiService;

  AmendmentRepository(this.apiService);

  /// GET `{baseUrl}/AmendmentAir/Get` — every air ticket amendment.
  Future<List<AmendmentBallys>> getAirAmendments() async {
    return parseAirResponse(await apiService.get('AmendmentAir/Get'));
  }

  /// GET `{baseUrl}/AmendmentHotel/Get` — every hotel amendment.
  Future<List<AmendmentBallys>> getHotelAmendments() async {
    return parseHotelResponse(await apiService.get('AmendmentHotel/Get'));
  }

  /// Rebuilds the air feed: tickets under their master, and guests, classes
  /// and sectors under their ticket.
  static List<AmendmentBallys> parseAirResponse(Map<String, dynamic> response) {
    if (response['success'] != true) return [];

    // Children first, bucketed by the row they hang off.
    final guestsByTicket = _groupBy(
      _rows(response['guests']).map(AmendmentGuest.fromJson),
      (AmendmentGuest g) => g.parentRowId,
    );
    final classesByTicket = _groupBy(
      _rows(response['classes']).map(AmendmentTicketClass.fromJson),
      (AmendmentTicketClass c) => c.ticketRowId,
    );
    final sectorsByTicket = _groupBy(
      _rows(response['sectors']).map(AmendmentTicketSector.fromJson),
      (AmendmentTicketSector s) => s.ticketRowId,
    );

    final ticketsByMaster = <int, List<AmendmentAirTicket>>{};
    for (final json in _rows(response['tickets'])) {
      final rowId = (json['RowId'] as num?)?.toInt() ?? 0;
      final ticket = AmendmentAirTicket.fromJson(
        json,
        guests: guestsByTicket[rowId] ?? const [],
        classes: classesByTicket[rowId] ?? const [],
        sectors: sectorsByTicket[rowId] ?? const [],
      );
      ticketsByMaster.putIfAbsent(ticket.masterRowId, () => []).add(ticket);
    }

    return _rows(response['master'])
        .map(
          (json) => AmendmentBallys.fromJson(
            json,
            tickets:
                ticketsByMaster[(json['RowId'] as num?)?.toInt() ?? 0] ??
                const [],
          ),
        )
        .toList();
  }

  /// Rebuilds the hotel feed: rooms under their master, guests under their
  /// room.
  static List<AmendmentBallys> parseHotelResponse(
    Map<String, dynamic> response,
  ) {
    if (response['success'] != true) return [];

    final guestsByRoom = _groupBy(
      _rows(response['guests']).map(AmendmentGuest.fromJson),
      (AmendmentGuest g) => g.parentRowId,
    );

    final roomsByMaster = <int, List<AmendmentHotelRoom>>{};
    for (final json in _rows(response['rooms'])) {
      final rowId = (json['RowId'] as num?)?.toInt() ?? 0;
      final room = AmendmentHotelRoom.fromJson(
        json,
        guests: guestsByRoom[rowId] ?? const [],
      );
      roomsByMaster.putIfAbsent(room.masterRowId, () => []).add(room);
    }

    return _rows(response['master'])
        .map(
          (json) => AmendmentBallys.fromJson(
            json,
            rooms:
                roomsByMaster[(json['RowId'] as num?)?.toInt() ?? 0] ??
                const [],
          ),
        )
        .toList();
  }

  /// Moves one amendment to [status] ("Checked" / "Approved" / "Rejected").
  ///
  /// POSTs to the endpoint that matches the feed and the status —
  /// `AmendmentAir/UpdateChecked`, `AmendmentHotel/UpdateRejected` and so on.
  /// The row is addressed by its master row id, which is what the two feeds
  /// hang their tickets and rooms off.
  Future<AmendmentStatusResult> updateStatus({
    required AmendmentBallys amendment,
    required String status,
    required String remarks,
  }) async {
    final action = _actionSegment(status);
    if (action == null) {
      return AmendmentStatusResult(
        success: false,
        message: 'Unsupported amendment status: $status',
      );
    }

    final endpoint =
        '${amendment.isHotel ? 'AmendmentHotel' : 'AmendmentAir'}/$action';
    final actionedBy = await StorageUtil.getUserName() ?? '';

    final response = await apiService.post(endpoint, {
      'MasterRowId': amendment.rowId,
      'Remark': remarks,
      'By': actionedBy,
    });

    // The amendment endpoints answer `success`; the older insert endpoints
    // answer `Status`. Accept either, so one shape changing does not read as
    // a failed action.
    final success =
        response['success'] == true || response['Status'] == true;

    return AmendmentStatusResult(
      success: success,
      message: (response['Message'] ?? response['message'] ??
              response['statusMsg'])
          ?.toString(),
    );
  }

  /// The URL segment for [status], or null when it is not an action the API
  /// takes (`Pending` never gets posted).
  static String? _actionSegment(String status) {
    switch (status) {
      case 'Checked':
        return 'UpdateChecked';
      case 'Approved':
        return 'UpdateApproved';
      case 'Rejected':
        return 'UpdateRejected';
      default:
        return null;
    }
  }

  /// The feeds answer with a list, but send null when a table is empty.
  static List<Map<String, dynamic>> _rows(Object? value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  static Map<int, List<T>> _groupBy<T>(
    Iterable<T> items,
    int Function(T) keyOf,
  ) {
    final grouped = <int, List<T>>{};
    for (final item in items) {
      grouped.putIfAbsent(keyOf(item), () => []).add(item);
    }
    return grouped;
  }
}

/// Outcome of a check / approve / reject call.
class AmendmentStatusResult {
  final bool success;
  final String? message;

  const AmendmentStatusResult({required this.success, this.message});
}

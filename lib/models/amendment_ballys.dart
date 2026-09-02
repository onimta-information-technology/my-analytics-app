/// Models for the two amendment feeds — `AmendmentAir/Get` and
/// `AmendmentHotel/Get`.
///
/// Both endpoints answer with the same shape: a flat `master` list plus flat
/// child lists that point back at their parent by row id. [AmendmentBallys]
/// stitches those back into one object per amendment request, so the screens
/// never have to join rows themselves.
library;

/// One person an amendment row was raised for (`guests`).
class AmendmentGuest {
  final int rowId;

  /// `TicketRowId` on the air feed, `RoomRowId` on the hotel feed.
  final int parentRowId;
  final String bmNumber;
  final String guestName;

  const AmendmentGuest({
    required this.rowId,
    required this.parentRowId,
    required this.bmNumber,
    required this.guestName,
  });

  factory AmendmentGuest.fromJson(Map<String, dynamic> json) {
    return AmendmentGuest(
      rowId: _asInt(json['RowId']) ?? 0,
      parentRowId:
          _asInt(json['TicketRowId']) ?? _asInt(json['RoomRowId']) ?? 0,
      bmNumber: _asString(json['BMNumber']),
      guestName: _asString(json['GuestName']),
    );
  }
}

/// A cabin class asked for by a Cabin Upgrade ticket (`classes`).
class AmendmentTicketClass {
  final int rowId;
  final int ticketRowId;
  final int? classId;
  final String className;
  final int count;

  const AmendmentTicketClass({
    required this.rowId,
    required this.ticketRowId,
    this.classId,
    required this.className,
    required this.count,
  });

  factory AmendmentTicketClass.fromJson(Map<String, dynamic> json) {
    return AmendmentTicketClass(
      rowId: _asInt(json['RowId']) ?? 0,
      ticketRowId: _asInt(json['TicketRowId']) ?? 0,
      classId: _asInt(json['air_ticket_class']),
      className: _asString(json['air_ticket_class_name']),
      count: _asInt(json['count']) ?? 0,
    );
  }
}

/// A transit stop on a multi-sector route change (`sectors`).
class AmendmentTicketSector {
  final int rowId;
  final int ticketRowId;

  /// `DEPARTURE` or `RETURN` — which leg the stop belongs to.
  final String legType;
  final int seqNo;
  final String airportCode;
  final String cityName;
  final String airportName;
  final String country;
  final DateTime? sectorDate;

  const AmendmentTicketSector({
    required this.rowId,
    required this.ticketRowId,
    required this.legType,
    required this.seqNo,
    required this.airportCode,
    required this.cityName,
    required this.airportName,
    required this.country,
    this.sectorDate,
  });

  factory AmendmentTicketSector.fromJson(Map<String, dynamic> json) {
    return AmendmentTicketSector(
      rowId: _asInt(json['RowId']) ?? 0,
      ticketRowId: _asInt(json['TicketRowId']) ?? 0,
      legType: _asString(json['LegType']).toUpperCase(),
      seqNo: _asInt(json['SeqNo']) ?? 0,
      airportCode: _asString(json['AirportCode']),
      cityName: _asString(json['CityName']),
      airportName: _asString(json['AirportName']),
      country: _asString(json['Country']),
      sectorDate: _asDate(json['SectorDate']),
    );
  }

  bool get isDeparture => legType == 'DEPARTURE';
  bool get isReturn => legType == 'RETURN';

  /// "CMB — Colombo" style label, skipping whichever half is blank.
  String get label {
    final parts = [
      airportCode,
      cityName.isNotEmpty ? cityName : airportName,
    ].where((p) => p.isNotEmpty);
    return parts.join(' — ');
  }
}

/// One airport named by a route change (the `dep_from_*` / `ret_to_*` groups).
class AmendmentAirportRef {
  final String code;
  final String city;
  final String airport;
  final String country;

  const AmendmentAirportRef({
    required this.code,
    required this.city,
    required this.airport,
    required this.country,
  });

  /// Reads the four columns sharing [prefix] (e.g. `dep_from`).
  static AmendmentAirportRef? fromJson(
    Map<String, dynamic> json,
    String prefix,
  ) {
    final ref = AmendmentAirportRef(
      code: _asString(json['${prefix}_code']),
      city: _asString(json['${prefix}_city']),
      airport: _asString(json['${prefix}_airport']),
      country: _asString(json['${prefix}_country']),
    );
    return ref.isEmpty ? null : ref;
  }

  bool get isEmpty =>
      code.isEmpty && city.isEmpty && airport.isEmpty && country.isEmpty;

  String get label {
    final parts = [
      code,
      city.isNotEmpty ? city : airport,
    ].where((p) => p.isNotEmpty);
    return parts.join(' — ');
  }
}

/// One amended ticket (`tickets`), with the guests, classes and sectors that
/// hang off it.
class AmendmentAirTicket {
  final int rowId;
  final int masterRowId;
  final int ticketNo;
  final String departureRoute;
  final String returnRoute;

  /// Cancellation / Void / Exchange.
  final String amendmentCategory;

  /// The specific ask inside the category — "Date Change", "Void", …
  final String amendmentType;
  final String reason;
  final String additionalRemark;

  // Type-specific detail. Every field here is null/blank unless the ticket's
  // own amendment type asked for it.
  final DateTime? newArrivalDate;
  final DateTime? newDepartureDate;
  final String routeLeg;
  final bool isMultiSector;
  final String ticketValidityNote;
  final String refundMethod;
  final AmendmentAirportRef? departureFrom;
  final AmendmentAirportRef? departureTo;
  final AmendmentAirportRef? returnFrom;
  final AmendmentAirportRef? returnTo;

  final List<AmendmentGuest> guests;
  final List<AmendmentTicketClass> classes;
  final List<AmendmentTicketSector> sectors;

  const AmendmentAirTicket({
    required this.rowId,
    required this.masterRowId,
    required this.ticketNo,
    required this.departureRoute,
    required this.returnRoute,
    required this.amendmentCategory,
    required this.amendmentType,
    required this.reason,
    required this.additionalRemark,
    this.newArrivalDate,
    this.newDepartureDate,
    required this.routeLeg,
    required this.isMultiSector,
    required this.ticketValidityNote,
    required this.refundMethod,
    this.departureFrom,
    this.departureTo,
    this.returnFrom,
    this.returnTo,
    this.guests = const [],
    this.classes = const [],
    this.sectors = const [],
  });

  factory AmendmentAirTicket.fromJson(
    Map<String, dynamic> json, {
    List<AmendmentGuest> guests = const [],
    List<AmendmentTicketClass> classes = const [],
    List<AmendmentTicketSector> sectors = const [],
  }) {
    return AmendmentAirTicket(
      rowId: _asInt(json['RowId']) ?? 0,
      masterRowId: _asInt(json['MasterRowId']) ?? 0,
      ticketNo: _asInt(json['ticket_no']) ?? 0,
      departureRoute: _asString(json['departure_route']),
      returnRoute: _asString(json['return_route']),
      amendmentCategory: _asString(json['amendment_category']),
      amendmentType: _asString(json['amendment_type']),
      reason: _asString(json['reason']),
      additionalRemark: _asString(json['additional_remark']),
      newArrivalDate: _asDate(json['new_arrival_date']),
      newDepartureDate: _asDate(json['new_departure_date']),
      routeLeg: _asString(json['route_leg']),
      isMultiSector: json['is_multi_sector'] == true,
      ticketValidityNote: _asString(json['ticket_validity_note']),
      refundMethod: _asString(json['refund_method']),
      departureFrom: AmendmentAirportRef.fromJson(json, 'dep_from'),
      departureTo: AmendmentAirportRef.fromJson(json, 'dep_to'),
      returnFrom: AmendmentAirportRef.fromJson(json, 'ret_from'),
      returnTo: AmendmentAirportRef.fromJson(json, 'ret_to'),
      guests: guests,
      classes: classes,
      sectors: sectors,
    );
  }

  List<AmendmentTicketSector> get departureSectors =>
      sectors.where((s) => s.isDeparture).toList()
        ..sort((a, b) => a.seqNo.compareTo(b.seqNo));

  List<AmendmentTicketSector> get returnSectors =>
      sectors.where((s) => s.isReturn).toList()
        ..sort((a, b) => a.seqNo.compareTo(b.seqNo));

  bool get changesDeparture => departureFrom != null || departureTo != null;
  bool get changesReturn => returnFrom != null || returnTo != null;
}

/// One amended room (`rooms`) with the guests booked into it.
class AmendmentHotelRoom {
  final int rowId;
  final int masterRowId;
  final int roomNo;

  // What the room holds today.
  final int? hotelId;
  final String hotelName;
  final int? roomCategoryId;
  final String roomCategoryName;
  final int? roomTypeId;
  final String roomTypeName;
  final DateTime? arrivalDate;
  final DateTime? departureDate;
  final int guestCount;
  final int childrenCount;
  final int roomCount;

  /// Date Change / Extras / Hotel Change / Room Category / Occupancy /
  /// Early Check-in / Late Check-out …
  final String amendmentCategory;

  // What it moves to. Null means that half is unchanged.
  final DateTime? newArrivalDate;
  final DateTime? newDepartureDate;
  final String extras;
  final int? newHotelId;
  final String newHotelName;
  final int? newRoomCategoryId;
  final String newRoomCategoryName;
  final int? newRoomTypeId;
  final String newRoomTypeName;
  final int? newGuestCount;
  final int? newChildrenCount;
  final int? newRoomCount;

  final List<AmendmentGuest> guests;

  const AmendmentHotelRoom({
    required this.rowId,
    required this.masterRowId,
    required this.roomNo,
    this.hotelId,
    required this.hotelName,
    this.roomCategoryId,
    required this.roomCategoryName,
    this.roomTypeId,
    required this.roomTypeName,
    this.arrivalDate,
    this.departureDate,
    required this.guestCount,
    required this.childrenCount,
    required this.roomCount,
    required this.amendmentCategory,
    this.newArrivalDate,
    this.newDepartureDate,
    required this.extras,
    this.newHotelId,
    required this.newHotelName,
    this.newRoomCategoryId,
    required this.newRoomCategoryName,
    this.newRoomTypeId,
    required this.newRoomTypeName,
    this.newGuestCount,
    this.newChildrenCount,
    this.newRoomCount,
    this.guests = const [],
  });

  factory AmendmentHotelRoom.fromJson(
    Map<String, dynamic> json, {
    List<AmendmentGuest> guests = const [],
  }) {
    return AmendmentHotelRoom(
      rowId: _asInt(json['RowId']) ?? 0,
      masterRowId: _asInt(json['MasterRowId']) ?? 0,
      roomNo: _asInt(json['room_no']) ?? 0,
      hotelId: _asInt(json['hotel']),
      hotelName: _asString(json['hotel_name']),
      roomCategoryId: _asInt(json['room_category']),
      roomCategoryName: _asString(json['room_category_name']),
      roomTypeId: _asInt(json['room_type']),
      roomTypeName: _asString(json['room_type_name']),
      arrivalDate: _asDate(json['arrival_date']),
      departureDate: _asDate(json['departure_date']),
      guestCount: _asInt(json['guest_count']) ?? 0,
      childrenCount: _asInt(json['children_count']) ?? 0,
      roomCount: _asInt(json['room_count']) ?? 0,
      amendmentCategory: _asString(json['amendment_category']),
      newArrivalDate: _asDate(json['new_arrival_date']),
      newDepartureDate: _asDate(json['new_departure_date']),
      extras: _asString(json['extras']),
      newHotelId: _asInt(json['new_hotel']),
      newHotelName: _asString(json['new_hotel_name']),
      newRoomCategoryId: _asInt(json['new_room_category']),
      newRoomCategoryName: _asString(json['new_room_category_name']),
      newRoomTypeId: _asInt(json['new_room_type']),
      newRoomTypeName: _asString(json['new_room_type_name']),
      newGuestCount: _asInt(json['new_guest_count']),
      newChildrenCount: _asInt(json['new_children_count']),
      newRoomCount: _asInt(json['new_room_count']),
      guests: guests,
    );
  }
}

/// What the amendment was raised against — decides which child list is filled.
enum AmendmentKind { airTicket, hotel }

/// One amendment request: the `master` row plus its rebuilt children.
class AmendmentBallys {
  final int rowId;
  final String masterId;
  final String reservationNo;

  /// Raw `amendment_on` — "AirTicket" or "Hotel".
  final String amendmentOn;
  final String userName;
  final String deviceId;
  final DateTime? createdDate;

  /// Pending / Checked / Approved / Rejected.
  final String status;
  final String checkedRemark;
  final String checkedBy;
  final DateTime? checkedDate;
  final String rejectRemark;
  final String rejectedBy;
  final DateTime? rejectedDate;

  /// Filled for [AmendmentKind.airTicket]; empty otherwise.
  final List<AmendmentAirTicket> tickets;

  /// Filled for [AmendmentKind.hotel]; empty otherwise.
  final List<AmendmentHotelRoom> rooms;

  const AmendmentBallys({
    required this.rowId,
    required this.masterId,
    required this.reservationNo,
    required this.amendmentOn,
    required this.userName,
    required this.deviceId,
    this.createdDate,
    required this.status,
    required this.checkedRemark,
    required this.checkedBy,
    this.checkedDate,
    required this.rejectRemark,
    required this.rejectedBy,
    this.rejectedDate,
    this.tickets = const [],
    this.rooms = const [],
  });

  factory AmendmentBallys.fromJson(
    Map<String, dynamic> json, {
    List<AmendmentAirTicket> tickets = const [],
    List<AmendmentHotelRoom> rooms = const [],
  }) {
    return AmendmentBallys(
      rowId: _asInt(json['RowId']) ?? 0,
      masterId: _asString(json['master_id']),
      reservationNo: _asString(json['reservation_no']),
      amendmentOn: _asString(json['amendment_on']),
      userName: _asString(json['user_name']),
      deviceId: _asString(json['device_id']),
      createdDate: _asDate(json['Created_Date']),
      status: _asString(json['Status']).isEmpty
          ? 'Pending'
          : _asString(json['Status']),
      checkedRemark: _asString(json['CheckedRemark']),
      checkedBy: _asString(json['CheckedBy']),
      checkedDate: _asDate(json['CheckedDate']),
      rejectRemark: _asString(json['RejectRemark']),
      rejectedBy: _asString(json['RejectedBy']),
      rejectedDate: _asDate(json['RejectedDate']),
      tickets: tickets,
      rooms: rooms,
    );
  }

  AmendmentKind get kind => amendmentOn.toLowerCase().contains('hotel')
      ? AmendmentKind.hotel
      : AmendmentKind.airTicket;

  bool get isHotel => kind == AmendmentKind.hotel;

  /// "Air Ticket" / "Hotel" — what the card and detail header show.
  String get kindLabel => isHotel ? 'Hotel' : 'Air Ticket';

  /// How many rows the request carries, whichever type it is.
  int get lineCount => isHotel ? rooms.length : tickets.length;

  /// Everyone named across every row, de-duplicated by BM number + name.
  List<AmendmentGuest> get allGuests {
    final all = isHotel
        ? rooms.expand((r) => r.guests)
        : tickets.expand((t) => t.guests);
    final seen = <String>{};
    return all
        .where((g) => seen.add('${g.bmNumber}|${g.guestName}'))
        .toList(growable: false);
  }

  /// The distinct categories asked for, so a card can summarise the request
  /// without opening it.
  List<String> get categories {
    final all = isHotel
        ? rooms.map((r) => r.amendmentCategory)
        : tickets.map((t) => t.amendmentCategory);
    return all.where((c) => c.isNotEmpty).toSet().toList(growable: false);
  }

  /// Who actioned it, and when — the same slot the reservation card uses.
  String? get actionBy {
    switch (status) {
      case 'Rejected':
        return rejectedBy.isEmpty ? null : rejectedBy;
      case 'Checked':
      case 'Approved':
        return checkedBy.isEmpty ? null : checkedBy;
      default:
        return null;
    }
  }

  DateTime? get actionDate {
    switch (status) {
      case 'Rejected':
        return rejectedDate;
      case 'Checked':
      case 'Approved':
        return checkedDate;
      default:
        return null;
    }
  }

  String? get actionRemark {
    switch (status) {
      case 'Rejected':
        return rejectRemark.isEmpty ? null : rejectRemark;
      case 'Checked':
      case 'Approved':
        return checkedRemark.isEmpty ? null : checkedRemark;
      default:
        return null;
    }
  }
}

// ── JSON helpers ────────────────────────────────────────────────────────────
// The feeds send nulls freely and mix strings with numbers, so every read
// goes through one of these rather than a hard cast.

String _asString(Object? value) => value?.toString().trim() ?? '';

int? _asInt(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

DateTime? _asDate(Object? value) {
  if (value == null) return null;
  final text = value.toString().trim();
  if (text.isEmpty) return null;
  return DateTime.tryParse(text);
}

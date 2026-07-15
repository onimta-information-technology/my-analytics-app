import 'dart:convert';
import 'package:ballys_reservation_app/models/guest_reservation_entry.dart';
import 'package:ballys_reservation_app/models/reservation/flight_booking.dart';
import 'package:ballys_reservation_app/models/reservation/hotel_desc.dart';
import 'package:ballys_reservation_app/models/reservation/reservation_passport_image.dart';

class Reservation {
  int idNo;
  String reservNo;
  DateTime reservDate;
  String mid;
  String mName;
  int noOfNights;
  DateTime arrDate;
  DateTime depDate;
  String airticketReservationStatus;
  String remarks;
  String reqBy;
  DateTime insertDate;
  bool isApp;
  DateTime isAppTime;
  String? isAppBy;
  String requestStatus;
  String isAppRemarks;
  List<HotelDescip> hotelDescip;
  List<FlightBooking> airticketDescrip;
  String? lastEditBy;
  DateTime lastEditTime;
  String returnStatus;
  String? gRating;
  String? reservationnewnumber;

  /// Package amount as stored in the DB (varchar), e.g. `"IND 10,000"`.
  String? packageAmount;

  /// Currency the [packageAmount] is expressed in, e.g. `"IND"` / `"USD"`.
  /// Sent as `currency_type` on insert/update and returned by the API.
  String? currencyType;

  /// Per-stage audit trail returned by `Reservation_GetAllReservations`.
  /// Each workflow stage (Pending → Checked → Approved/Rejected) records who
  /// actioned it, when, and their remark. Fields are null when that stage has
  /// not happened yet (or on the legacy `fromJson` path).
  String? pendingBy;
  DateTime? pendingTime;

  String? checkedStatus;
  String? checkedBy;
  String? checkedRemark;
  DateTime? checkedTime;

  String? approvedStatus;
  String? approvedBy;
  String? approvedRemark;
  DateTime? approvedTime;

  String? rejectedStatus;
  String? rejectedBy;
  String? rejectedRemark;
  DateTime? rejectedTime;

  /// All guests attached to this reservation. A single reservation number can
  /// carry multiple guests; the reservations list shows one card while the
  /// detail view can expand to show every guest.
  List<GuestReservationEntry> guests;

  /// Passport images/PDFs returned by the API, each tagged with the owning
  /// guest's BM number via [ReservationPassportImage.guestBmNumber].
  List<ReservationPassportImage> passportImages;

  Reservation({
    required this.idNo,
    required this.reservNo,
    required this.reservDate,
    required this.mid,
    required this.mName,
    required this.noOfNights,
    required this.arrDate,
    required this.depDate,
    required this.airticketReservationStatus,
    required this.remarks,
    required this.reqBy,
    required this.insertDate,
    required this.isApp,
    required this.isAppTime,
    this.isAppBy,
    required this.requestStatus,
    required this.isAppRemarks,
    required this.hotelDescip,
    required this.airticketDescrip,
    this.lastEditBy,
    required this.lastEditTime,
    required this.returnStatus,
    required this.gRating,
    this.reservationnewnumber,
    this.packageAmount,
    this.currencyType,
    this.pendingBy,
    this.pendingTime,
    this.checkedStatus,
    this.checkedBy,
    this.checkedRemark,
    this.checkedTime,
    this.approvedStatus,
    this.approvedBy,
    this.approvedRemark,
    this.approvedTime,
    this.rejectedStatus,
    this.rejectedBy,
    this.rejectedRemark,
    this.rejectedTime,
    this.guests = const [],
    this.passportImages = const [],
  });

  /// The package amount as it should be shown to the user: currency + amount
  /// (e.g. `"IND 10,000"`). Falls back to the bare amount when the API returns
  /// no currency, and avoids doubling the prefix for legacy rows where the
  /// currency is already baked into the amount string.
  String get packageAmountDisplay {
    final amount = packageAmount?.trim() ?? '';
    final currency = currencyType?.trim() ?? '';
    if (amount.isEmpty) return '';
    if (currency.isEmpty) return amount;
    if (amount.toUpperCase().startsWith(currency.toUpperCase())) return amount;
    return '$currency $amount';
  }

  /// Who actioned the reservation into its current [requestStatus], picked
  /// from the matching per-stage audit field. Falls back to the legacy
  /// [isAppBy] for the old response shape.
  String? get actionBy {
    switch (requestStatus) {
      case 'Checked':
        return checkedBy ?? isAppBy;
      case 'Approved':
        return approvedBy ?? isAppBy;
      case 'Rejected':
        return rejectedBy ?? isAppBy;
      default:
        return isAppBy;
    }
  }

  /// When the reservation reached its current [requestStatus]. Null when the
  /// stage carries no timestamp (avoids showing a bogus "now").
  DateTime? get actionTime {
    switch (requestStatus) {
      case 'Checked':
        return checkedTime;
      case 'Approved':
        return approvedTime;
      case 'Rejected':
        return rejectedTime;
      default:
        return null;
    }
  }

  factory Reservation.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(String? date) =>
        date != null ? DateTime.parse(date) : null;

    List<HotelDescip> parseHotelDescip(String? jsonStr) {
      if (jsonStr == null || jsonStr.isEmpty) return [];
      try {
        return (jsonDecode(jsonStr) as List)
            .map((item) => HotelDescip.fromJson(item))
            .toList();
      } catch (e) {
      
        return [];
      }
    }

    List<FlightBooking> parseAirticketDescrip(String? jsonStr) {
      if (jsonStr == null || jsonStr.isEmpty) return [];
      try {
        return (jsonDecode(jsonStr) as List)
            .map((item) => FlightBooking.fromJson(item))
            .toList();
      } catch (e) {
       
        return [];
      }
    }

    return Reservation(
      idNo: json['Id_No'] ?? 0,
      reservNo: json['Reserv_No'] as String? ?? '',
      reservDate: parseDate(json['Reserv_Date']) ?? DateTime.now(),
      mid: json['MID'] as String? ?? '',
      mName: json['MNAME'] as String? ?? '',
      noOfNights: json['NoOfNights'] ?? 0,
      arrDate: parseDate(json['Arr_Date']) ?? DateTime.now(),
      depDate: parseDate(json['Dep_Date']) ?? DateTime.now(),
      airticketReservationStatus:
          json['Airticket_Reservation_Status'] as String? ?? '',
      remarks: json['Remarks'] as String? ?? '',
      reqBy: json['Req_By'] as String? ?? '',
      insertDate: parseDate(json['InsertDate']) ?? DateTime.now(),
      isApp: json['Is_App'] ?? false,
      isAppTime: parseDate(json['Is_App_Time']) ?? DateTime.now(),
      isAppBy: json['Is_App_By'], // Nullable field
      requestStatus: json['Request_Status'] as String? ?? '',
      isAppRemarks: json['Is_App_Remarks'] as String? ?? '',
      hotelDescip: parseHotelDescip(json['Hotel_Descip']),
      airticketDescrip: parseAirticketDescrip(json['Airticket_Descrip']),
      lastEditBy: json['Last_Edit_By'],
      lastEditTime: parseDate(json['Last_Edit_Time']) ?? DateTime.now(),
      returnStatus: json['ReturnStatus'] as String? ?? '',
      gRating: json['G_Rating'] as String? ?? '',
      reservationnewnumber: json['Manual_Reserv_No'] as String? ?? '',
      packageAmount: json['Package_Amount']?.toString(),
      currencyType:
          (json['Currency_Type'] ?? json['currency_type'])?.toString(),
    );
  }

  /// Maps a single item from the `Reservation_GetAllReservations` response
  /// (new flat structure with `room_details` / `air_ticket_details` lists)
  /// into a [Reservation]. The response carries no approval status, so
  /// callers classify these as pending.
  factory Reservation.fromReservationData(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic date) {
      if (date is String && date.isNotEmpty) {
        try {
          return DateTime.parse(date);
        } catch (_) {
          return null;
        }
      }
      return null;
    }

    int toInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    List<HotelDescip> parseRooms(dynamic list) {
      if (list is List) {
        return list
            .whereType<Map<String, dynamic>>()
            .map((item) => HotelDescip.fromJson(item))
            .toList();
      }
      return [];
    }

    List<FlightBooking> parseFlights(dynamic list) {
      if (list is List) {
        return list
            .whereType<Map<String, dynamic>>()
            .map((item) => FlightBooking.fromJson(item))
            .toList();
      }
      return [];
    }

    // Build one entry per guest, attaching only the rooms / air tickets whose
    // BMNumber matches that guest so the detail view can show each guest with
    // their own hotels and flights.
    List<GuestReservationEntry> parseGuests() {
      final guestList = json['guests'];
      if (guestList is! List) return [];

      final rooms = json['room_details'];
      final flights = json['air_ticket_details'];

      List<HotelDescip> roomsFor(String bm) {
        if (rooms is! List) return [];
        return rooms
            .whereType<Map<String, dynamic>>()
            .where((r) => r['BMNumber'] == bm)
            .map((r) => HotelDescip.fromJson(r))
            .toList();
      }

      List<FlightBooking> flightsFor(String bm) {
        if (flights is! List) return [];
        return flights
            .whereType<Map<String, dynamic>>()
            .where((f) => f['BMNumber'] == bm)
            .map((f) => FlightBooking.fromJson(f))
            .toList();
      }

      return guestList.whereType<Map<String, dynamic>>().map((g) {
        final bm = g['BMNumber'] as String? ?? '';
        return GuestReservationEntry(
          mid: bm,
          guestName: g['GuestName'] as String? ?? '',
          hotels: roomsFor(bm),
          flights: flightsFor(bm),
          arrivalDate: parseDate(g['ArrivalDate']),
          departureDate: parseDate(g['DepartureDate']),
          remarks: g['Remarks'] as String? ?? '',
          airTicketRequisition:
              g['HasAirTicketReservation'] == true ? 'Yes' : 'No',
        );
      }).toList();
    }

    List<ReservationPassportImage> parsePassportImages(dynamic list) {
      if (list is List) {
        return list
            .whereType<Map<String, dynamic>>()
            .map((item) => ReservationPassportImage.fromJson(item))
            .toList();
      }
      return [];
    }

    final hasAir = json['has_air_ticket_reservation'] == true;

    // Approval state as stored by the insert endpoint: "Pending" / "Checked" /
    // "Approved" / "Rejected". Blank rows fall back to Pending.
    final rawStatus = (json['reservation_status'] ??
            json['Reservation_Status'] ??
            json['ReservationStatus'])
        ?.toString()
        .trim();
    final reservationStatus =
        (rawStatus == null || rawStatus.isEmpty) ? 'Pending' : rawStatus;

    return Reservation(
      idNo: toInt(json['master_id']),
      reservNo: json['master_id']?.toString() ?? '',
      reservDate: parseDate(json['arrival_date']) ?? DateTime.now(),
      mid: json['bm_number'] as String? ?? '',
      mName: json['guest_name'] as String? ?? '',
      noOfNights: toInt(json['no_of_nights']),
      arrDate: parseDate(json['arrival_date']) ?? DateTime.now(),
      depDate: parseDate(json['departure_date']) ?? DateTime.now(),
      airticketReservationStatus: hasAir ? '1' : '0',
      remarks: json['remarks'] as String? ?? '',
      reqBy: json['user_name'] as String? ?? '',
      insertDate: parseDate(json['created_date']) ??
          parseDate(json['arrival_date']) ??
          DateTime.now(),
      isApp: reservationStatus == 'Approved',
      isAppTime: DateTime.now(),
      isAppBy: null,
      requestStatus: reservationStatus,
      isAppRemarks: '',
      hotelDescip: parseRooms(json['room_details']),
      airticketDescrip: parseFlights(json['air_ticket_details']),
      lastEditBy: null,
      lastEditTime: DateTime.now(),
      returnStatus: '',
      gRating: null,
      reservationnewnumber: json['manual_reserv_no'] as String? ?? '',
      packageAmount: json['package_amount']?.toString(),
      currencyType:
          (json['currency_type'] ?? json['Currency_Type'])?.toString(),
      pendingBy: json['pending_by'] as String?,
      pendingTime: parseDate(json['pending_time']),
      checkedStatus: json['checked_status'] as String?,
      checkedBy: json['checked_by'] as String?,
      checkedRemark: json['checked_remark'] as String?,
      checkedTime: parseDate(json['checked_time']),
      approvedStatus: json['approved_status'] as String?,
      approvedBy: json['approved_by'] as String?,
      approvedRemark: json['approved_remark'] as String?,
      approvedTime: parseDate(json['approved_time']),
      rejectedStatus: json['rejected_status'] as String?,
      rejectedBy: json['rejected_by'] as String?,
      rejectedRemark: json['rejected_remark'] as String?,
      rejectedTime: parseDate(json['rejected_time']),
      guests: parseGuests(),
      passportImages: parsePassportImages(json['passport_images']),
    );
  }

  Map<String, dynamic> toJson() {
    String? formatDate(DateTime? date) => date?.toIso8601String();

    return {
      'Id_No': idNo,
      'Reserv_No': reservNo,
      'Reserv_Date': formatDate(reservDate),
      'MID': mid,
      'MNAME': mName,
      'NoOfNights': noOfNights,
      'Arr_Date': formatDate(arrDate),
      'Dep_Date': formatDate(depDate),
      'Airticket_Reservation_Status': airticketReservationStatus,
      'Remarks': remarks,
      'Req_By': reqBy,
      'InsertDate': formatDate(insertDate),
      'Is_App': isApp,
      'Is_App_Time': formatDate(isAppTime),
      'Is_App_By': isAppBy,
      'Request_Status': requestStatus,
      'Is_App_Remarks': isAppRemarks,
      'Hotel_Descip': hotelDescip.map((item) => item.toJson()).toList(),
      'Airticket_Descrip':
          airticketDescrip.map((item) => item.toJson()).toList(),
      'Last_Edit_By': lastEditBy,
      'Last_Edit_Time': formatDate(lastEditTime),
      'ReturnStatus': returnStatus,
      'G_Rating': gRating,
      'Manual_Reserv_No': reservationnewnumber,
      'Package_Amount': packageAmount,
      'Currency_Type': currencyType,
    };
  }

  // copyWith({required String status}) {}
}

void printLargeBody(String body) {
  const chunkSize = 1024;
  for (int i = 0; i < body.length; i += chunkSize) {
  
  }
}

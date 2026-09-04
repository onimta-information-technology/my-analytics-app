import 'package:ballys_reservation_app/models/reservation/assigned_guest.dart';

/// One hotel booking inside a guest member on the quick reservation screen.
///
/// Lives outside the screen so the repository can turn a list of these into an
/// API payload without the screen having to hand over loose maps.
class QuickHotelEntry {
  String hotel;
  double? hotelId;
  String arrival;
  String departure;
  DateTime? arrivalDate;
  DateTime? departureDate;
  String noOfRooms;
  String noOfPax;

  /// Children sharing the room. Counted separately from [noOfPax], which stays
  /// the adult count.
  String noOfChildren;
  String roomType;
  int? roomTypeId;
  String roomCategory;
  int? roomCategoryId;

  /// Grading of the room category, e.g. "(Standard)".
  String hotelCategory;
  String eciLco;
  String mealPlan;
  String paymentBy;
  String remarks;
  String marketingPerson;
  String approvedBy;

  /// The guests this room is booked for, ticked on the assignment card. A room
  /// can go to one guest or to several, so it travels with the room rather than
  /// being implied by whoever was in the form when it was added.
  List<AssignedGuest> assignedGuests;

  QuickHotelEntry({
    this.hotel = '',
    this.hotelId,
    this.arrival = '',
    this.departure = '',
    this.arrivalDate,
    this.departureDate,
    this.noOfRooms = '1',
    this.noOfPax = '1',
    this.noOfChildren = '0',
    this.roomType = '',
    this.roomTypeId,
    this.roomCategory = '',
    this.roomCategoryId,
    this.hotelCategory = '',
    this.eciLco = 'NA',
    this.mealPlan = '',
    this.paymentBy = 'NA',
    this.remarks = '',
    this.marketingPerson = '',
    this.approvedBy = '',
    this.assignedGuests = const [],
  });

  Map<String, dynamic> toMap() => {
        'hotel': hotel,
        'arrival': arrival,
        'departure': departure,
        'noOfRooms': noOfRooms,
        'noOfPax': noOfPax,
        'noOfChildren': noOfChildren,
        'roomType': roomType,
        'roomCategory': roomCategory,
        'hotelCategory': hotelCategory,
        'eciLco': eciLco,
        'mealPlan': mealPlan,
        'paymentBy': paymentBy,
        'remarks': remarks,
        'marketingPerson': marketingPerson,
        'approvedBy': approvedBy,
      };

  Map<String, dynamic> toApiJson() {
    final arrDt = arrivalDate;
    final depDt = departureDate;
    final nights =
        (arrDt != null && depDt != null) ? depDt.difference(arrDt).inDays : 0;
    return {
      'hotel': hotelId,
      'hotel_name': hotel,
      'room_category': roomCategoryId,
      'room_category_name': roomCategory,
      'room_type': roomTypeId,
      'room_type_name': roomType,
      'guest_count': int.tryParse(noOfPax) ?? 1,
      'children_count': int.tryParse(noOfChildren) ?? 0,
      'room_count': int.tryParse(noOfRooms) ?? 1,
      'no_of_nights': nights,
      'arrival_date': arrDt?.toIso8601String(),
      'departure_date': depDt?.toIso8601String(),
      'selected_cost': 0.0,
      'cost_index': 0,
      'ec_lco_facility': eciLco,
      // `payment_by` is a reservation-level field now, so it is sent once at the
      // top of the body rather than repeated on every room.
      // Everyone the room is booked for, named inside the row itself — the same
      // shape HotelDescipBallys.toJson() sends.
      'assigned_guests': assignedGuests.map((g) => g.toJson()).toList(),
    };
  }
}

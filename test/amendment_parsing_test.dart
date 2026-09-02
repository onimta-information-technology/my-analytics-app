import 'dart:convert';

import 'package:ballys_reservation_app/data/repositories/amendment_repository.dart';
import 'package:ballys_reservation_app/models/amendment_ballys.dart';
import 'package:flutter_test/flutter_test.dart';

/// The two amendment feeds answer flat and are joined by row id, so these
/// exercise the join against a real response from each endpoint.
void main() {
  group('AmendmentAir/Get', () {
    final response =
        jsonDecode(_airResponse) as Map<String, dynamic>;
    final amendments = AmendmentRepository.parseAirResponse(response);

    test('one amendment per master row, tickets attached', () {
      expect(amendments.length, 6);
      expect(amendments.every((a) => a.tickets.length == 1), isTrue);
      expect(amendments.every((a) => a.kind == AmendmentKind.airTicket), isTrue);
    });

    test('guests, classes and sectors land on their own ticket', () {
      final cabinUpgrade = amendments.firstWhere((a) => a.rowId == 6);
      expect(cabinUpgrade.tickets.single.classes.single.className, 'Economy');
      expect(cabinUpgrade.allGuests.single.guestName, 'MR. SUNIL JUNEJA');

      final routeChange = amendments.firstWhere((a) => a.rowId == 5);
      final ticket = routeChange.tickets.single;
      expect(ticket.amendmentType, 'Route Change');
      expect(ticket.routeLeg, 'Return only');
      expect(ticket.isMultiSector, isTrue);
      expect(ticket.changesReturn, isTrue);
      expect(ticket.changesDeparture, isFalse);
      expect(ticket.returnFrom!.label, 'MWT — Moolawatana');
      expect(ticket.returnSectors.single.airportCode, 'CCJ');
      expect(ticket.departureSectors, isEmpty);
      expect(ticket.classes, isEmpty);
    });

    test('date change keeps both new dates', () {
      final ticket =
          amendments.firstWhere((a) => a.rowId == 4).tickets.single;
      expect(ticket.newDepartureDate, DateTime(2026, 12, 11));
      expect(ticket.newArrivalDate, DateTime(2026, 10, 6));
    });

    test('everything is pending until actioned', () {
      expect(amendments.every((a) => a.status == 'Pending'), isTrue);
      expect(amendments.every((a) => a.actionBy == null), isTrue);
      expect(amendments.every((a) => a.actionDate == null), isTrue);
    });
  });

  group('AmendmentHotel/Get', () {
    final response =
        jsonDecode(_hotelResponse) as Map<String, dynamic>;
    final amendments = AmendmentRepository.parseHotelResponse(response);

    test('rooms and guests land on their own master', () {
      expect(amendments.length, 3);
      expect(amendments.every((a) => a.kind == AmendmentKind.hotel), isTrue);

      final extras = amendments.firstWhere((a) => a.rowId == 4);
      final room = extras.rooms.single;
      expect(room.hotelName, 'Courtyard Marriott');
      expect(room.amendmentCategory, 'Extras');
      expect(room.extras, 'test');
      expect(room.guestCount, 2);
      expect(room.newRoomTypeName, isEmpty);
      expect(
        extras.allGuests.single.guestName,
        'MR. GHANSHYAM FATEHCHAND NIHALANI',
      );
    });

    test('a master with no matching room still parses', () {
      final orphan = AmendmentRepository.parseHotelResponse({
        'success': true,
        'master': [
          {'RowId': 99, 'master_id': '1', 'amendment_on': 'Hotel'},
        ],
        'rooms': null,
        'guests': null,
      });
      expect(orphan.single.rooms, isEmpty);
      expect(orphan.single.status, 'Pending');
      expect(orphan.single.lineCount, 0);
    });
  });
}

const _airResponse = '''
{
  "success": true,
  "master": [
    {"RowId": 6, "master_id": "1788333748545", "reservation_no": "1788333748545", "amendment_on": "AirTicket", "user_name": "Mr Anushka", "device_id": "72c966397cdc6f44", "Created_Date": "2026-09-02T15:33:00.19", "Status": "Pending", "CheckedRemark": null, "CheckedBy": null, "CheckedDate": null, "RejectRemark": null, "RejectedBy": null, "RejectedDate": null},
    {"RowId": 5, "master_id": "1788333748545", "reservation_no": "1788333748545", "amendment_on": "AirTicket", "user_name": "Mr Anushka", "device_id": "72c966397cdc6f44", "Created_Date": "2026-09-02T15:32:11.217", "Status": "Pending"},
    {"RowId": 4, "master_id": "1788333748545", "reservation_no": "1788333748545", "amendment_on": "AirTicket", "user_name": "Mr Anushka", "device_id": "72c966397cdc6f44", "Created_Date": "2026-09-02T15:31:35.03", "Status": "Pending"},
    {"RowId": 3, "master_id": "1788333748545", "reservation_no": "1788333748545", "amendment_on": "AirTicket", "user_name": "Mr Anushka", "device_id": "72c966397cdc6f44", "Created_Date": "2026-09-02T15:31:10.473", "Status": "Pending"},
    {"RowId": 2, "master_id": "1788333748545", "reservation_no": "1788333748545", "amendment_on": "AirTicket", "user_name": "Mr Anushka", "device_id": "72c966397cdc6f44", "Created_Date": "2026-09-02T15:30:13.737", "Status": "Pending"},
    {"RowId": 1, "master_id": "1786346086378", "reservation_no": "1786346086378", "amendment_on": "AirTicket", "user_name": "Mr Anushka", "device_id": "72c966397cdc6f44", "Created_Date": "2026-09-02T11:25:16.893", "Status": "Pending"}
  ],
  "tickets": [
    {"RowId": 1, "MasterRowId": 1, "ticket_no": 1, "departure_route": "HYD → CMB", "return_route": "CMB → BOM", "amendment_category": "Cancellation", "amendment_type": "Cancel and open ticket", "reason": "test", "additional_remark": "test", "ticket_validity_note": ""},
    {"RowId": 2, "MasterRowId": 2, "ticket_no": 1, "departure_route": "BOM → CMB", "return_route": "CMB → GOI", "amendment_category": "Void", "amendment_type": "Void", "reason": "test", "additional_remark": "test"},
    {"RowId": 3, "MasterRowId": 3, "ticket_no": 1, "departure_route": "BOM → CMB", "return_route": "CMB → GOI", "amendment_category": "Cancellation", "amendment_type": "Cancel & refund ticket", "reason": "test", "additional_remark": "test", "refund_method": "Original Form of Payment"},
    {"RowId": 4, "MasterRowId": 4, "ticket_no": 1, "departure_route": "BOM → CMB", "return_route": "CMB → GOI", "amendment_category": "Exchange", "amendment_type": "Date Change", "reason": "test", "additional_remark": "test", "new_arrival_date": "2026-10-06T00:00:00", "new_departure_date": "2026-12-11T00:00:00"},
    {"RowId": 5, "MasterRowId": 5, "ticket_no": 1, "departure_route": "BOM → CMB", "return_route": "CMB → GOI", "amendment_category": "Exchange", "amendment_type": "Route Change", "reason": "test", "additional_remark": "test", "route_leg": "Return only", "is_multi_sector": true, "ret_from_code": "MWT", "ret_from_city": "Moolawatana", "ret_from_airport": "Moolawatana", "ret_from_country": "Australia", "ret_to_code": "CCJ", "ret_to_city": "Kozhikode", "ret_to_airport": "Kozhikode Airport", "ret_to_country": "India"},
    {"RowId": 6, "MasterRowId": 6, "ticket_no": 1, "departure_route": "BOM → CMB", "return_route": "CMB → GOI", "amendment_category": "Exchange", "amendment_type": "Cabin Upgrade", "reason": "test", "additional_remark": "test"}
  ],
  "guests": [
    {"RowId": 1, "TicketRowId": 1, "BMNumber": "BM 11111", "GuestName": "MR. MAHESH KUMAR G."},
    {"RowId": 2, "TicketRowId": 2, "BMNumber": "BM 12121", "GuestName": "MR. SUNIL JUNEJA"},
    {"RowId": 3, "TicketRowId": 3, "BMNumber": "BM 12121", "GuestName": "MR. SUNIL JUNEJA"},
    {"RowId": 4, "TicketRowId": 4, "BMNumber": "BM 12121", "GuestName": "MR. SUNIL JUNEJA"},
    {"RowId": 5, "TicketRowId": 5, "BMNumber": "BM 12121", "GuestName": "MR. SUNIL JUNEJA"},
    {"RowId": 6, "TicketRowId": 6, "BMNumber": "BM 12121", "GuestName": "MR. SUNIL JUNEJA"}
  ],
  "classes": [
    {"RowId": 1, "TicketRowId": 6, "air_ticket_class": 1, "air_ticket_class_name": "Economy", "count": 1}
  ],
  "sectors": [
    {"RowId": 1, "TicketRowId": 5, "LegType": "RETURN", "SeqNo": 1, "AirportCode": "CCJ", "CityName": "Kozhikode", "AirportName": "Kozhikode Airport", "Country": "India", "SectorDate": "2026-09-04T00:00:00"}
  ]
}
''';

const _hotelResponse = '''
{
  "success": true,
  "master": [
    {"RowId": 6, "master_id": "1786444467678", "reservation_no": "1786444467678", "amendment_on": "Hotel", "user_name": "Mr Anushka", "device_id": "72c966397cdc6f44", "Created_Date": "2026-09-02T12:47:46.943", "Status": "Pending"},
    {"RowId": 5, "master_id": "1786444467678", "reservation_no": "1786444467678", "amendment_on": "Hotel", "user_name": "Mr Anushka", "device_id": "72c966397cdc6f44", "Created_Date": "2026-09-02T12:46:47.703", "Status": "Pending"},
    {"RowId": 4, "master_id": "1786444467678", "reservation_no": "1786444467678", "amendment_on": "Hotel", "user_name": "Mr Anushka", "device_id": "72c966397cdc6f44", "Created_Date": "2026-09-02T12:46:33.58", "Status": "Pending"}
  ],
  "rooms": [
    {"RowId": 1, "MasterRowId": 4, "room_no": 1, "hotel": 7, "hotel_name": "Courtyard Marriott", "room_category": 47, "room_category_name": "Ocean Vista Suite", "room_type": 138, "room_type_name": "Triple - BB", "arrival_date": "2026-08-11T16:04:00.003", "departure_date": "2026-08-19T00:00:00", "guest_count": 2, "children_count": 1, "room_count": 1, "amendment_category": "Extras", "extras": "test"},
    {"RowId": 2, "MasterRowId": 5, "room_no": 1, "hotel": 7, "hotel_name": "Courtyard Marriott", "room_category": 47, "room_category_name": "Ocean Vista Suite", "room_type": 138, "room_type_name": "Triple - BB", "arrival_date": "2026-08-11T16:04:00.003", "departure_date": "2026-08-19T00:00:00", "guest_count": 2, "children_count": 1, "room_count": 1, "amendment_category": "Extras", "extras": "test"},
    {"RowId": 3, "MasterRowId": 6, "room_no": 1, "hotel": 7, "hotel_name": "Courtyard Marriott", "room_category": 47, "room_category_name": "Ocean Vista Suite", "room_type": 138, "room_type_name": "Triple - BB", "arrival_date": "2026-08-11T16:04:00.003", "departure_date": "2026-08-19T00:00:00", "guest_count": 2, "children_count": 1, "room_count": 1, "amendment_category": "Early Check-in"}
  ],
  "guests": [
    {"RowId": 1, "RoomRowId": 1, "BMNumber": "BM 1651", "GuestName": "MR. GHANSHYAM FATEHCHAND NIHALANI"},
    {"RowId": 2, "RoomRowId": 2, "BMNumber": "BM 1651", "GuestName": "MR. GHANSHYAM FATEHCHAND NIHALANI"},
    {"RowId": 3, "RoomRowId": 3, "BMNumber": "BM 1651", "GuestName": "MR. GHANSHYAM FATEHCHAND NIHALANI"}
  ]
}
''';

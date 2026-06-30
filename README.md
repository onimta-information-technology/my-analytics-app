# ballys_reservation

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.


{
  "bm_number": "BM12345",
  "guest_name": "John Doe",
  "arrival_date": "25/06/2026",
  "departure_date": "28/06/2026",
  "no_of_nights": 3,
  "has_air_ticket_reservation": "1",
  "remarks": "Some additional details",
  "manual_reserv_no": "MAN-001",
  "package_amount": "1500",
  "sales_code": "SC001",
  "user_name": "john_doe",
  "device_id": "device-uuid-here",

  "room_details": [
    {
      "hotel": 1,
      "hotel_name": "Hotel Grand",
      "room_category": 2,
      "room_category_name": "Deluxe",
      "room_type": 3,
      "room_type_name": "King",
      "guest_count": 2,
      "children_count": 0,
      "room_count": 1,
      "no_of_nights": 3,
      "selected_date_range": "25/06/2026 ~ 28/06/2026",
      "arrival_date": "2026-06-25T00:00:00.000",
      "departure_date": "2026-06-28T00:00:00.000",
      "selected_cost": 500.00,
      "cost_index": 0,
      "ec_lco_facility": "ECL",
      "payment_by": "By Hamoos"
    }
  ],

  "air_ticket_details": [
    {
      "guest_count": 2,
      "air_ticket_class": 1,
      "air_ticket_class_name": "Economy",
      "air_line": "SriLankan Airlines",
      "contact_person": "test 1",
      "visa": true,
      "is_round_trip": true,
      "silk_route": 0,
      "airport_transportation": 0,
      "arrival_date": "2026-06-25T00:00:00.000",
      "departure_date": "2026-06-25T00:00:00.000",
      "selected_cost": 800.00,
      "airports": {
        "departure": {
          "d_from": {
            "df_AirportCode": "CMB",
            "df_Cityname": "Colombo",
            "df_AirportName": "Bandaranaike Intl Airport",
            "df_Country": "Sri Lanka"
          },
          "d_to": {
            "dt_AirportCode": "DXB",
            "dt_Cityname": "Dubai",
            "dt_AirportName": "Dubai International Airport",
            "dt_Country": "UAE"
          }
        },
        "return_": {
          "r_from": {
            "rf_AirportCode": "DXB",
            "rf_Cityname": "Dubai",
            "rf_AirportName": "Dubai International Airport",
            "rf_Country": "UAE"
          },
          "r_to": {
            "rt_AirportCode": "CMB",
            "rt_Cityname": "Colombo",
            "rt_AirportName": "Bandaranaike Intl Airport",
            "rt_Country": "Sri Lanka"
          }
        }
      }
    }
  ],

  "guests": [
    {
      "bmNumber": "BM12345",
      "guestName": "John Doe",
      "arrivalDate": "2026-06-25T00:00:00.000",
      "departureDate": "2026-06-28T00:00:00.000",
      "hasAirTicketReservation": "1",
      "remarks": "Some additional details",
      "roomDetails": [
        {
          "hotel": 1,
          "hotel_name": "Hotel Grand",
          "room_category": 2,
          "room_category_name": "Deluxe",
          "room_type": 3,
          "room_type_name": "King",
          "guest_count": 2,
          "children_count": 0,
          "room_count": 1,
          "no_of_nights": 3,
          "selected_date_range": "25/06/2026 ~ 28/06/2026",
          "arrival_date": "2026-06-25T00:00:00.000",
          "departure_date": "2026-06-28T00:00:00.000",
          "selected_cost": 500.00,
          "cost_index": 0,
          "ec_lco_facility": "ECL",
          "payment_by": "By Hamoos"
        }
      ],
      "airTicketDetails": [
        {
          "guest_count": 2,
          "air_ticket_class": 1,
          "air_ticket_class_name": "Economy",
          "air_line": "SriLankan Airlines",
          "contact_person": "test 1",
          "visa": true,
          "is_round_trip": true,
          "silk_route": 0,
          "airport_transportation": 0,
          "arrival_date": "2026-06-25T00:00:00.000",
          "departure_date": "2026-06-25T00:00:00.000",
          "selected_cost": 800.00,
          "airports": { "...": "..." }
        }
      ],
      "passport_images": [
        {
          "file_name": "john_passport.jpg",
          "is_pdf": false,
          "base64_data": "base64-encoded-string-here"
        }
      ]
    },
    {
      "bmNumber": "BM67890",
      "guestName": "Jane Smith",
      "arrivalDate": "2026-06-25T00:00:00.000",
      "departureDate": "2026-06-28T00:00:00.000",
      "hasAirTicketReservation": "0",
      "remarks": "",
      "roomDetails": [ { "...": "..." } ],
      "airTicketDetails": [],
      "passport_images": [
        {
          "file_name": "jane_passport.pdf",
          "is_pdf": true,
          "base64_data": "base64-encoded-string-here"
        }
      ]
    }
  ]
}

class AirTicketWarning {
  final String existingMasterId;
  final String existingBmNumber;
  final String existingAirLine;
  final String existingDepartureFrom;
  final String existingDepartureTo;
  final String existingReturnFrom;
  final String existingReturnTo;
  final String existingArrivalDate;
  final String existingDepartureDate;

  const AirTicketWarning({
    required this.existingMasterId,
    required this.existingBmNumber,
    required this.existingAirLine,
    required this.existingDepartureFrom,
    required this.existingDepartureTo,
    required this.existingReturnFrom,
    required this.existingReturnTo,
    required this.existingArrivalDate,
    required this.existingDepartureDate,
  });

  factory AirTicketWarning.fromJson(Map<String, dynamic> json) {
    String value(String key) => json[key]?.toString().trim() ?? '';

    return AirTicketWarning(
      existingMasterId: value('existing_master_id'),
      existingBmNumber: value('existing_bm_number'),
      existingAirLine: value('existing_air_line'),
      existingDepartureFrom: value('existing_departure_from'),
      existingDepartureTo: value('existing_departure_to'),
      existingReturnFrom: value('existing_return_from'),
      existingReturnTo: value('existing_return_to'),
      existingArrivalDate: value('existing_arrival_date'),
      existingDepartureDate: value('existing_departure_date'),
    );
  }
}

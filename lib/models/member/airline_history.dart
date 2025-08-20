class AirlineHistory {
  final String resNo;
  final String arrivalDate;
  final String departureDate;
  final String requestBy;
  final String approvedBy;
  final String airpotDrop;
  final String marketinPerson;
  final String airLine;
  final String travelClass;
  final double cost;
  final String sector;
  final String route01;
  final String route02;
  final String route03;
  final String remarks;
  final String remarks2;

  AirlineHistory({
    required this.resNo,
    required this.arrivalDate,
    required this.departureDate,
    required this.requestBy,
    required this.approvedBy,
    required this.airpotDrop,
    required this.marketinPerson,
    required this.airLine,
    required this.travelClass,
    required this.cost,
    required this.sector,
    required this.route01,
    required this.route02,
    required this.route03,
    required this.remarks,
    required this.remarks2,
  });

  factory AirlineHistory.fromJson(Map<String, dynamic> json) {
    return AirlineHistory(
      resNo: json['Res_No'],
      arrivalDate: json['ArrivalDate'],
      departureDate: json['DepartureDate'],
      requestBy: json['RequestBy'],
      approvedBy: json['ApprovedBy'],
      airpotDrop: json['AirpotDrop'],
      marketinPerson: json['MarketinPerson'],
      airLine: json['AirLine'],
      travelClass: json['Class'],
      cost: json['Cost'],
      sector: json['Sector'],
      route01: json['Route01'],
      route02: json['Route02'],
      route03: json['Route03'],
      remarks: json['Remarks'],
      remarks2: json['Remarks2'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Res_No': resNo,
      'ArrivalDate': arrivalDate,
      'DepartureDate': departureDate,
      'RequestBy': requestBy,
      'ApprovedBy': approvedBy,
      'AirpotDrop': airpotDrop,
      'MarketinPerson': marketinPerson,
      'AirLine': airLine,
      'Class': travelClass,
      'Cost': cost,
      'Sector': sector,
      'Route01': route01,
      'Route02': route02,
      'Route03': route03,
      'Remarks': remarks,
      'Remarks2': remarks2,
    };
  }
}

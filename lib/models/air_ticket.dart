class AirTicket {
  final String mid;
  final String? mname;
  final DateTime? lvd;
  final String reservNo;
  final DateTime arrDate;
  final DateTime depDate;
  final double tktCost;
  final String airLine;
  final String cls;
  final String sector;
  final String remarks;
  final String visitStatus; 
  final String requestBy;
  final String approvedBy;
  final String mktPerson;

  AirTicket({
    required this.mid,
    this.mname,
    this.lvd,
    required this.reservNo,
    required this.arrDate,
    required this.depDate,
    required this.tktCost,
    required this.airLine,
    required this.cls,
    required this.sector,
    required this.remarks,
    required this.visitStatus,
    required this.requestBy,
    required this.approvedBy,
    required this.mktPerson,
  });

  factory AirTicket.fromJson(Map<String, dynamic> json) {
    return AirTicket(
      mid: json['MID']?.toString() ?? '',
      mname: json['MNAME']?.toString(),
      lvd: json['LVD'] != null ? DateTime.tryParse(json['LVD'].toString()) : null,
      reservNo: json['Reserv_No']?.toString() ?? '',
      arrDate: DateTime.tryParse(json['Arr_Date']?.toString() ?? '') ?? DateTime.now(),
      depDate: DateTime.tryParse(json['Dep_Date']?.toString() ?? '') ?? DateTime.now(),
      tktCost: (json['Tkt_Cost'] as num?)?.toDouble() ?? 0.0,
      airLine: json['AirLine']?.toString().trim() ?? '',
      cls: json['Class']?.toString() ?? '',
      sector: json['Sector']?.toString() ?? '',
      remarks: json['Remarks']?.toString() ?? '',
      visitStatus: json['Visit_Status']?.toString() ?? 'NO',
      requestBy: json['RequestBy']?.toString() ?? '',
      approvedBy: json['ApprovedBy']?.toString() ?? '',
      mktPerson: json['Mkt_Person']?.toString() ?? '',
    );
  }

  bool get isPending => visitStatus.toUpperCase() == 'PENDING';
  bool get isVisited => visitStatus.toUpperCase() == 'YES';
  bool get isNotVisited => visitStatus.toUpperCase() == 'NO';
}
class DailyWalkingGuest {
  final String mId;
  final String mname;
  final String country;
  final String mgroup;
  final String gName;
  final String phone;
  final String rdt;
  final String dateRemark;
  final double dlt;
  final int batchId;
  final double adt;
  final String menImage2;

  DailyWalkingGuest({
    required this.mId,
    required this.mname,
    required this.country,
    required this.mgroup,
    required this.gName,
    required this.phone,
    required this.rdt,
    required this.dateRemark,
    required this.dlt,
    required this.batchId,
    required this.adt,
    required this.menImage2,
  });

  factory DailyWalkingGuest.fromJson(Map<String, dynamic> json) {
    return DailyWalkingGuest(
      mId: json['MID'],
      mname: json['MName'],
      country: json['Country'],
      mgroup: json['mGroup'],
      gName: json['GName'],
      phone: json['Phone'],
      rdt: json['rdt'],
      dateRemark: json['Date_Remark'],
      dlt: (json['dtl'] ?? 0).toDouble(),
      batchId: json['batch_id'] ?? 0,
      adt: (json['adt'] ?? 0).toDouble(),
      menImage2: json['MemImage2'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'MID': mId,
      'MName': mname,
      'Country': country,
      'mGroup': mgroup,
      'GName': gName,
      'Phone': phone,
      'rdt': rdt,
      'Date_Remark': dateRemark,
      'dtl': dlt,
      'batch_id': batchId,
      'adt': adt,
      'MemImage2': menImage2,
    };
  }
}

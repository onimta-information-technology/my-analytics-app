class Birthday {
  final String mid;
  final String mname;
  final String country;
  final DateTime bDate;
  final String bdt;
  final int age;
  final String gRating;
  final String msg;
  final String msg1;
  final DateTime lvd;
  final String gift;
  final String? gName;
  final String? mobile;
  final String? mGroup;

  Birthday({
    required this.mid,
    required this.mname,
    required this.country,
    required this.bDate,
    required this.bdt,
    required this.age,
    required this.gRating,
    required this.msg,
    required this.msg1,
    required this.lvd,
    required this.gift,
    this.gName,
    this.mobile,
    this.mGroup,
  });

  static String _str(dynamic v) => v == null ? '' : v.toString();

  static int _int(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString().trim()) ?? 0;
  }

  static DateTime _date(dynamic v) {
    if (v == null) return DateTime.now();
    if (v is DateTime) return v;
    final s = v.toString().trim();
    if (s.isEmpty) return DateTime.now();
    return DateTime.tryParse(s) ?? DateTime.now();
  }

  factory Birthday.fromJson(Map<String, dynamic> json) {
    return Birthday(
      mid: _str(json['MID']),
      mname: _str(json['MNAME']),
      country: _str(json['Country']),
      bDate: _date(json['BDate']),
      bdt: _str(json['BDT']),
      age: _int(json['age']),
      gRating: _str(json['G_Rating']),
      msg: _str(json['MSG']),
      msg1: _str(json['MSG1']),
      lvd: _date(json['LVD']),
      gift: _str(json['GIFT']),
      gName: json['GName']?.toString(),
      mobile: json['Mobile']?.toString(),
      mGroup: json['mGroup']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'MID': mid,
      'MNAME': mname,
      'Country': country,
      'BDate': bDate.toIso8601String(),
      'BDT': bdt,
      'age': age,
      'G_Rating': gRating,
      'MSG': msg,
      'MSG1': msg1,
      'LVD': lvd.toIso8601String(),
      'GIFT': gift,
      'GName': gName,
      'Mobile': mobile,
      'mGroup': mGroup,
    };
  }
}

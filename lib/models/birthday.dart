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
  });

  factory Birthday.fromJson(Map<String, dynamic> json) {
    return Birthday(
      mid: json['MID'],
      mname: json['MNAME'],
      country: json['Country'],
      bDate: DateTime.parse(json['BDate']),
      bdt: json['BDT'],
      age: json['age'],
      gRating: json['G_Rating'],
      msg: json['MSG'],
      msg1: json['MSG1'],
      lvd: DateTime.parse(json['LVD']),
      gift: json['GIFT'],
      gName: json['GName'],
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
    };
  }
}

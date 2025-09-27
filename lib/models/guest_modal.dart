class Guest {
  final String mid;
  final String memberName;
  final String country;
  final String lastVisitDate;
  final int age;
  final String? gRating;
  final String? mGroup;
  final String? gName;
  String? memImage2;
  String? gift;
  double? mDrop;
  String? mobile;

  Guest({
    required this.mid,
    required this.memberName,
    required this.country,
    required this.lastVisitDate,
    required this.age,
    required this.gRating,
    required this.mGroup,
    required this.gName,
    this.memImage2,
    this.gift,
    this.mDrop,
    this.mobile,
  });

  Guest.withGift({required this.mid, required this.memberName})
    : country = '',
      lastVisitDate = '1970-01-01',
      age = 0,
      gRating = null,
      mGroup = null,
      gName = null,
      memImage2 = null,
      gift = null,
      mDrop = null;

  Guest copyWith({String? memImage2}) {
    return Guest(
      mid: mid,
      memberName: memberName,
      country: country,
      lastVisitDate: lastVisitDate,
      age: age,
      gRating: gRating,
      mGroup: mGroup,
      gName: gName,
      memImage2: memImage2 ?? this.memImage2,
      gift: gift ?? gift,
      mDrop: mDrop ?? mDrop,
      mobile: mobile ?? mobile,
    );
  }

  // factory Guest.fromJson(Map<String, dynamic> json) {
  //   return Guest(
  //     mid: json['MID'],
  //     memberName: json['MName'],
  //     country: json['COUNTRY'],
  //     lastVisitDate: json['LVD'],
  //     age: json['AGE'],
  //     gRating: json['G_Rating'],
  //     mGroup: json['mGroup'],
  //     gName: json['GName'],
  //     memImage2: json['MemImage2'],
  //     gift: json['GIFT'],
  //     mDrop: json['MDROP'],
  //   );
  // }


  factory Guest.fromJson(Map<String, dynamic> json) {
    String? getValue(List<String> keys) {
      for (var key in keys) {
        if (json.containsKey(key) && json[key] != null) {
          return json[key].toString();
        }
      }
      return null;
    }

    return Guest(
      mid: getValue(['MID']) ?? '',
      memberName: getValue(['MName', 'MNAME', 'MNane']) ?? '',
      country: getValue(['COUNTRY']) ?? '',
      lastVisitDate: getValue(['LVD']) ?? '1970-01-01',
      age: int.tryParse(getValue(['AGE']) ?? '0') ?? 0,
      gRating: getValue(['G_Rating']),
      mGroup: getValue(['mGroup']),
      gName: getValue(['GName']),
      memImage2: getValue(['MemImage2']),
      gift: getValue(['GIFT']),
      mDrop: double.tryParse(getValue(['MDROP']) ?? '0'),
     // mobile: getValue(['Mobile', 'MOBILE']),
    );
  }
  void updateWith({String? newMemImage2}) {
    if (newMemImage2 != null) {
      memImage2 = newMemImage2;
    }
  }
}

Map<String, List<Guest>> groupByMGroup(List<Guest> guests) {
  Map<String, List<Guest>> groupedData = {};

  for (var guest in guests) {
    if (guest.mGroup != null) {
      if (!groupedData.containsKey(guest.mGroup)) {
        groupedData[guest.mGroup!] = [];
      }
      // if (guest.mid != '') {
      groupedData[guest.mGroup!]!.add(guest);
      // }
    }
  }

  var sortedGroupedData = Map.fromEntries(
    groupedData.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length)),
  );

  return sortedGroupedData;
}

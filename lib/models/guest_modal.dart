class Guest {
  final String mid;
  final String memberName;
  final String country;
  final String lastVisitDate;
  final int age;
  final String? gRating;
  final String? mGroup;
  final String? gName;
  final int? rc;
  String? memImage2;
  String? gift;
  double? mDrop;
  String? mobile;
  String? categoryCode;

  Guest({
    required this.mid,
    required this.memberName,
    required this.country,
    required this.lastVisitDate,
    required this.age,
    required this.gRating,
    required this.mGroup,
    required this.gName,
    this.rc,
    this.memImage2,
    this.gift,
    this.mDrop,
    this.mobile,
    this.categoryCode,
  });

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
      rc: rc,
      memImage2: memImage2 ?? this.memImage2,
      gift: gift ?? this.gift,
      mDrop: mDrop ?? this.mDrop,
      mobile: mobile ?? this.mobile,
      categoryCode: categoryCode,
    );
  }

  factory Guest.fromJson(Map<String, dynamic> json) {
    // Build a lowercase-key map once for case-insensitive lookup.
    // This fixes the bug where yesterday's API returns "country" (lowercase)
    // while today's returns "COUNTRY" (uppercase), causing empty country fields
    // and all guests falling into the 'Unknown' bucket in groupByCountry().
    final lowerJson = {
      for (final e in json.entries) e.key.toLowerCase(): e.value
    };

    String? getValue(List<String> keys) {
      for (final key in keys) {
        final v = lowerJson[key.toLowerCase()];
        if (v != null) return v.toString();
      }
      return null;
    }

    return Guest(
      mid: getValue(['MID']) ?? '',
      memberName: getValue(['MName', 'MNAME', 'MNane']) ?? '',
      country: getValue(['COUNTRY']) ?? '',
      lastVisitDate: getValue(['LVD']) ?? '',
      age: int.tryParse(getValue(['AGE']) ?? '0') ?? 0,
      gRating: getValue(['G_Rating', 'G_RATING']),
      mGroup: getValue(['mGroup', 'MGROUP']),
      gName: getValue(['GName', 'GNAME']),
      rc: int.tryParse(getValue(['RC']) ?? ''),
      memImage2: getValue(['MemImage2', 'MEMIMAGE2']),
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

/// Groups guests by their mGroup code, sorted by count descending.
/// Used for: Today/Yesterday/Monthly count boxes (admin level 1),
/// and the OTHER Marketing slice in the pie chart.
Map<String, List<Guest>> groupByMGroup(List<Guest> guests) {
  final Map<String, List<Guest>> groupedData = {};
  for (var guest in guests) {
    if (guest.mGroup != null) {
      if (!groupedData.containsKey(guest.mGroup)) {
        groupedData[guest.mGroup!] = [];
      }
      groupedData[guest.mGroup!]!.add(guest);
    }
  }
  final sortedGroupedData = Map.fromEntries(
    groupedData.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length)),
  );
  return sortedGroupedData;
}
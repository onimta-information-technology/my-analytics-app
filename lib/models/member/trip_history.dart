import 'dart:convert';

class DTLDesc {
  final String gameType;
  final String gDate;
  final double dtl;

  DTLDesc({required this.gameType, required this.gDate, required this.dtl});

  factory DTLDesc.fromJson(Map<String, dynamic> json) {
    return DTLDesc(
      gameType: json['Game_Type'],
      gDate: json['G_Date'],
      dtl: (json['DTL'] as num).toDouble(),
    );
  }
  Map<String, dynamic> toJson() {
    return {'Game_Type': gameType, 'G_Date': gDate, 'DTL': dtl};
  }
}

class ExGift {
  final String giftType;
  final int amount;
  final String remark;
  final String trDate;

  ExGift({
    required this.giftType,
    required this.amount,
    required this.remark,
    required this.trDate,
  });

  factory ExGift.fromJson(Map<String, dynamic> json) {
    return ExGift(
      giftType: json['GiftType'],
      amount: _parseToInt(json['Amount']),
      remark: json['Remarks'],
      trDate: json['TrDate'],
    );
  }
  // static int _parseToInt(dynamic value) {
  //   if (value == null) return 0;
  //   if (value is int) return value;
  //   if (value is String) {
  //     return int.tryParse(value) ?? 0;
  //   }
  //   if (value is double) return value.toInt();
  //   return 0;
  // }
static int _parseToInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) {
      // Remove commas and trim whitespace before parsing
      String cleanValue = value.replaceAll(',', '').trim();
      return int.tryParse(cleanValue) ?? 0;
    }
    if (value is double) return value.toInt();
    return 0;
  }
  Map<String, dynamic> toJson() {
    return {
      'GiftType': giftType,
      'Amount': amount,
      'Remarks': remark,
      'TrDate': trDate,
    };
  }
}

class TripHistory {
  final double consecutiveDates;
  final String arrivalDate;
  final String departureDate;
  final double tripDrop;
  final double tripCashOut;
  final double tripResult;
  final double tripCommission;
  final double tripActDrop;
  final double tripTotalCoupon;
  final double tripHour;
  final double tripMinutes;
  final List<DTLDesc> dtlDesc;
  final double fbCost;
  final double atCost;
  final double transportCost;
  final double htcost;
  final double dtlM;
  final double adtM;
  final double ttlm;
  final double attm;
  final List<ExGift> exGift;

  TripHistory({
    required this.consecutiveDates,
    required this.arrivalDate,
    required this.departureDate,
    required this.tripDrop,
    required this.tripCashOut,
    required this.tripResult,
    required this.tripCommission,
    required this.tripActDrop,
    required this.tripTotalCoupon,
    required this.tripHour,
    required this.tripMinutes,
    required this.dtlDesc,
    required this.fbCost,
    required this.atCost,
    required this.transportCost,
    required this.htcost,
    required this.dtlM,
    required this.adtM,
    required this.ttlm,
    required this.attm,
    required this.exGift,
  });

  factory TripHistory.fromJson(Map<String, dynamic> json) {
    return TripHistory(
      consecutiveDates: json['ConsecutiveDates'],
      arrivalDate: json['ArrivalDate'],
      departureDate: json['DepartureDate'],
      tripDrop: json['Trip_Drop'],
      tripCashOut: json['Trip_CashOut'],
      tripResult: json['Trip_Result'],
      tripCommission: json['Trip_Commission'],
      tripActDrop: json['Trip_ActDrop'],
      tripTotalCoupon: json['Trip_TotalCoupon'],
      tripHour: json['Trip_Hour'],
      tripMinutes: json['Trip_Minutes'],
      dtlDesc:
          (json['DTL_desc'] != null && json['DTL_desc'].toString().isNotEmpty)
          ? (jsonDecode(json['DTL_desc']) as List)
                .map((e) => DTLDesc.fromJson(e))
                .toList()
          : [],
      fbCost: json['FB_Cost'],
      atCost: json['AT_Cost'],
      transportCost: json['tP_Cost'],
      htcost: json['HT_Cost'],
      dtlM: json['DTL_M'],
      adtM: json['ADT_M'],
      ttlm: json['TTL_M'],
      attm: json['ATT_M'],
      exGift: (json['Ex_Gift'] != null && json['Ex_Gift'].toString().isNotEmpty)
          ? (jsonDecode(json['Ex_Gift']) as List)
                .map((e) => ExGift.fromJson(e))
                .toList()
          : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ConsecutiveDates': consecutiveDates,
      'ArrivalDate': arrivalDate,
      'DepartureDate': departureDate,
      'Trip_Drop': tripDrop,
      'Trip_CashOut': tripCashOut,
      'Trip_Result': tripResult,
      'Trip_Commission': tripCommission,
      'Trip_ActDrop': tripActDrop,
      'Trip_TotalCoupon': tripTotalCoupon,
      'Trip_Hour': tripHour,
      'Trip_Minutes': tripMinutes,
      'DTL_desc': dtlDesc.isNotEmpty
          ? jsonEncode(dtlDesc.map((e) => e.toJson()).toList())
          : null,
      'FB_Cost': fbCost,
      'AT_Cost': atCost,
      'tP_Cost': transportCost,
      'HT_Cost': htcost,
      'DTL_M': dtlM,
      'ADT_M': adtM,
      'TTL_M': ttlm,
      'ATT_M': attm,
      'Ex_Gift': exGift,
      jsonEncode(exGift.map((e) => e.toJson()).toList()): null,
    };
  }
}

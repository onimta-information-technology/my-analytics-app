class SpecialGiftRequest {
  final double idNo;
  final String mid;
  final String mname;
  final double mdrop;
  final double cashout;
  final double res;
  final double mCoupon;
  final double avebet;
  final double gPoints;
  final double ghh;
  final double gmm;
  final String gType;
  final String arrDate;
  final String dptDate;
  final double atamt;
  final double htamt;
  final String reqBy;
  final String appBy;
  final String appDate;
  final String dateFrom;
  final String dateTo;
  final String insertDate;
  final String destFrom;
  final String destTo;
  final String lastAirTktDate;
  final String lastHtlDate;
  final double lastAirTkt;
  final double lastHtl;
  final String lastAirTktCashDate;
  final String lastHtlCashDate;
  final double lastAirTktCash;
  final double lastHtlCash;
  final double paidComm;
  final double actDrop;
  final double perActDrop;
  final String gRating;
  final int freeHand;
  final int palyHand;
  final String finalApp;
  final String giftCategory;
  final String giftDesc;
  final String serialNo;
  final double flushCoupon;
  final String dataInsertDate;
  final bool isActive;
  final String? pitAppBy;
  final String? pitAppTime;
  final String chipType;
  final String? editBy;
  final String? editTime;
  final bool isPaid;
  final String cashierPayType;
  final double flushActDrop;
  final String? mktPer;
  final String? deleteUser;
  final String? deleteTime;
  final String? firstAppBy;
  final String? firstAppTime;
  final String? giftCategoryApp;
  final String? descApp;
  final String? validDates;
  SpecialGiftRequest({
    required this.idNo,
    required this.mid,
    required this.mname,
    required this.mdrop,
    required this.cashout,
    required this.res,
    required this.mCoupon,
    required this.avebet,
    required this.gPoints,
    required this.ghh,
    required this.gmm,
    required this.gType,
    required this.arrDate,
    required this.dptDate,
    required this.atamt,
    required this.htamt,
    required this.reqBy,
    required this.appBy,
    required this.appDate,
    required this.dateFrom,
    required this.dateTo,
    required this.insertDate,
    required this.destFrom,
    required this.destTo,
    required this.lastAirTktDate,
    required this.lastHtlDate,
    required this.lastAirTkt,
    required this.lastHtl,
    required this.lastAirTktCashDate,
    required this.lastHtlCashDate,
    required this.lastAirTktCash,
    required this.lastHtlCash,
    required this.paidComm,
    required this.actDrop,
    required this.perActDrop,
    required this.gRating,
    required this.freeHand,
    required this.palyHand,
    required this.finalApp,
    required this.giftCategory,
    required this.giftDesc,
    required this.serialNo,
    required this.flushCoupon,
    required this.dataInsertDate,
    required this.isActive,
    this.pitAppBy,
    this.pitAppTime,
    required this.chipType,
    this.editBy,
    this.editTime,
    required this.isPaid,
    required this.cashierPayType,
    required this.flushActDrop,
    this.mktPer,
    this.deleteUser,
    this.deleteTime,
    this.firstAppBy,
    this.firstAppTime,
    this.giftCategoryApp,
    this.descApp,
     this.validDates,
  });

  factory SpecialGiftRequest.fromJson(Map<String, dynamic> json) {
    String? parseValidDates(dynamic value) {
      if (value == null) return null;
      if (value is String) return value.isEmpty ? null : value;
      if (value is num) return value.toString();
      return value.toString();
    }
    return SpecialGiftRequest(
      idNo: (json['Id_No'] ?? 0).toDouble(),
      mid: json['MID'] ?? '',
      mname: json['MNAME'] ?? '',
      mdrop: (json['MDROP'] ?? 0).toDouble(),
      cashout: (json['CASHOUT'] ?? 0).toDouble(),
      res: (json['RES'] ?? 0).toDouble(),
      mCoupon: (json['MCOUPON'] ?? 0).toDouble(),
      avebet: (json['AVGBET'] ?? 0).toDouble(),
      gPoints: (json['GPOINTS'] ?? 0).toDouble(),
      ghh: (json['GHH'] ?? 0).toDouble(),
      gmm: (json['GMM'] ?? 0).toDouble(),
      gType: json['GType'] ?? '',
      arrDate: json['ArrDate'] ?? '',
      dptDate: json['DptDate'] ?? '',
      atamt: (json['ATAmt'] ?? 0).toDouble(),
      htamt: (json['HTAmt'] ?? 0).toDouble(),
      reqBy: json['ReqBy'] ?? '',
      appBy: json['AppBy'] ?? '',
      appDate: json['AppDate'] ?? '',
      dateFrom: json['DateFrom'] ?? '',
      dateTo: json['DateTo'] ?? '',
      insertDate: json['InsertDate'] ?? '',
      destFrom: json['DestFrom'] ?? '',
      destTo: json['DestTo'] ?? '',
      lastAirTktDate: json['LastAirTktDate'] ?? '',
      lastHtlDate: json['LastHtlDate'] ?? '',
      lastAirTkt: (json['LastAirTkt'] ?? 0).toDouble(),
      lastHtl: (json['LastHtl'] ?? 0).toDouble(),
      lastAirTktCashDate: json['LastAirTktCashDate'] ?? '',
      lastHtlCashDate: json['LastHtlCashDate'] ?? '',
      lastAirTktCash: (json['LastAirTktCash'] ?? 0).toDouble(),
      lastHtlCash: (json['LastHtlCash'] ?? 0).toDouble(),
      paidComm: (json['PaidComm'] ?? 0).toDouble(),
      actDrop: (json['ActDrop'] ?? 0).toDouble(),
      perActDrop: (json['PerActDrop'] ?? 0).toDouble(),
      gRating: json['G_Rating'] ?? '',
      freeHand: (json['FreeHand'] ?? 0),
      palyHand: (json['PalyHand'] ?? 0),
      finalApp: json['FINALAPP'] ?? '',
      giftCategory: json['Gift_Category'] ?? '',
      giftDesc: json['Gift_Desc'] ?? '',
      serialNo: json['SerialNo'] ?? '',
      flushCoupon: (json['Flush_Coupon'] ?? 0).toDouble(),
      dataInsertDate: json['Data_Insert_Date'] ?? '',
      isActive: json['Is_Active'] ?? false,
      pitAppBy: json['Pit_AppBy'],
      pitAppTime: json['Pit_AppTime'],
      chipType: json['Chip_Type'] ?? '',
      editBy: json['Edit_By'],
      editTime: json['Edit_Time'],
      isPaid: json['Is_Paid'] ?? false,
      cashierPayType: json['CashierPay_Type'] ?? '',
      flushActDrop: (json['FlushActDrop'] ?? 0).toDouble(),
      mktPer: json['Mkt_Per'],
      deleteUser: json['Delete_User'],
      deleteTime: json['Delete_Time'],
      firstAppBy: json['First_AppBy'],
      firstAppTime: json['First_AppBy_Time'],
      giftCategoryApp: json['Gift_Category_App'],
      descApp: json['Gift_Desc_App'],
       validDates: parseValidDates(json['VDate']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Id_No': idNo,
      'MID': mid,
      'MNAME': mname,
      'MDROP': mdrop,
      'CASHOUT': cashout,
      'RES': res,
      'MCOUPON': mCoupon,
      'AVGBET': avebet,
      'GPOINTS': gPoints,
      'GHH': ghh,
      'GMM': gmm,
      'GType': gType,
      'ArrDate': arrDate,
      'DptDate': dptDate,
      'ATAmt': atamt,
      'HTAmt': htamt,
      'ReqBy': reqBy,
      'AppBy': appBy,
      'AppDate': appDate,
      'DateFrom': dateFrom,
      'DateTo': dateTo,
      'InsertDate': insertDate,
      'DestFrom': destFrom,
      'DestTo': destTo,
      'LastAirTktDate': lastAirTktDate,
      'LastHtlDate': lastHtlDate,
      'LastAirTkt': lastAirTkt,
      'LastHtl': lastHtl,
      'LastAirTktCashDate': lastAirTktCashDate,
      'LastHtlCashDate': lastHtlCashDate,
      'LastAirTktCash': lastAirTktCash,
      'LastHtlCash': lastHtlCash,
      'PaidComm': paidComm,
      'ActDrop': actDrop,
      'PerActDrop': perActDrop,
      'G_Rating': gRating,
      'FreeHand': freeHand,
      'PalyHand': palyHand,
      'FINALAPP': finalApp,
      'Gift_Category': giftCategory,
      'Gift_Desc': giftDesc,
      'SerialNo': serialNo,
      'Flush_Coupon': flushCoupon,
      'Data_Insert_Date': dataInsertDate,
      'Is_Active': isActive,
      'Pit_AppBy': pitAppBy,
      'Pit_AppTime': pitAppTime,
      'Chip_Type': chipType,
      'Edit_By': editBy,
      'Edit_Time': editTime,
      'Is_Paid': isPaid,
      'CashierPay_Type': cashierPayType,
      'FlushActDrop': flushActDrop,
      'Mkt_Per': mktPer,
      'Delete_User': deleteUser,
      'Delete_Time': deleteTime,
      'First_AppBy': firstAppBy,
      'First_AppBy_Time': firstAppTime,
      'Gift_Category_App': giftCategoryApp,
      'Gift_Desc_App': descApp,
      'VDate': validDates,
    };
  }
}

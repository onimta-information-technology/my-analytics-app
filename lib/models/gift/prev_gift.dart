class PrevGift {
  String? mid;
  String? mname;
  String? serialNo;
  String? pitAppTime;
  String? chipType;
  String? pitAppBy;
  String? giftCategory;
  String? giftDesc;
  double? mDrop;
  double? cashout;
  double? res;
  double? mCoupon;
  double? avgBet;
  double? gPoints;
  double? ghh;
  double? gmm;
  String? gType;
  String? arrDate;
  String? dptDate;
  double? atAmt;
  double? htAmt;
  String? reqBy;
  String? appBy;
  String? appDate;
  String? dateFrom;
  String? dateTo;
  String? insertDate;
  String? destFrom;
  String? destTo;
  String? lastAirTktDate;
  String? lastHtlDate;
  double? lastAirTkt;
  double? lastHtl;
  String? lastAirTktCashDate;
  String? lastHtlCashDate;
  double? lastAirTktCash;
  double? lastHtlCash;
  double? paidComm;
  double? actDrop;
  double? perActDrop;
  String? gRating;
  int? freeHand;
  int? palyHand;
  String? finalApp;
  double? flushCoupon;
  String? dataInsertDate;
  bool? isActive;
  String? editBy;
  String? editTime;
  bool? isPaid;
  String? cashierPayType;
  double? flushActDrop;
  String? mktPer;
 String? giftAppTime;

  PrevGift({
    required this.mid, 
    required this.mname,
    required this.serialNo,
    required this.pitAppTime,
    required this.chipType, 
    required this.pitAppBy,
    required this.giftCategory, 
    required this.giftDesc,
    required this.mDrop,    
    required this.cashout,
    required this.res,    
    required this.mCoupon,    
    required this.avgBet,    
    required this.gPoints,        
    required this.ghh,            
    required this.gmm,            
     this.gType,            
    required this.arrDate,            
    required this.dptDate,            
     this.atAmt,            
     this.htAmt,            
    required this.reqBy,            
    required this.appBy,            
    required this.appDate,            
    required this.dateFrom,            
    required this.dateTo,            
    required this.insertDate,            
     this.destFrom,            
     this.destTo,            
     this.lastAirTktDate,            
     this.lastHtlDate,            
     this.lastAirTkt,            
     this.lastHtl,            
     this.lastAirTktCashDate,            
     this.lastHtlCashDate,            
     this.lastAirTktCash,            
     this.lastHtlCash,            
     this.paidComm,            
     this.actDrop,            
     this.perActDrop,            
     this.gRating,            
     this.freeHand,            
     this.palyHand,            
     this.finalApp,            
     this.flushCoupon,            
    required this.dataInsertDate,            
    required this.isActive,            
     this.editBy,            
     this.editTime,            
    required this.isPaid,            
    required this.cashierPayType,            
    required this.flushActDrop,            
     this.mktPer,
     this.giftAppTime

    });
    
  factory PrevGift.fromJson(Map<String, dynamic> json) {
    return PrevGift(mid: json['MID'],
      mname: json['MNAME'],
      serialNo: json['SerialNo'],
      pitAppTime: json['Pit_AppTime'],
      chipType: json['Chip_Type'],
      pitAppBy: json['Pit_AppBy'],
      giftCategory: json['Gift_Category'],
      giftDesc: json['Gift_Desc'],
      mDrop: (json['MDrop'] as num?)?.toDouble(),
      cashout: (json['CASHOUT'] as num?)?.toDouble(),
      res: (json['Res'] as num?)?.toDouble(),
      mCoupon: (json['MCOUPON'] as num?)?.toDouble(),
      avgBet: (json['AVGBET'] as num?)?.toDouble(),
      gPoints: (json['GPOINTS'] as num?)?.toDouble(),
      ghh: (json['GHH'] as num?)?.toDouble(),
      gmm: (json['GMM'] as num?)?.toDouble(),
      gType: json['GType'],
      arrDate: json['ArrDate'],
      dptDate: json['DptDate'],
      atAmt: (json['ATAmt'] as num?)?.toDouble(),
      htAmt: (json['HTAmt'] as num?)?.toDouble(),
      reqBy: json['ReqBy'],
      appBy: json['AppBy'],
      appDate: json['AppDate'],
      dateFrom: json['DateFrom'],
      dateTo: json['DateTo'],
      insertDate: json['InsertDate'],
      destFrom: json['DestFrom'],
      destTo: json['DestTo'],
      lastAirTktDate: json['LastAirTktDate'],
      lastHtlDate: json['LastHtlDate'],
      lastAirTkt: (json['LastAirTkt'] as num?)?.toDouble(),
      lastHtl: (json['LastHtl'] as num?)?.toDouble(),
      lastAirTktCashDate: json['LastAirTktCashDate'],
      lastHtlCashDate: json['LastHtlCashDate'],
      lastAirTktCash: (json['LastAirTktCash'] as num?)?.toDouble(),
      lastHtlCash: (json['LastHtlCash'] as num?)?.toDouble(),
      paidComm: (json['PaidComm'] as num?)?.toDouble(),
      actDrop: (json['ActDrop'] as num?)?.toDouble(),
      perActDrop: (json['PerActDrop'] as num?)?.toDouble(),
      gRating: json['G_Rating'],
      freeHand: json['FreeHand'],
      palyHand: json['PalyHand'],
      finalApp: json['FINALAPP'],
      flushCoupon: (json['Flush_Coupon'] as num?)?.toDouble(),
      dataInsertDate: json['Data_Insert_Date'],
      isActive: json['Is_Active'],
      editBy: json['Edit_By'],
      editTime: json['Edit_Time'],
      isPaid: json['Is_Paid'],
      cashierPayType: json['CashierPay_Type'],
      flushActDrop: (json['FlushActDrop'] as num?)?.toDouble(),
      mktPer: json['Mkt_Per'],
      giftAppTime: json['Gift_App_Time']
     );
  }

  Map<String, dynamic> toJson() => {
    'MID': mid, 
    'MNAME': mname,
    'SerialNo': serialNo,
    'Pit_AppTime': pitAppTime,
    'Chip_Type': chipType,
    'Pit_AppBy': pitAppBy,
    'Gift_Category': giftCategory,
    'Gift_Desc': giftDesc,
    'MDrop': mDrop,
    'CASHOUT': cashout,
    'Res': res,
    'MCOUPON': mCoupon,
    'AVGBET': avgBet,
    'GPOINTS': gPoints,
    'GHH': ghh,
    'GMM': gmm,
    'GType': gType,
    'ArrDate': arrDate,
    'DptDate': dptDate,
    'ATAmt': atAmt,
    'HTAmt': htAmt,
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
    'Flush_Coupon': flushCoupon,
    'Data_Insert_Date': dataInsertDate,
    'Is_Active': isActive,
    'Edit_By': editBy,
    'Edit_Time': editTime,
    'Is_Paid': isPaid,
    'CashierPay_Type': cashierPayType,
    'FlushActDrop': flushActDrop,
    'Mkt_Per': mktPer,
    'Gift_App_Time': giftAppTime
  };
}

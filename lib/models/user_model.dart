class User {
  final String userName;
  final String userLevel;
  final String salesCode;
  final String marketingCode;
  final String? loginId;
  final String? mobileNumber;
  final bool? memProfSH;
  final bool? giftApp;
  final bool? resApp;
  final bool? resChk;
  final bool? otgiApp;
  final bool? otgiChk;
  final bool? bgApp;
  final bool? bgChk;
  User({
    required this.userName,
    required this.userLevel,
    required this.salesCode,
    required this.marketingCode,
    this.mobileNumber,
    this.loginId,
    this.memProfSH,
    this.giftApp,
    this.resApp,
    this.resChk,
    this.otgiApp,
    this.otgiChk,
    this.bgApp,    
    this.bgChk,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      userName: json['Login_By'],
      userLevel: json['User_Level'],
      salesCode: json['Sales_Code'],
      marketingCode: json['Marketing_Code'],
      mobileNumber: json['Mobile'],
      loginId: json['LoginID']?.toString(),
      memProfSH: json['Mem_Prof_SH'],
      giftApp: json['Gift_App'],
      resApp: json['R_App'],
      resChk: json['R_Chk'],
      otgiApp: json['G_App'],
      otgiChk: json['G_CHK'],
      bgApp: json['BG_APP'],
      bgChk: json['BG_CHK'],
    );
  }
}

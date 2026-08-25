class User {
  final String userName;
  final String? uName;
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
  final bool? marketingP;
  User({
    required this.userName,
    this.uName,
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
    this.marketingP,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      userName: json['Login_By'],
      uName: json['U_Name'],
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
      marketingP: parseMarketingP(json),
    );
  }

  // The login response spells this key "MArketing_P" and may send it as a bool
  // or as a "True"/"False" string, so read it defensively.
  static bool? parseMarketingP(Map<String, dynamic> json) {
    final raw = json['MArketing_P'] ?? json['Marketing_P'];
    if (raw == null) return null;
    if (raw is bool) return raw;
    return raw.toString().toLowerCase() == 'true';
  }
}

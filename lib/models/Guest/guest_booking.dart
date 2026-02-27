class GuestBooking {
  final int idNo;
  final String mid;
  final String pkgStart;
  final String pkgEnd;
  final bool pkgStatus;
  final String insertDate;
  final String mname;
  final String bookingId;
  final String? acceptUser;
  final String? acceptTime;
  final String? remark;
  final String? peRemark;
  GuestBooking({
    required this.idNo,
    required this.mid,
    required this.pkgStart,
    required this.pkgEnd,
    required this.pkgStatus,
    required this.insertDate,
    this.mname = '',
    this.bookingId = '',
    this.acceptUser,
    this.acceptTime,
    this.remark,
    this.peRemark,

  });

  factory GuestBooking.fromJson(Map<String, dynamic> json) {
    return GuestBooking(
      idNo: json['Id_No'] ?? 0,
      mid: json['MID'] ?? '',
      pkgStart: json['Pkg_Start'] ?? '',
      pkgEnd: json['Pkg_End'] ?? '',
      pkgStatus: json['Pkg_Status'] ?? false,
      insertDate: json['InsertDate'] ?? '',
      mname: json['MName'] ?? '',
      bookingId: json['Booking_Id'] ?? '',
      acceptUser: json['Accept_User'],
      acceptTime: json['Accept_Time'],
      remark: json['Remark'],
      peRemark: json['Remark_Premier_Rewards'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Id_No': idNo,
      'MID': mid,
      'Pkg_Start': pkgStart,
      'Pkg_End': pkgEnd,
      'Pkg_Status': pkgStatus,
      'InsertDate': insertDate,
      'MName': mname,
      'Booking_Id': bookingId,
      'Accept_User': acceptUser,
      'Accept_Time': acceptTime,
      'Remark': remark,
      'Remark_Premier_Rewards': peRemark,
    };
  }
}
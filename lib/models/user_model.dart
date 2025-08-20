class User {
  final String userName;
  final String userLevel;
  final String salesCode;

  User(
      {required this.userName,
      required this.userLevel,
      required this.salesCode});

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      userName: json['Login_By'],
      userLevel: json['User_Level'],
      salesCode: json['Sales_Code'],
    );
  }
}

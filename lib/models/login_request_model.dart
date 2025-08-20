class LoginRequestModal {
  final String userName;
  final String password;

  LoginRequestModal({required this.userName, required this.password});

  Map<String, dynamic> toJson() {
    return {
      "UserName": userName,
      "PassWord": password,
    };
  }
}

class PhoneResponse {
  final String phone1;

  PhoneResponse({
    required this.phone1,
  });

  factory PhoneResponse.fromJson(Map<String, dynamic> json) {
    return PhoneResponse(
      phone1: json['Phone1'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Phone1': phone1,
    };
  }

  @override
  String toString() {
    return 'PhoneResponse(phone1: $phone1)';
  }
}
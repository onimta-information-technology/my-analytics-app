class PrimaryContactResponse {
  final String? message;
  final String? contactType;
  final String? primaryValue;

  PrimaryContactResponse({
    this.message,
    this.contactType,
    this.primaryValue,
  });

  factory PrimaryContactResponse.fromJson(Map<String, dynamic> json) {
    return PrimaryContactResponse(
      message: json['Message']?.toString(),
      contactType: json['ContactType']?.toString(),
      primaryValue: json['PrimaryValue']?.toString(),
    );
  }
}
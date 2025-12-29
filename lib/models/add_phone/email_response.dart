class EmailResponse {
  final String email;
  final int emailType; // 1 for Email1, 2 for Email2
  final String emailFieldName; // "Email1", "Email2"

  EmailResponse({
    required this.email,
    required this.emailType,
    required this.emailFieldName,
  });

  factory EmailResponse.fromJson(Map<String, dynamic> json, int emailType) {
    String fieldName = 'Email$emailType';
    String email = '';
    
    // Try to get the email from the appropriate field
    if (json['Email1'] != null) {
      email = json['Email1'] as String;
      fieldName = 'Email1';
    } else if (json['Email2'] != null) {
      email = json['Email2'] as String;
      fieldName = 'Email2';
    }
    
    return EmailResponse(
      email: email,
      emailType: emailType,
      emailFieldName: fieldName,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      emailFieldName: email,
      'emailType': emailType,
    };
  }

  @override
  String toString() {
    return 'EmailResponse(email: $email, emailType: $emailType, emailFieldName: $emailFieldName)';
  }
}
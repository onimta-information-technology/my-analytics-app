class WhatsappResponse {
  final String phoneNumber;
  final int phoneType; // 1 for Phone1, 2 for Phone2, 3 for Phone3
  final String phoneFieldName; // "Phone1", "Phone2", "Phone3"

  WhatsappResponse({
    required this.phoneNumber,
    required this.phoneType,
    required this.phoneFieldName,
  });

  factory WhatsappResponse.fromJson(Map<String, dynamic> json, int phoneType) {
    String fieldName = 'Phone$phoneType';
    String phoneNumber = '';
    
    // Try to get the phone number from the appropriate field
    if (json['WhatsApp'] != null) {
      phoneNumber = json['WhatsApp'] as String;
      fieldName = 'WhatsApp';
    } else if (json['WhatsApp1'] != null) {
      phoneNumber = json['WhatsApp1'] as String;
      fieldName = 'WhatsApp1';
    } else if (json['WhatsApp2'] != null) {
      phoneNumber = json['WhatsApp2'] as String;
      fieldName = 'WhatsApp2';
    }

    return WhatsappResponse(
      phoneNumber: phoneNumber,
      phoneType: phoneType,
      phoneFieldName: fieldName,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      phoneFieldName: phoneNumber,
      'phoneType': phoneType,
    };
  }

  @override
  String toString() {
    return 'WhatsappResponse(phoneNumber: $phoneNumber, phoneType: $phoneType, phoneFieldName: $phoneFieldName)';
  }
}
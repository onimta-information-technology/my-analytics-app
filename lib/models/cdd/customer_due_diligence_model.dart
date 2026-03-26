// lib/models/cdd/customer_due_diligence_model.dart

class CustomerDueDiligenceModel {
  final bool success;
  final String message;

  CustomerDueDiligenceModel({required this.success, required this.message});

  factory CustomerDueDiligenceModel.fromJson(Map<String, dynamic> json) {
    return CustomerDueDiligenceModel(
      success: json['Success'] == true || json['success'] == true,
      message: json['Message'] ?? json['message'] ?? '',
    );
  }
}
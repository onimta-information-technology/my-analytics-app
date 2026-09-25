/// Row from the Duty Manager SP call (Iid 647, Ballys only).
class DutyManager {
  final String name;
  final String department;
  final String designation;
  final String inTime;
  final String status;

  DutyManager({
    required this.name,
    required this.department,
    required this.designation,
    required this.inTime,
    required this.status,
  });

  factory DutyManager.fromJson(Map<String, dynamic> json) {
    return DutyManager(
      name: json['Name']?.toString().trim() ?? '',
      department: json['Department']?.toString().trim() ?? '',
      designation: json['Designation']?.toString().trim() ?? '',
      inTime: json['InTime']?.toString().trim() ?? '',
      status: json['Status']?.toString().trim() ?? '',
    );
  }

  bool get isOnDuty => status.toLowerCase() == 'on duty';
}

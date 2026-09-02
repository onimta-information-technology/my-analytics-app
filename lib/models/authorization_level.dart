/// One approver row from `GetAuthorizationLevels` — the people a reservation
/// can be sent to for approval, ordered by their authorization level.
class AuthorizationLevel {
  final int idNo;
  final String name;
  final String category;
  final String levelLabel;
  final int levelNo;
  final bool isActive;

  const AuthorizationLevel({
    required this.idNo,
    required this.name,
    required this.category,
    required this.levelLabel,
    required this.levelNo,
    required this.isActive,
  });

  factory AuthorizationLevel.fromJson(Map<String, dynamic> json) {
    return AuthorizationLevel(
      idNo: int.tryParse(json['id_no']?.toString() ?? '') ?? 0,
      name: json['Name']?.toString() ?? '',
      category: json['Category']?.toString() ?? '',
      levelLabel: json['Levl']?.toString() ?? '',
      levelNo: int.tryParse(json['LevelNo']?.toString() ?? '') ?? 0,
      isActive: json['Is_Active'] == true,
    );
  }

  /// What the dropdown shows once an approver is picked.
  String get displayLabel =>
      levelLabel.isEmpty ? name : '$name — $levelLabel';

  // The dropdown compares the selected value against the freshly parsed list,
  // so equality has to be by id rather than by identity.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AuthorizationLevel && other.idNo == idNo);

  @override
  int get hashCode => idNo.hashCode;
}

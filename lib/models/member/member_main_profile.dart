class MemberMainProfile {
  final Map<String, String> details;

  MemberMainProfile({required this.details});

  factory MemberMainProfile.fromJson(Map<String, dynamic> json) {
    Map<String, String> details = {};
    json.forEach((key, value) {
      details[key] = value.toString();
    });
    return MemberMainProfile(details: details);
  }

  Map<String, dynamic> toJson() {
    return details;
  }
}

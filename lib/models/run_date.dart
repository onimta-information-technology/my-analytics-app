class RunDate {
  final DateTime date;

  RunDate({required this.date});

  factory RunDate.fromJson(Map<String, dynamic> json) {
    return RunDate(
      date: DateTime.parse(json['RunDate'] as String),
    );
  }

  @override
  String toString() => 'RunDate(date: $date)';
}
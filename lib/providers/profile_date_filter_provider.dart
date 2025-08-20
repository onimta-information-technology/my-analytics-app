import 'package:flutter_riverpod/flutter_riverpod.dart';

class DateFilterState {
  final DateTime? dateFrom;
  final DateTime? dateTo;

  DateFilterState({this.dateFrom, this.dateTo});

  DateFilterState copyWith({DateTime? dateFrom, DateTime? dateTo}) {
    return DateFilterState(
      dateFrom: dateFrom ?? this.dateFrom,
      dateTo: dateTo ?? this.dateTo,
    );
  }
}

class DateFilterNotifier extends StateNotifier<DateFilterState> {
  DateFilterNotifier() : super(DateFilterState());

  void setDateFrom(DateTime date) {
    state = state.copyWith(dateFrom: date);
  }

  void setDateTo(DateTime date) {
    state = state.copyWith(dateTo: date);
  }

  void resetDates() {
    state = DateFilterState();
  }
}

final dateFilterProvider = StateNotifierProvider<DateFilterNotifier, DateFilterState>((ref) {
  return DateFilterNotifier();
});
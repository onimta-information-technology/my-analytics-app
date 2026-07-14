import 'package:ballys_reservation_app/data/repositories/transport_repository.dart';
import 'package:ballys_reservation_app/data/services/api_service.dart';
import 'package:ballys_reservation_app/models/transport/transport_reservation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TransportNotifier extends StateNotifier<TransportState> {
  final TransportRepository repository;

  TransportNotifier(this.repository) : super(TransportState());

  Future<void> getTransportData() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final reservations = await repository.getTransportData();
      state = state.copyWith(reservations: reservations, isLoading: false);
    } catch (e) {
      print('Error in getTransportData: $e');
      state = state.copyWith(
        reservations: [],
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  void resetData() {
    state = TransportState();
  }
}

final transportRepositoryProvider = Provider((ref) {
  final apiService = ApiService(const FlutterSecureStorage());
  return TransportRepository(apiService);
});

final transportProvider =
    StateNotifierProvider<TransportNotifier, TransportState>((ref) {
  return TransportNotifier(ref.read(transportRepositoryProvider));
});

class TransportState {
  final List<TransportReservation> reservations;
  final bool isLoading;
  final String? error;

  TransportState({
    this.reservations = const [],
    this.isLoading = false,
    this.error,
  });

  TransportState copyWith({
    List<TransportReservation>? reservations,
    bool? isLoading,
    String? error,
  }) {
    return TransportState(
      reservations: reservations ?? this.reservations,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

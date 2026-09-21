import 'package:ballys_reservation_app/data/repositories/transport_repository_ballys.dart';
import 'package:ballys_reservation_app/data/services/api_service.dart';
import 'package:ballys_reservation_app/models/transport/transport_reservation_ballys.dart';
import 'package:ballys_reservation_app/utils/secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TransportNotifierBallys extends StateNotifier<TransportStateBallys> {
  final TransportRepositoryBallys repository;

  TransportNotifierBallys(this.repository) : super(TransportStateBallys());

  Future<void> getTransportReservations() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final reservations = await repository.getTransportReservations();
      state = state.copyWith(reservations: reservations, isLoading: false);
    } catch (e) {
      print('Error in getTransportReservations (Ballys): $e');
      state = state.copyWith(
        reservations: [],
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Checks, approves or rejects a request, then reloads the list so it moves
  /// to its new tab.
  Future<TransportStatusUpdateResult> updateStatus({
    required String masterId,
    required String status,
    required String remark,
  }) async {
    try {
      final result = await repository.updateStatus(
        masterId: masterId,
        status: status,
        remark: remark,
      );
      if (result.success) await getTransportReservations();
      return result;
    } catch (e) {
      return TransportStatusUpdateResult(success: false, message: e.toString());
    }
  }

  void resetData() {
    state = TransportStateBallys();
  }
}

final transportRepositoryBallysProvider = Provider((ref) {
  return TransportRepositoryBallys(ApiService(SecureStorage.instance));
});

final transportProviderBallys =
    StateNotifierProvider<TransportNotifierBallys, TransportStateBallys>((ref) {
  return TransportNotifierBallys(ref.read(transportRepositoryBallysProvider));
});

/// The request opened from the list, read by the view screen.
final selectedTransportBallysProvider =
    StateProvider<TransportReservationBallys?>((ref) => null);

class TransportStateBallys {
  final List<TransportReservationBallys> reservations;
  final bool isLoading;
  final String? error;

  TransportStateBallys({
    this.reservations = const [],
    this.isLoading = false,
    this.error,
  });

  TransportStateBallys copyWith({
    List<TransportReservationBallys>? reservations,
    bool? isLoading,
    String? error,
  }) {
    return TransportStateBallys(
      reservations: reservations ?? this.reservations,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

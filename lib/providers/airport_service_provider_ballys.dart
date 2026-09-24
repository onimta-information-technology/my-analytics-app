import 'package:ballys_reservation_app/data/repositories/airport_service_repository_ballys.dart';
import 'package:ballys_reservation_app/data/services/api_service.dart';
import 'package:ballys_reservation_app/models/airport_service/airport_service_ballys.dart';
import 'package:ballys_reservation_app/utils/secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AirportServiceNotifierBallys
    extends StateNotifier<AirportServiceStateBallys> {
  final AirportServiceRepositoryBallys repository;

  AirportServiceNotifierBallys(this.repository)
      : super(AirportServiceStateBallys());

  Future<void> getAirportServices() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final requests = await repository.getAirportServices();
      state = state.copyWith(requests: requests, isLoading: false);
    } catch (e) {
      print('Error in getAirportServices (Ballys): $e');
      state = state.copyWith(
        requests: [],
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Checks, approves or rejects a request, then reloads the list so it moves
  /// to its new tab.
  Future<AirportServiceStatusUpdateResult> updateStatus({
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
      if (result.success) await getAirportServices();
      return result;
    } catch (e) {
      return AirportServiceStatusUpdateResult(
          success: false, message: e.toString());
    }
  }

  void resetData() {
    state = AirportServiceStateBallys();
  }
}

final airportServiceRepositoryBallysProvider = Provider((ref) {
  return AirportServiceRepositoryBallys(ApiService(SecureStorage.instance));
});

final airportServiceProviderBallys = StateNotifierProvider<
    AirportServiceNotifierBallys, AirportServiceStateBallys>((ref) {
  return AirportServiceNotifierBallys(
      ref.read(airportServiceRepositoryBallysProvider));
});

/// The request opened from the list, read by the view screen.
final selectedAirportServiceBallysProvider =
    StateProvider<AirportServiceBallys?>((ref) => null);

class AirportServiceStateBallys {
  final List<AirportServiceBallys> requests;
  final bool isLoading;
  final String? error;

  AirportServiceStateBallys({
    this.requests = const [],
    this.isLoading = false,
    this.error,
  });

  AirportServiceStateBallys copyWith({
    List<AirportServiceBallys>? requests,
    bool? isLoading,
    String? error,
  }) {
    return AirportServiceStateBallys(
      requests: requests ?? this.requests,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

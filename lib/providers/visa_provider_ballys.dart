import 'package:ballys_reservation_app/data/repositories/visa_repository_ballys.dart';
import 'package:ballys_reservation_app/data/services/api_service.dart';
import 'package:ballys_reservation_app/models/visa/visa_request_ballys.dart';
import 'package:ballys_reservation_app/utils/secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class VisaNotifierBallys extends StateNotifier<VisaStateBallys> {
  final VisaRepositoryBallys repository;

  VisaNotifierBallys(this.repository) : super(VisaStateBallys());

  Future<void> getVisaRequests() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final requests = await repository.getVisaRequests();
      state = state.copyWith(requests: requests, isLoading: false);
    } catch (e) {
      print('Error in getVisaRequests (Ballys): $e');
      state = state.copyWith(
        requests: [],
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Checks, approves or rejects a request, then reloads the list so it moves
  /// to its new tab.
  Future<VisaStatusUpdateResult> updateStatus({
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
      if (result.success) await getVisaRequests();
      return result;
    } catch (e) {
      return VisaStatusUpdateResult(success: false, message: e.toString());
    }
  }

  void resetData() {
    state = VisaStateBallys();
  }
}

final visaRepositoryBallysProvider = Provider((ref) {
  return VisaRepositoryBallys(ApiService(SecureStorage.instance));
});

final visaProviderBallys =
    StateNotifierProvider<VisaNotifierBallys, VisaStateBallys>((ref) {
  return VisaNotifierBallys(ref.read(visaRepositoryBallysProvider));
});

/// The request opened from the list, read by the view screen.
final selectedVisaBallysProvider =
    StateProvider<VisaRequestBallys?>((ref) => null);

class VisaStateBallys {
  final List<VisaRequestBallys> requests;
  final bool isLoading;
  final String? error;

  VisaStateBallys({
    this.requests = const [],
    this.isLoading = false,
    this.error,
  });

  VisaStateBallys copyWith({
    List<VisaRequestBallys>? requests,
    bool? isLoading,
    String? error,
  }) {
    return VisaStateBallys(
      requests: requests ?? this.requests,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

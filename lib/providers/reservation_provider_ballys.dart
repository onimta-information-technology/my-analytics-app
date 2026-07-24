import 'package:ballys_reservation_app/data/repositories/reservation_repository.dart';
import 'package:ballys_reservation_app/data/services/api_service.dart';
import 'package:ballys_reservation_app/models/reervationBallys.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ReservationBallysNotifier
    extends StateNotifier<Map<String, List<ReservationBallys>>> {
  final ReservationRepository reservationRepository;

  ReservationBallysNotifier(this.reservationRepository)
    : super({'Pending': [], 'Approved': [], 'Rejected': [], 'Checked': []});

  Future<void> getReservationData() async {
    state = {'Pending': [], 'Approved': [], 'Rejected': [], 'Checked': []};

    final reservations = await reservationRepository.getBallysReservations();

    state = reservations;
 
  }
void clearReservations() {
    state = {'Pending': [], 'Approved': [], 'Rejected': [], 'Checked': []};
  }
  void addReservationToPending(ReservationBallys newReservation) {
   
  }
  // Add this method to your ReservationNotifier class

  /// Re-posts the reservation to the insert endpoint with a new
  /// `reservation_status` and refreshes the list on success.
  Future<bool> updateReservationStatus({
    required ReservationBallys reservation,
    required String status,
    required String remarks,
  }) async {
    try {
      final success = await reservationRepository.updateBallysReservationStatus(
        reservation: reservation,
        status: status,
        remarks: remarks,
      );

      if (success) {
        await getReservationData();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Future<bool> approveOrRejectReservation({
  //   required String memberID,
  //   required String reservationNo,
  //   required String currentUName,
  //   required String status,
  //   required String remarks,
  // }) async {
  //   try {
      
  //     final success = await reservationRepository.approveOrRejectReservation(
  //       memberID: memberID,
  //       reservationNo: reservationNo,
  //       currentUName: currentUName,
  //       status: status,
  //       remarks: remarks,
  //     );

  //     if (success) {
  //       // Refresh the reservation data after successful approve/reject
  //       await getReservationData();
  //       return true;
  //     }
  //     return false;
  //   } catch (e) {
   
  //     return false;
  //   }
  // }
}

final flutterSecureStorageProvider = Provider(
  (ref) => const FlutterSecureStorage(),
);

final apiServiceProvider = Provider((ref) {
  final storage = ref.read(flutterSecureStorageProvider);
  return ApiService(storage);
});

final reservationRepositoryProvider = Provider((ref) {
  final apiService = ref.read(apiServiceProvider);
  return ReservationRepository(apiService);
});

final reservationBallysProvider =
    StateNotifierProvider<ReservationBallysNotifier, Map<String, List<ReservationBallys>>>(
      (ref) {
        final reservationRepository = ref.read(reservationRepositoryProvider);
        return ReservationBallysNotifier(reservationRepository);
      },
    );

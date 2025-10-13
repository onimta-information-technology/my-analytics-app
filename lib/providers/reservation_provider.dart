import 'package:ballys_reservation_app/data/repositories/reservation_repository.dart';
import 'package:ballys_reservation_app/data/services/api_service.dart';
import 'package:ballys_reservation_app/models/reservation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ReservationNotifier
    extends StateNotifier<Map<String, List<Reservation>>> {
  final ReservationRepository reservationRepository;

  ReservationNotifier(this.reservationRepository)
    : super({'Pending': [], 'Approved': [], 'Rejected': []});

  Future<void> getReservationData() async {
    state = {'Pending': [], 'Approved': [], 'Rejected': []};

    final reservations = await reservationRepository.getReservations();

    state = reservations;
    print(state);
  }

  void addReservationToPending(Reservation newReservation) {
   
  }
  // Add this method to your ReservationNotifier class

  Future<bool> approveOrRejectReservation({
    required String memberID,
    required String reservationNo,
    required String currentUName,
    required String status,
    required String remarks,
  }) async {
    try {
      
      final success = await reservationRepository.approveOrRejectReservation(
        memberID: memberID,
        reservationNo: reservationNo,
        currentUName: currentUName,
        status: status,
        remarks: remarks,
      );

      if (success) {
        // Refresh the reservation data after successful approve/reject
        await getReservationData();
        return true;
      }
      return false;
    } catch (e) {
      print('Error in ReservationNotifier.approveOrRejectReservation: $e');
      return false;
    }
  }
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

final reservationProvider =
    StateNotifierProvider<ReservationNotifier, Map<String, List<Reservation>>>((
      ref,
    ) {
      final reservationRepository = ref.read(reservationRepositoryProvider);
      return ReservationNotifier(reservationRepository);
    });

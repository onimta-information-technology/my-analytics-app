import 'package:ballys_reservation_app/data/repositories/guest_booking_repository.dart';
import 'package:ballys_reservation_app/data/services/api_service.dart';
import 'package:ballys_reservation_app/models/Guest/guest_booking.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ballys_reservation_app/utils/secure_storage.dart';

class GuestBookingNotifier extends StateNotifier<GuestBookingState> {
  final GuestBookingRepository bookingRepository;

  GuestBookingNotifier(this.bookingRepository) : super(GuestBookingState());

  Future<void> getAllBookings() async {
    try {
      final bookingList = await bookingRepository.getAllBookings();
      
      // Use whereType to ensure only non-null GuestBooking objects
      final pendingBookings = bookingList
          .whereType<GuestBooking>()
          .where((b) => b.pkgStatus == false)
          .toList();
      final acceptedBookings = bookingList
          .whereType<GuestBooking>()
          .where((b) => b.pkgStatus == true)
          .toList();
      
      state = state.copyWith(
        pendingBookings: pendingBookings,
        acceptedBookings: acceptedBookings,
      );
    } catch (e) {
      print('Error in getAllBookings: $e');
      state = state.copyWith(
        pendingBookings: [],
        acceptedBookings: [],
      );
    }
  }
Future<bool> acceptBooking({
  required String mid,
  required String bookingId,
  String remark = "",
}) async {
  return await bookingRepository.acceptBooking(
    mid: mid,
    bookingId: bookingId,
    remark: remark,
  );
}
  // Future<bool> acceptBooking({
  //   required int idNo,
  //   required String userName,
  // }) async {
  //   return await bookingRepository.acceptBooking(
  //     idNo: idNo,
  //     userName: userName,
  //   );
  // }

  // Future<bool> rejectBooking({
  //   required int idNo,
  //   required String userName,
  // }) async {
  //   return await bookingRepository.rejectBooking(
  //     idNo: idNo,
  //     userName: userName,
  //   );
  // }

  void resetData() {
    state = GuestBookingState();
  }
}

final guestBookingProvider = StateNotifierProvider<GuestBookingNotifier, GuestBookingState>((ref) {
  final bookingRepository = ref.read(guestBookingRepositoryProvider);
  return GuestBookingNotifier(bookingRepository);
});

final guestBookingRepositoryProvider = Provider((ref) {
  final apiService = ApiService(SecureStorage.instance);
  return GuestBookingRepository(apiService, SecureStorage.instance);
});

class GuestBookingState {
  final List<GuestBooking> pendingBookings;
  final List<GuestBooking> acceptedBookings;

  GuestBookingState({
    this.pendingBookings = const [],
    this.acceptedBookings = const [],
  });

  GuestBookingState copyWith({
    List<GuestBooking>? pendingBookings,
    List<GuestBooking>? acceptedBookings,
  }) {
    return GuestBookingState(
      pendingBookings: pendingBookings ?? this.pendingBookings,
      acceptedBookings: acceptedBookings ?? this.acceptedBookings,
    );
  }
}
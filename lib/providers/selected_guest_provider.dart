import 'package:ballys_reservation_app/data/repositories/guest_repository.dart';
import 'package:ballys_reservation_app/data/services/api_service.dart';
import 'package:ballys_reservation_app/models/guest_modal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';


class SelectedGuestNotifier extends StateNotifier<Guest?> {
  final GuestRepository guestRepository;

  SelectedGuestNotifier(this.guestRepository) : super(null);

  void setSelectedGuest(Guest guest) {
    state = guest;
 
  }

  Future<void> setSelectedGuestWithId(String memberId) async {
    // Set initial partial data
    state = Guest(
      mid: memberId,
      memberName: "",
      country: "",
      lastVisitDate: "1990-01-01",
      age: 0,
      gRating: "",
      mGroup: "",
      gName: "",
    );

    // Fetch complete data
    try {
      final completeGuestList = await guestRepository.getGuestData(
        9021,
        memberId,
      );
      if (completeGuestList.isNotEmpty) {
        state = completeGuestList.first;
      }
    } catch (e) {
     
    }
   
  }

  void setSelectedGuestfilterdate() {}
  void updateMemberInfo(String mid, String mName) {
    state = Guest(
      mid: mid,
      memberName: mName,
      country: "",
      lastVisitDate: "1990-01-01",
      age: 0,
      gRating: "",
      mGroup: "",
      gName: state?.gName ?? "",
      memImage2: state?.memImage2 ?? "",
    );
  
  }

  Future<void> getGuestImage(int iid, String text1) async {
    try {
      final imageUrl = await guestRepository.fetchGuestImage(iid, text1);
      if (imageUrl == null) return;
      state = state?.copyWith(memImage2: imageUrl);
    } catch (e) {
   
      state = state?.copyWith(memImage2: null);
    } finally {}
  }
}

final flutterSecureStorageProvider = Provider(
  (ref) => const FlutterSecureStorage(),
);

final apiServiceProvider = Provider((ref) {
  final storage = ref.read(flutterSecureStorageProvider);
  return ApiService(storage);
});

final guestRepositoryProvider = Provider((ref) {
  final apiService = ref.read(apiServiceProvider);
  return GuestRepository(apiService);
});

final selectedGuestProvider =
    StateNotifierProvider<SelectedGuestNotifier, Guest?>((ref) {
      final guestRepository = ref.read(guestRepositoryProvider);
      return SelectedGuestNotifier(guestRepository);
    });

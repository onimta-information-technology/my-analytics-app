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
  void setSelectedGuestfilterdate(){
    
  }
    void updateMemberInfo(String mid, String mName) {
    state = Guest(
      mid: mid,
      memberName: mName ,
      country: "",
      lastVisitDate: "1990-01-01",
      age: 0,
      gRating: "",
      mGroup: "",
      gName: "",
    );
  }

  Future<void> getGuestImage(int iid, String text1) async {
    try {
      final imageUrl = await guestRepository.fetchGuestImage(iid, text1);
      if (imageUrl == null) return;
      state = state?.copyWith(memImage2: imageUrl);
    } catch (e) {
      print('Data retrivng: $e');
      state = state?.copyWith(memImage2: null);
    } finally {}
  }
}

// List<Guest> _updateGuestList(
//     List<Guest> guestList, String mid, String imageUrl) {
//   return guestList.map((guest) {
//     if (guest.mid == mid) {
//       return guest.copyWith(memImage2: imageUrl);
//     }
//     return guest;
//   }).toList();
// }

final flutterSecureStorageProvider =
    Provider((ref) => const FlutterSecureStorage());

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

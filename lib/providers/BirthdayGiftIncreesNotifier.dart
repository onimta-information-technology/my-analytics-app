import 'package:ballys_reservation_app/data/repositories/gifts_repository.dart';
import 'package:ballys_reservation_app/data/services/api_service.dart';
import 'package:ballys_reservation_app/models/gift/birthday_gift_request.dart';
import 'package:ballys_reservation_app/models/gift/special_gift_request.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class BirthdayGiftIncreesNotifier extends StateNotifier<BirthdayGiftIncreesState> {
  final GiftsRepository giftRepository;

  BirthdayGiftIncreesNotifier(this.giftRepository) : super(BirthdayGiftIncreesState());
  void clearbirthdayGifts() {
    state = BirthdayGiftIncreesState(
      pendingBirthdayGift: [],
      checkedBirthdayGift: [],
      approvedBirthdayGift: [],
      rejectBirthdayGift: [],
      
    );
  }
  Future<void> getBirthdayGiftData(int iid, String text1) async {
    try {
      var birthdayGiftList = await giftRepository.getBirthdayIncressGift(iid, text1);
    
      switch (iid) {
        case 98890:
          state = state.copyWith(pendingBirthdayGift: birthdayGiftList);
          break;
        case 788790:
          state = state.copyWith(checkedBirthdayGift: birthdayGiftList);
          break;
        case 98891:
          state = state.copyWith(approvedBirthdayGift: birthdayGiftList);
          break;
        case 98893:
          state = state.copyWith(rejectBirthdayGift: birthdayGiftList);
          break;
      }
    } catch (e) {
      print('Error in getBirthdayGiftData: $e');
      switch (iid) {
        case 98890:
          state = state.copyWith(pendingBirthdayGift: []);
          break;
        case 788790:
          state = state.copyWith(checkedBirthdayGift: []);
          break;
        case 98891:
          state = state.copyWith(approvedBirthdayGift: []);
          break;
        case 98893:
          state = state.copyWith(rejectBirthdayGift: []);
          break;
      }
    }
  }

  Future<bool> sendApprovedBirthdayGiftFromUI({
    required double reqid,
    required String remarks,
    required String amount,
    required String userName,
    required String validDates,
  }) async {
    return await giftRepository.approvedBirthdayGiftRequest(
      reqid: reqid,
      remarks: remarks,
      amount: amount,
      userName: userName,
      validDates: validDates,
    );
  }

  Future<bool> rejectBirthdayGiftFromUI({
    required double reqid,
    required String userName,
  }) async {
    return await giftRepository.rejectBirthdayGiftRequest(
      reqid: reqid,
      userName: userName,
    );
  }

  Future<bool> reverseBirthdayGiftFromUI({
    required double reqid,
    required String userName,
  }) async {
    return await giftRepository.reverseBirthdayGiftRequest(
      reqid: reqid,
      userName: userName,
    );
  }

  Future<bool> reverseBirthdayGiftFromUIRejected({
    required double reqid,
    required String userName,
  }) async {
    return await giftRepository.reverseBirthdayGiftRequestRejected(
      reqid: reqid,
      userName: userName,
    );
  }
Future<bool> checkBirthdayGiftincreesFromUI({
    required double reqid,
    required String remarks,
    required String amount,
    required String userName,
    required String validDates,
  }) async {
    return await giftRepository.checkbirthdayGiftPriceIncreesRequest(
      reqid: reqid,
      remarks: remarks,
      amount: amount,
      userName: userName,
      validDates: validDates,
    );
  }
  void resetData() {
    state = BirthdayGiftIncreesState();
  }
}

final birthdayGiftIncreesProvider = StateNotifierProvider<BirthdayGiftIncreesNotifier, BirthdayGiftIncreesState>((ref) {
  final giftRepository = ref.read(giftRepositoryIncreesProvider);
  return BirthdayGiftIncreesNotifier(giftRepository);
});

// Reusing the existing providers from special_gift_provider
final giftRepositoryIncreesProvider = Provider((ref) {
  final apiService = ApiService(const FlutterSecureStorage());
  return GiftsRepository(apiService);
});

class BirthdayGiftIncreesState {
  final List<BirthdayIncressGiftRequest> pendingBirthdayGift;
  final List<BirthdayIncressGiftRequest> checkedBirthdayGift;
  final List<BirthdayIncressGiftRequest> approvedBirthdayGift;
  final List<BirthdayIncressGiftRequest> rejectBirthdayGift;

  BirthdayGiftIncreesState({
    this.pendingBirthdayGift = const [],
    this.checkedBirthdayGift = const [],
    this.approvedBirthdayGift = const [],
    this.rejectBirthdayGift = const [],
  });

  BirthdayGiftIncreesState copyWith({
    List<BirthdayIncressGiftRequest>? pendingBirthdayGift,
    List<BirthdayIncressGiftRequest>? checkedBirthdayGift,
    List<BirthdayIncressGiftRequest>? approvedBirthdayGift,
    List<BirthdayIncressGiftRequest>? rejectBirthdayGift,
  }) {
    return BirthdayGiftIncreesState(
      pendingBirthdayGift: pendingBirthdayGift ?? this.pendingBirthdayGift,
      checkedBirthdayGift: checkedBirthdayGift ?? this.checkedBirthdayGift,
      approvedBirthdayGift: approvedBirthdayGift ?? this.approvedBirthdayGift,
      rejectBirthdayGift: rejectBirthdayGift ?? this.rejectBirthdayGift,
    );
  }
}
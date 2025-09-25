import 'package:ballys_reservation_app/data/repositories/gifts_repository.dart';
import 'package:ballys_reservation_app/data/services/api_service.dart';
import 'package:ballys_reservation_app/models/gift/gest_gift_data.dart';
import 'package:ballys_reservation_app/models/gift/gift_type.dart';
import 'package:ballys_reservation_app/models/gift/prev_gift.dart';
import 'package:ballys_reservation_app/models/gift/special_gift_request.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class GiftNotifier extends StateNotifier<GiftState> {
  final GiftsRepository giftRepository;

  GiftNotifier(this.giftRepository) : super(GiftState());

  Future<void> getSpecialGiftData(int iid, String text1) async {
    try {
      var gifttList = await giftRepository.getSpecialGift(iid, text1);
      print('API Response for iid $iid: $gifttList'); // <- debug here

      switch (iid) {
        case 8890:
          state = state.copyWith(pendinggift: gifttList);
          break;
        case 8891:
          state = state.copyWith(approvedgift: gifttList);
          break;
        case 8893:
          state = state.copyWith(rejectgift: gifttList);
          break;
      }
    } catch (e) {
      print('Error fetching gifts for iid $iid: $e');
      // Optional: reset that specific state instead of all
      switch (iid) {
        case 8890:
          state = state.copyWith(pendinggift: []);
          break;
        case 8891:
          state = state.copyWith(approvedgift: []);
          break;
        case 8893:
          state = state.copyWith(rejectgift: []);
          break;
      }
    }
  }

  Future<void> getGestgiftGift(
    int iid,
    String text1,
    String text2,
    String text3,
    String text4,
    String text5,
  ) async {
    try {
      var giftList = await giftRepository.getgestgiftGift(
        iid,
        text1,
        text2,
        text3,
        text4,
        text5,
      );
      state = state.copyWith(guestGiftData: giftList);
    } catch (e) {
      print("Error fetching guest gift data: $e");
      state = state.copyWith(guestGiftData: []);
    }
  }

  Future<void> getGiftForList() async {
    try {
      final giftForList = await giftRepository.getGiftForList();
      state = state.copyWith(giftForList: giftForList);
    } catch (e) {
      print("Error fetching gift for list: $e");
      state = state.copyWith(giftForList: []);
    }
  }

  Future<bool> sendSpecialGiftFromUI({
    required String mid,
    required String memberName,
    required String fromDateTime,
    required String toDateTime,
    required String arrivalDate,
    required String departureDate,
    required String giftForCode,
    required String chipTypeUI, // "OTP Chips" | "NC Chips"
    required String amountUI, // might include commas
    required String remarks,
    required String userName,
  }) async {
    // map UI chip label -> API code
    String mapChip(String v) {
      final t = v.trim().toUpperCase();
      if (t.contains('NC')) return 'NC_CHIPS';
      return 'OTP_CHIPS';
    }

    String cleanAmount(String v) => v.replaceAll(',', '').trim();

    // Pull guest metrics from current state (after "Guest Data" was fetched)
    final data = state.guestGiftData.isNotEmpty
        ? state.guestGiftData.first
        : null;

    try {
      // Call the repository method and get the full response
      final apiResponse = await giftRepository.insertSpecialGiftRequest(
        mid: mid,
        memberName: memberName,
        fromDateTime: fromDateTime,
        toDateTime: toDateTime,
        arrivalDate: arrivalDate,
        departureDate: departureDate,
        giftForCode: (giftForCode.isEmpty) ? "SPECIAL GIFT" : giftForCode,
        chipTypeCode: mapChip(chipTypeUI),
        amount: cleanAmount(amountUI),
        remarks: remarks,
        guestDrop: data?.guestDrop,
        tmpCashout: data?.tmpCashout,
        res: data?.res,
        actD: data?.actD,
        tmpAvgBet: data?.tmpAvgBet,
        guestCoupon: data?.guestCoupon,
        flushCoupon: data?.flushCoupon,
        flushActDrop: data?.flushActDrop,
        tmpPoint: data?.tmpPoint,
        tmphh: data?.tmphh,
        tmpCommpaid: data?.tmpCommpaid,
        grt: data?.grt,
        userName: userName,
      );

      // Extract Return_Serial from the response and update state
      String? returnSerial;
      if (apiResponse != null && 
          apiResponse.containsKey('CommonResult') &&
          apiResponse['CommonResult'] is Map<String, dynamic> &&
          apiResponse['CommonResult']['Table'] is List &&
          (apiResponse['CommonResult']['Table'] as List).isNotEmpty) {
        
        final firstTableEntry = (apiResponse['CommonResult']['Table'] as List)[0];
        if (firstTableEntry is Map<String, dynamic> && 
            firstTableEntry.containsKey('Return_Serial')) {
          returnSerial = firstTableEntry['Return_Serial'].toString();
        }
      }

      // Update the state with the API response and return serial
      state = state.copyWith(
        lastApiResponse: apiResponse,
        lastReturnSerial: returnSerial,
      );

      // Return true if the API call was successful
      return apiResponse?['strRturnRes'] == true;
      
    } catch (e) {
      print('Error in sendSpecialGiftFromUI: $e');
      // Clear the response data on error
      state = state.copyWith(
        lastApiResponse: null,
        lastReturnSerial: null,
      );
      return false;
    }
  }

  Future<void> getprvGift(String text1) async {
    try {
      final prvgiftList = await giftRepository.getPrvGiftList(text1);
      state = state.copyWith(prvgiftList: prvgiftList);
    } catch (e, stack) {
      print("Error fetching gift for list: $e");
      print(stack);
      state = state.copyWith(prvgiftList: []);
    }
  }

  Future<bool> sendApprovedSpecialGiftFromUI({
    required double reqid,
    required String remarks,
    required String amount,
    required String userName,
  }) async {
    return await giftRepository.approvedSPecialgiftRequest(
      reqid: reqid,
      remarks: remarks,
      amount: amount,
      userName: userName,
    );
  }

  Future<bool> rejectSpecialGiftFromUI({
    required double reqid,
    required String userName,
  }) async {
    return await giftRepository.rejectSPecialgiftRequest(
      reqid: reqid,
      userName: userName,
    );
  }

  void resetData() {
    state = GiftState();
  }

  // Method to clear the last API response data
  void clearLastApiResponse() {
    state = state.copyWith(
      lastApiResponse: null,
      lastReturnSerial: null,
    );
  }
}

final flutterSecureStorageProvider = Provider(
  (ref) => const FlutterSecureStorage(),
);

final apiServiceProvider = Provider((ref) {
  final storage = ref.read(flutterSecureStorageProvider);
  return ApiService(storage);
});

final giftRepositoryProvider = Provider((ref) {
  final apiService = ref.read(apiServiceProvider);
  return GiftsRepository(apiService);
});

final giftProvider = StateNotifierProvider<GiftNotifier, GiftState>((ref) {
  final giftRepository = ref.read(giftRepositoryProvider);
  return GiftNotifier(giftRepository);
});

class GiftState {
  final List<SpecialGiftRequest> pendinggift;
  final List<SpecialGiftRequest> approvedgift;
  final List<SpecialGiftRequest> rejectgift;
  final List<GestGiftData> guestGiftData;
  final List<GiftType> giftForList;
  final List<PrevGift> prvgiftList;
  final Map<String, dynamic>? lastApiResponse; // Store the full API response
  final String? lastReturnSerial; // Store the extracted Return_Serial

  GiftState({
    this.pendinggift = const [],
    this.approvedgift = const [],
    this.rejectgift = const [],
    this.guestGiftData = const [],
    this.giftForList = const [],
    this.prvgiftList = const [],
    this.lastApiResponse,
    this.lastReturnSerial,
  });

  GiftState copyWith({
    List<SpecialGiftRequest>? pendinggift,
    List<SpecialGiftRequest>? approvedgift,
    List<SpecialGiftRequest>? rejectgift,
    List<GestGiftData>? guestGiftData,
    List<GiftType>? giftForList,
    List<PrevGift>? prvgiftList,
    Map<String, dynamic>? lastApiResponse,
    String? lastReturnSerial,
  }) {
    return GiftState(
      pendinggift: pendinggift ?? this.pendinggift,
      approvedgift: approvedgift ?? this.approvedgift,
      rejectgift: rejectgift ?? this.rejectgift,
      guestGiftData: guestGiftData ?? this.guestGiftData,
      giftForList: giftForList ?? this.giftForList,
      prvgiftList: prvgiftList ?? this.prvgiftList,
      lastApiResponse: lastApiResponse ?? this.lastApiResponse,
      lastReturnSerial: lastReturnSerial ?? this.lastReturnSerial,
    );
  }
}
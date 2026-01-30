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
      print('Error in getSpecialGiftData: $e');
      // Reset that specific state instead of all
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
      print('Error in getGestgiftGift: $e');
      state = state.copyWith(guestGiftData: []);
    }
  }

  Future<void> getGiftForList() async {
    try {
      final giftForList = await giftRepository.getGiftForList();
      state = state.copyWith(giftForList: giftForList);
    } catch (e) {
      print('Error in getGiftForList: $e');
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
    required String chipTypeUI,
    required String amountUI,
    required String remarks,
    required String userName,
  }) async {
    // Map UI chip label -> API code
    String mapChip(String v) {
      final t = v.trim().toUpperCase();
      if (t.contains('NC')) return 'NC_CHIPS';
      return 'OTP_CHIPS';
    }

    String cleanAmount(String v) => v.replaceAll(',', '').trim();

    // Pull guest metrics from current state
    final data = state.guestGiftData.isNotEmpty
        ? state.guestGiftData.first
        : null;

    try {
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

      print('API Response in sendSpecialGiftFromUI: $apiResponse');

      // Extract Return_Serial from the response
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

      // Check if the API call was successful
      bool isSuccess = _isApiResponseSuccessful(apiResponse);
      print('Is API call successful: $isSuccess');
      
      return isSuccess;
      
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

  Future<bool> increaceBirtdayGiftFromUI({
    required String mid,
    required String memberName,
    required String fromDateTime,
    required String toDateTime,
    required String arrivalDate,
    required String departureDate,
    required String giftForCode,
    required String chipTypeUI,
    required String amountUI,
    required String remarks,
    required String userName,
    required String previousGiftPrice,
  }) async {
    // Map UI chip label -> API code
    String mapChip(String v) {
      final t = v.trim().toUpperCase();
      if (t.contains('NC')) return 'NC_CHIPS';
      return 'OTP_CHIPS';
    }

    String cleanAmount(String v) => v.replaceAll(',', '').trim();

    // Pull guest metrics from current state
    final data = state.guestGiftData.isNotEmpty
        ? state.guestGiftData.first
        : null;

    try {
      print('Starting increaceBirtdayGiftFromUI with data:');
      print('MID: $mid, Name: $memberName');
      print('New Amount: $amountUI, Previous: $previousGiftPrice');
      print('Chip Type: $chipTypeUI, Gift For: $giftForCode');
      
      final apiResponse = await giftRepository.increeseBirthdayGiftRequest(
        mid: mid,
        memberName: memberName,
        fromDateTime: fromDateTime,
        toDateTime: toDateTime,
        arrivalDate: arrivalDate,
        departureDate: departureDate,
        giftForCode: (giftForCode.isEmpty) ? "BIRTHDAY_GIFT" : giftForCode,
        chipTypeCode: mapChip(chipTypeUI),
        amount: cleanAmount(amountUI),
        remarks: remarks,
        previousGiftPrice: "100",
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

      print('API Response in increaceBirtdayGiftFromUI: $apiResponse');

      // Extract Return_Serial from the response
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

      // Check if the API call was successful
      bool isSuccess = _isApiResponseSuccessful(apiResponse);
      print('Is API call successful: $isSuccess');
      
      return isSuccess;
      
    } catch (e) {
      print('Error in increaceBirtdayGiftFromUI: $e');
      // Clear the response data on error
      state = state.copyWith(
        lastApiResponse: null,
        lastReturnSerial: null,
      );
      return false;
    }
  }

  // Helper method to check if API response indicates success
  bool _isApiResponseSuccessful(Map<String, dynamic>? apiResponse) {
    if (apiResponse == null) {
      print('API Response is null');
      return false;
    }

    print('Checking API response for success...');
    print('Full API Response: $apiResponse');

    // Check 1: Look for CommonResult with Table data
    if (apiResponse.containsKey('CommonResult') &&
        apiResponse['CommonResult'] != null) {
      
      final commonResult = apiResponse['CommonResult'];
      print('CommonResult found: $commonResult');
      
      if (commonResult is Map<String, dynamic> &&
          commonResult['Table'] is List) {
        
        final table = commonResult['Table'] as List;
        print('Table found with ${table.length} entries');
        
        if (table.isNotEmpty) {
          print('Table has data - considering this a success');
          return true;
        }
      }
    }

    // Check 2: Look for strRturnRes field (various possible formats)
    if (apiResponse.containsKey('strRturnRes')) {
      final strRturnRes = apiResponse['strRturnRes'];
      print('strRturnRes found: $strRturnRes (type: ${strRturnRes.runtimeType})');
      
      // Check for boolean true
      if (strRturnRes == true) {
        print('strRturnRes is boolean true');
        return true;
      }
      
      // Check for string representations of true
      if (strRturnRes is String) {
        final upperValue = strRturnRes.toUpperCase();
        if (upperValue == 'TRUE' || upperValue == 'T' || upperValue == 'SUCCESS') {
          print('strRturnRes indicates success (string value: $strRturnRes)');
          return true;
        }
      }
      
      // Check for numeric 1 (sometimes APIs return 1 for success)
      if (strRturnRes == 1 || strRturnRes == '1') {
        print('strRturnRes is 1 (success)');
        return true;
      }
    }

    // Check 3: Look for success indicators in the response
    if (apiResponse.containsKey('success')) {
      final success = apiResponse['success'];
      print('success field found: $success');
      if (success == true || success == 'true' || success == 'T' || success == 1) {
        return true;
      }
    }

    // Check 4: Look for status field
    if (apiResponse.containsKey('status')) {
      final status = apiResponse['status'];
      print('status field found: $status');
      if (status == 'success' || status == 'SUCCESS' || status == 'ok' || status == 'OK') {
        return true;
      }
    }

    // Check 5: Look for error indicators (if no error, assume success)
    bool hasError = apiResponse.containsKey('error') || 
                    apiResponse.containsKey('Error') ||
                    (apiResponse.containsKey('strRturnRes') && 
                     apiResponse['strRturnRes'] == false);
    
    if (!hasError && apiResponse.isNotEmpty) {
      print('No error indicators found and response is not empty - considering success');
      return true;
    }

    print('No success indicators found - returning false');
    return false;
  }

  Future<void> getprvGift(String text1) async {
    try {
      final prvgiftList = await giftRepository.getPrvGiftList(text1);
      state = state.copyWith(prvgiftList: prvgiftList);
    } catch (e, stack) {
      print('Error in getprvGift: $e');
      print('Stack trace: $stack');
      state = state.copyWith(prvgiftList: []);
    }
  }

  Future<bool> sendApprovedSpecialGiftFromUI({
    required double reqid,
    required String remarks,
    required String amount,
    required String userName,
    required String validDates,
  }) async {
    return await giftRepository.approvedSPecialgiftRequest(
      reqid: reqid,
      remarks: remarks,
      amount: amount,
      userName: userName,
      validDates: validDates,
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

  Future<bool> reverseSpecialGiftFromUI({
    required double reqid,
    required String userName,
  }) async {
    return await giftRepository.reverseSpecialGiftRequest(
      reqid: reqid,
      userName: userName,
    );
  }

  Future<bool> reverseSpecialGiftFromUIrejcted({
    required double reqid,
    required String userName,
  }) async {
    return await giftRepository.reverseSpecialGiftRequestRejected(
      reqid: reqid,
      userName: userName,
    );
  }

  void resetData() {
    state = GiftState();
  }

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
  final Map<String, dynamic>? lastApiResponse;
  final String? lastReturnSerial;

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
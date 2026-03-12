import 'package:ballys_reservation_app/data/repositories/birthday_repository.dart';
import 'package:ballys_reservation_app/data/services/api_service.dart';
import 'package:ballys_reservation_app/models/birthday.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class BirthdaysNotifier extends StateNotifier<Map<String, List<Birthday>>> {
  final BirthdayRepository birthdayRepository;

  BirthdaysNotifier(this.birthdayRepository)
    : super({
        'past': [],
        'recentPast': [],
        'recentUpcoming': [],
        'upcoming': [],
      });
void clearBirthdays() {
    state = {
      'past': [],
      'recentPast': [],
      'recentUpcoming': [],
      'upcoming': [],
    };
  }
  Future<Map<String, List<Birthday>>> getBirthdays() async {
    try {
      final birthdayMap = await birthdayRepository.getBirthdays();
      state = {
        'past': birthdayMap['past'] ?? [],
        'recentPast': birthdayMap['recentPast'] ?? [],
        'recentUpcoming': birthdayMap['recentUpcoming'] ?? [],
        'upcoming': birthdayMap['upcoming'] ?? [],
      };
      return state;
    } catch (e) {
      state = {
        'past': [],
        'recentPast': [],
        'recentUpcoming': [],
        'upcoming': [],
      };
      return state;
    }
  }
 Future<String> sendWhatsappMessage({
    required String mname,
    required String whatsappNumber,
    required String gift,
    required String mid,
    required String memberMobile,
  }) async {
    try {
      final response = await birthdayRepository.sendWhatsappMessage(
        gift: gift,
        mname: mname,
        whatsappNumber: whatsappNumber,
        mid: mid,
        memberMobile: memberMobile,
      );
      return response;
    } catch (e) {
      return "Error sending message";
    }
  }
  Future<String> sendWhatsappMessagePriceIncrease({
    required String mname,
    required String whatsappNumber,
    required String gift,
    required String mid,
    required String memberMobile,
    required String previousAmount,
    required String chiptype,
  }) async {
    try {
    print("=== sendWhatsappMessagePriceIncrease DEBUG ===");
      print("mname: $mname");
      print("whatsappNumber: $whatsappNumber");
      print("gift: $gift");
      print("mid: $mid");
      print("memberMobile: $memberMobile");
         print("previousAmount: $previousAmount");
          print("chiptype: $chiptype");
      print("=============================================");
      final response = await birthdayRepository.sendWhatsappMessagetpPriceincrease(
        gift: gift,
        mname: mname,
        whatsappNumber: whatsappNumber,
        mid: mid,
        memberMobile: memberMobile,
        previousAmount:previousAmount,
        chiptype:chiptype,

      );
      return response;
    } catch (e) {
      return "Error sending message";
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

final birthdaysRepositoryProvider = Provider((ref) {
  final apiService = ref.read(apiServiceProvider);
  return BirthdayRepository(apiService);
});

final birthdayProvider =
    StateNotifierProvider<BirthdaysNotifier, Map<String, List<Birthday>>>((
      ref,
    ) {
      final birthdayRepository = ref.read(birthdaysRepositoryProvider);
      return BirthdaysNotifier(birthdayRepository);
    });

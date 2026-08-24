import 'package:ballys_reservation_app/data/repositories/birthday_repository.dart';
import 'package:ballys_reservation_app/data/services/api_service.dart';
import 'package:ballys_reservation_app/models/birthday.dart';
import 'package:ballys_reservation_app/providers/app_mode_setting_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ballys_reservation_app/utils/secure_storage.dart';

class BirthdaysNotifier extends StateNotifier<Map<String, List<Birthday>>> {
  final BirthdayRepository birthdayRepository;
  final Ref ref;

  BirthdaysNotifier(this.birthdayRepository, this.ref)
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
      final appMode = ref.read(appmodeSettingsProvider).appMode;
      final birthdayMap = await birthdayRepository.getBirthdays(
        isMyDataMode: appMode == AppMode.myData,
      );
      print('birthdays provider -> past: ${birthdayMap['past']?.length}, recentPast: ${birthdayMap['recentPast']?.length}, recentUpcoming: ${birthdayMap['recentUpcoming']?.length}, upcoming: ${birthdayMap['upcoming']?.length}');
      state = {
        'past': birthdayMap['past'] ?? [],
        'recentPast': birthdayMap['recentPast'] ?? [],
        'recentUpcoming': birthdayMap['recentUpcoming'] ?? [],
        'upcoming': birthdayMap['upcoming'] ?? [],
      };
      return state;
    } catch (e, st) {
      print('getBirthdays ERROR: $e');
      print('getBirthdays STACK: $st');
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
  (ref) => SecureStorage.instance,
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
      final notifier = BirthdaysNotifier(birthdayRepository, ref);

      // Birthdays are fetched under a scope code that depends on the app mode,
      // so cached results go stale the moment the mode changes. Dropping them
      // here makes BirthdayScreen hit the API again next time it opens instead
      // of showing the previous mode's data until a manual refresh.
      ref.listen<AppModeSettings>(appmodeSettingsProvider, (previous, next) {
        if (previous?.appMode != next.appMode) {
          notifier.clearBirthdays();
        }
      });

      return notifier;
    });

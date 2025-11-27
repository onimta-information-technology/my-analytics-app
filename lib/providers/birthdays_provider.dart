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

  Future<String> sendWhatsappMessage(
      {required String mname,
      required String whatsappNumber,
      required String gift,
        required String mid,
    required String memberMobile,}) async {
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
}

final flutterSecureStorageProvider =
    Provider((ref) => const FlutterSecureStorage());

final apiServiceProvider = Provider((ref) {
  final storage = ref.read(flutterSecureStorageProvider);
  return ApiService(storage);
});

final birthdaysRepositoryProvider = Provider((ref) {
  final apiService = ref.read(apiServiceProvider);
  return BirthdayRepository(apiService);
});

final birthdayProvider =
    StateNotifierProvider<BirthdaysNotifier, Map<String, List<Birthday>>>(
        (ref) {
  final birthdayRepository = ref.read(birthdaysRepositoryProvider);
  return BirthdaysNotifier(birthdayRepository);
});

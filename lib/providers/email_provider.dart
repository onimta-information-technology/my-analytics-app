import 'package:ballys_reservation_app/data/repositories/email_repository.dart';
import 'package:ballys_reservation_app/data/services/api_service.dart';
import 'package:ballys_reservation_app/models/add_phone/email_response.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ballys_reservation_app/utils/secure_storage.dart';

class EmailState {
  final bool isLoading;
  final EmailResponse? emailResponse;
  final String? error;

  EmailState({
    this.isLoading = false,
    this.emailResponse,
    this.error,
  });

  EmailState copyWith({
    bool? isLoading,
    EmailResponse? emailResponse,
    String? error,
  }) {
    return EmailState(
      isLoading: isLoading ?? this.isLoading,
      emailResponse: emailResponse ?? this.emailResponse,
      error: error ?? this.error,
    );
  }
}

class EmailNotifier extends StateNotifier<EmailState> {
  final EmailRepository emailRepository;

  EmailNotifier(this.emailRepository) : super(EmailState());

  Future<bool> addOrUpdateEmail({
    required String memberId,
    required String email,
    required String memberName,
    required int emailType, // 1 for Email1, 2 for Email2
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await emailRepository.addOrUpdateEmail(
        memberId: memberId,
        email: email,
        memberName: memberName,
        emailType: emailType,
      );

      if (response != null) {
        state = state.copyWith(
          isLoading: false,
          emailResponse: response,
        );
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to add/update email',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return false;
    }
  }

  void reset() {
    state = EmailState();
  }
}

// Providers
final emailRepositoryProvider = Provider((ref) {
  final apiService = ref.read(apiServiceProvider);
  return EmailRepository(apiService);
});

final emailProvider = StateNotifierProvider<EmailNotifier, EmailState>((ref) {
  final emailRepository = ref.read(emailRepositoryProvider);
  return EmailNotifier(emailRepository);
});

// Note: Make sure apiServiceProvider is available in your project
// If not already defined, add this:
final flutterSecureStorageProvider = Provider(
  (ref) => SecureStorage.instance,
);

final apiServiceProvider = Provider((ref) {
  final storage = ref.read(flutterSecureStorageProvider);
  return ApiService(storage);
});
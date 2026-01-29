import 'package:ballys_reservation_app/data/repositories/primary_contact_repository.dart';
import 'package:ballys_reservation_app/data/services/api_service.dart';
import 'package:ballys_reservation_app/models/primary_contact_response.dart';
import 'package:ballys_reservation_app/providers/marketing_provider.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

final primaryContactRepositoryProvider = Provider<PrimaryContactRepository>((ref) {
  final apiService = ref.read(apiServiceProvider);
  return PrimaryContactRepository(apiService);
});

class PrimaryContactState {
  final bool isLoading;
  final PrimaryContactResponse? response;
  final String? error;

  PrimaryContactState({
    this.isLoading = false,
    this.response,
    this.error,
  });

  PrimaryContactState copyWith({
    bool? isLoading,
    PrimaryContactResponse? response,
    String? error,
  }) {
    return PrimaryContactState(
      isLoading: isLoading ?? this.isLoading,
      response: response ?? this.response,
      error: error ?? this.error,
    );
  }
}

class PrimaryContactNotifier extends StateNotifier<PrimaryContactState> {
  final PrimaryContactRepository repository;

  PrimaryContactNotifier(this.repository) : super(PrimaryContactState());

  Future<bool> setPrimaryPhone({
    required String memberId,
    required String phoneNumber,
    required String memberName,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await repository.setPrimaryPhone(
        memberId: memberId,
        phoneNumber: phoneNumber,
        memberName: memberName,
      );

      if (response != null) {
        state = state.copyWith(isLoading: false, response: response);
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to set primary phone',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> setPrimaryEmail({
    required String memberId,
    required String email,
    required String memberName,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await repository.setPrimaryEmail(
        memberId: memberId,
        email: email,
        memberName: memberName,
      );

      if (response != null) {
        state = state.copyWith(isLoading: false, response: response);
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to set primary email',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> setPrimaryWhatsApp({
    required String memberId,
    required String whatsappNumber,
    required String memberName,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await repository.setPrimaryWhatsApp(
        memberId: memberId,
        whatsappNumber: whatsappNumber,
        memberName: memberName,
      );

      if (response != null) {
        state = state.copyWith(isLoading: false, response: response);
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to set primary WhatsApp',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }
}

final primaryContactProvider =
    StateNotifierProvider<PrimaryContactNotifier, PrimaryContactState>((ref) {
  final repository = ref.read(primaryContactRepositoryProvider);
  return PrimaryContactNotifier(repository);
});
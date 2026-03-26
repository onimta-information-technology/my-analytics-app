// lib/providers/customer_due_diligence_provider.dart

import 'package:ballys_reservation_app/data/repositories/customer_due_diligence_repository.dart';
import 'package:ballys_reservation_app/data/services/api_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// ─── Shared low-level providers (reuse or define once app-wide) ───────────────

final _secureStorageProvider = Provider((ref) => const FlutterSecureStorage());

final _apiServiceProvider = Provider((ref) {
  final storage = ref.read(_secureStorageProvider);
  return ApiService(storage);
});

final cddRepositoryProvider = Provider((ref) {
  final apiService = ref.read(_apiServiceProvider);
  return CustomerDueDiligenceRepository(apiService);
});

// ─── CDD form state ───────────────────────────────────────────────────────────

class CDDFormState {
  final String? idType;              // "PASSPORT" | "NIC"
  final String identificationNumber;
  final String? sourceOfFunds;
  final String? clientType;
  final String? natureOfBusiness;
  final bool isSubmitting;
  final String? errorMessage;
  final bool isSuccess;

  const CDDFormState({
    this.idType,
    this.identificationNumber = '',
    this.sourceOfFunds,
    this.clientType,
    this.natureOfBusiness,
    this.isSubmitting = false,
    this.errorMessage,
    this.isSuccess = false,
  });

  CDDFormState copyWith({
    String? idType,
    String? identificationNumber,
    String? sourceOfFunds,
    String? clientType,
    String? natureOfBusiness,
    bool? isSubmitting,
    String? errorMessage,
    bool? isSuccess,
    bool clearError = false,
  }) {
    return CDDFormState(
      idType: idType ?? this.idType,
      identificationNumber: identificationNumber ?? this.identificationNumber,
      sourceOfFunds: sourceOfFunds ?? this.sourceOfFunds,
      clientType: clientType ?? this.clientType,
      natureOfBusiness: natureOfBusiness ?? this.natureOfBusiness,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isSuccess: isSuccess ?? this.isSuccess,
    );
  }
}

class CDDFormNotifier extends StateNotifier<CDDFormState> {
  final CustomerDueDiligenceRepository repository;

  CDDFormNotifier(this.repository) : super(const CDDFormState());

  void setIdType(String value) =>
      state = state.copyWith(idType: value, clearError: true);

  void setIdentificationNumber(String value) =>
      state = state.copyWith(identificationNumber: value);

  void setSourceOfFunds(String value) =>
      state = state.copyWith(sourceOfFunds: value, clearError: true);

  void setClientType(String value) =>
      state = state.copyWith(clientType: value, clearError: true);

  void setNatureOfBusiness(String value) =>
      state = state.copyWith(natureOfBusiness: value, clearError: true);

  void reset() => state = const CDDFormState();

  Future<bool> submit() async {
    if (state.idType == null ||
        state.identificationNumber.isEmpty ||
        state.sourceOfFunds == null ||
        state.clientType == null ||
        state.natureOfBusiness == null) {
      state = state.copyWith(
        errorMessage: 'Please complete all fields before submitting.',
      );
      return false;
    }

    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final result = await repository.submitCDD(
        passportOrNic: state.idType!,
        identificationNumber: state.identificationNumber,
        sourceOfFunds: state.sourceOfFunds!,
        clientType: state.clientType!,
        natureOfBusiness: state.natureOfBusiness!,
      );
      state = state.copyWith(isSubmitting: false, isSuccess: result.success);
      return result.success;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'Submission failed: ${e.toString()}',
      );
      return false;
    }
  }
}

final cddFormProvider =
    StateNotifierProvider.autoDispose<CDDFormNotifier, CDDFormState>((ref) {
  final repository = ref.read(cddRepositoryProvider);
  return CDDFormNotifier(repository);
});
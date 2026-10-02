import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_user_application/core/network/api_exception.dart';
import 'package:food_user_application/core/network/dio_client.dart';
import 'package:food_user_application/core/providers/core_providers.dart';
import 'package:food_user_application/features/registration/domain/registration_form_data.dart';

class RegistrationUiState {
  const RegistrationUiState({
    this.currentStep = 0,
    this.isSubmitting = false,
    this.submitError,
    this.isSubmitted = false,
  });

  final int currentStep;
  final bool isSubmitting;
  final String? submitError;
  final bool isSubmitted;

  RegistrationUiState copyWith({
    int? currentStep,
    bool? isSubmitting,
    String? submitError,
    bool clearError = false,
    bool? isSubmitted,
  }) {
    return RegistrationUiState(
      currentStep: currentStep ?? this.currentStep,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      submitError: clearError ? null : (submitError ?? this.submitError),
      isSubmitted: isSubmitted ?? this.isSubmitted,
    );
  }
}

/// Drives the 4-step wizard. The actual form fields live on [form], a plain
/// mutable object the step widgets write into directly — see
/// [RegistrationFormData] for why that's simpler here than a `copyWith`
/// immutable model. Riverpod state ([RegistrationUiState]) only tracks the
/// wizard's own transient UI: which step is showing and submit progress.
class RegistrationController extends Notifier<RegistrationUiState> {
  late final RegistrationFormData form;

  @override
  RegistrationUiState build() {
    form = RegistrationFormData();
    return const RegistrationUiState();
  }

  String? _inMemoryToken;

  void prefillPhone(String phone) {
    form.ownerPhone = phone;
  }

  void setRegistrationToken(String token) {
    _inMemoryToken = token;
  }

  void goToStep(int step) => state = state.copyWith(currentStep: step);

  void nextStep() {
    if (state.currentStep < 3) {
      state = state.copyWith(currentStep: state.currentStep + 1);
    }
  }

  void previousStep() {
    if (state.currentStep > 0) {
      state = state.copyWith(currentStep: state.currentStep - 1);
    }
  }

  Future<void> submit() async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final dio = ref.read(dioProvider);
      final formData = await form.toFormData();

      // Read the registration token from in-memory or dedicated storage key
      final tokenStorage = ref.read(tokenStorageProvider);
      final regToken = _inMemoryToken ?? await tokenStorage.registrationToken;
      debugPrint(
        '🔑 [REGISTER] registrationToken: ${regToken != null ? "exists (${regToken.length} chars)" : "NULL"}',
      );

      if (regToken == null || regToken.isEmpty) {
        debugPrint('❌ [REGISTER] No registration token! User must re-verify OTP.');
        state = state.copyWith(
          isSubmitting: false,
          submitError: 'Session expired. Please go back and verify OTP again.',
        );
        return;
      }

      // Attach registrationToken into form fields as well
      formData.fields.add(MapEntry('registrationToken', regToken));

      // Post with Authorization header, x-registration-token header, and query param
      await dio.post(
        '/food/restaurant/register',
        queryParameters: {'token': regToken},
        data: formData,
        options: Options(
          headers: {
            'Authorization': 'Bearer $regToken',
            'x-registration-token': regToken,
          },
        ),
      );

      // Clear registration token after successful submission
      await tokenStorage.clearRegistrationToken();
      _inMemoryToken = null;
      state = state.copyWith(isSubmitting: false, isSubmitted: true);
    } on DioException catch (e) {
      debugPrint('❌ [REGISTER] DioException: ${e.response?.statusCode} ${e.response?.data}');
      final message = e.error is ApiException
          ? (e.error as ApiException).message
          : 'Registration failed. Please try again.';
      state = state.copyWith(isSubmitting: false, submitError: message);
    }
  }
}

final registrationControllerProvider =
    NotifierProvider<RegistrationController, RegistrationUiState>(
      RegistrationController.new,
    );

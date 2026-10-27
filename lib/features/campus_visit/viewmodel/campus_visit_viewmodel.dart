import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/failures.dart';
import '../../../core/providers/core_providers.dart';

/// Form state for the campus visit booking form.
class CampusVisitFormState {
  final String fullName;
  final String mobileNumber;
  final String email;
  final DateTime? visitDate;
  final String? session; // 'morning' | 'afternoon'
  final int delegationSize;
  final String purpose;
  final bool isSubmitting;
  final String? errorMessage;
  final String? successVisitId;

  const CampusVisitFormState({
    this.fullName = '',
    this.mobileNumber = '',
    this.email = '',
    this.visitDate,
    this.session,
    this.delegationSize = 1,
    this.purpose = '',
    this.isSubmitting = false,
    this.errorMessage,
    this.successVisitId,
  });

  CampusVisitFormState copyWith({
    String? fullName,
    String? mobileNumber,
    String? email,
    DateTime? visitDate,
    String? session,
    int? delegationSize,
    String? purpose,
    bool? isSubmitting,
    String? errorMessage,
    String? successVisitId,
    bool clearError = false,
    bool clearSuccess = false,
    bool clearDate = false,
    bool clearSession = false,
  }) {
    return CampusVisitFormState(
      fullName: fullName ?? this.fullName,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      email: email ?? this.email,
      visitDate: clearDate ? null : (visitDate ?? this.visitDate),
      session: clearSession ? null : (session ?? this.session),
      delegationSize: delegationSize ?? this.delegationSize,
      purpose: purpose ?? this.purpose,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successVisitId: clearSuccess
          ? null
          : (successVisitId ?? this.successVisitId),
    );
  }

  /// True when the form has enough data to attempt submission.
  bool get isReadyToSubmit =>
      fullName.trim().length >= 2 &&
      mobileNumber.trim().isNotEmpty &&
      email.trim().isNotEmpty &&
      visitDate != null &&
      session != null &&
      delegationSize >= 1 &&
      purpose.trim().length >= 20 &&
      !isSubmitting;
}

/// ViewModel for the Campus Visit booking form.
///
/// Follows the existing Notifier pattern:
/// imperative mutations, Riverpod state, delegate to repository.
class CampusVisitViewModel extends Notifier<CampusVisitFormState> {
  @override
  CampusVisitFormState build() => const CampusVisitFormState();

  // ── Field setters ─────────────────────────────────────────────────────────

  void setFullName(String v) =>
      state = state.copyWith(fullName: v, clearError: true);

  void setMobileNumber(String v) =>
      state = state.copyWith(mobileNumber: v, clearError: true);

  void setEmail(String v) => state = state.copyWith(email: v, clearError: true);

  void setVisitDate(DateTime? d) =>
      state = state.copyWith(visitDate: d, clearError: true);

  void setSession(String? s) =>
      state = state.copyWith(session: s, clearError: true);

  void setDelegationSize(int n) {
    final clamped = n.clamp(1, 50);
    state = state.copyWith(delegationSize: clamped, clearError: true);
  }

  void setPurpose(String v) =>
      state = state.copyWith(purpose: v, clearError: true);

  // ── Submission ─────────────────────────────────────────────────────────────

  Future<void> submit() async {
    if (!state.isReadyToSubmit) return;

    // Client-side validation mirrors server rules
    final nameErr = _validateName(state.fullName);
    if (nameErr != null) {
      state = state.copyWith(errorMessage: nameErr);
      return;
    }

    final mobileErr = _validateMobile(state.mobileNumber);
    if (mobileErr != null) {
      state = state.copyWith(errorMessage: mobileErr);
      return;
    }

    final emailErr = _validateEmail(state.email);
    if (emailErr != null) {
      state = state.copyWith(errorMessage: emailErr);
      return;
    }

    final purposeErr = _validatePurpose(state.purpose);
    if (purposeErr != null) {
      state = state.copyWith(errorMessage: purposeErr);
      return;
    }

    state = state.copyWith(isSubmitting: true, clearError: true);

    try {
      final repo = ref.read(campusVisitRepositoryProvider);
      final key = _buildIdempotencyKey();

      final visitId = await repo.submitVisit(
        applicantName: state.fullName.trim(),
        applicantMobile: _normalizePhone(state.mobileNumber),
        applicantEmail: state.email.trim().toLowerCase(),
        visitDate: state.visitDate!,
        session: state.session!,
        delegationSize: state.delegationSize,
        purpose: state.purpose.trim(),
        idempotencyKey: key,
      );

      state = state.copyWith(
        isSubmitting: false,
        successVisitId: visitId,
        clearError: true,
      );
    } on Failure catch (f) {
      state = state.copyWith(isSubmitting: false, errorMessage: f.message);
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'Something went wrong. Please try again.',
      );
    }
  }

  void reset() => state = const CampusVisitFormState();

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// SHA-256(uid + visitDate ISO + session) — matches the server-side check.
  String _buildIdempotencyKey() {
    // We don't have uid here; the server will further scope it by applicantId.
    // The key is used to make the payload unique per booking intent.
    final raw =
        '${state.visitDate!.toIso8601String().substring(0, 10)}_${state.session}';
    final bytes = utf8.encode(raw);
    return sha256.convert(bytes).toString();
  }

  String _normalizePhone(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('91') && digits.length == 12) return '+$digits';
    if (digits.length == 10) return '+91$digits';
    return '+$digits';
  }

  String? _validateName(String v) {
    final trimmed = v.trim();
    if (trimmed.length < 2) return 'Full name must be at least 2 characters.';
    if (trimmed.length > 100) {
      return 'Full name must be 100 characters or fewer.';
    }
    return null;
  }

  String? _validateMobile(String v) {
    final normalized = _normalizePhone(v);
    if (!RegExp(r'^\+\d{7,15}$').hasMatch(normalized)) {
      return 'Enter a valid 10-digit mobile number.';
    }
    return null;
  }

  String? _validateEmail(String v) {
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v.trim())) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  String? _validatePurpose(String v) {
    final trimmed = v.trim();
    if (trimmed.length < 20) return 'Purpose must be at least 20 characters.';
    if (trimmed.length > 1000) {
      return 'Purpose must be 1000 characters or fewer.';
    }
    return null;
  }
}

final campusVisitViewModelProvider =
    NotifierProvider.autoDispose<CampusVisitViewModel, CampusVisitFormState>(
      CampusVisitViewModel.new,
    );

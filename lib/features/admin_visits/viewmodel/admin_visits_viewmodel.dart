import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/failures.dart';
import '../../../core/providers/core_providers.dart';

/// State for the Admin Visit Review mutation.
class AdminVisitMutationState {
  final bool isLoading;
  final String? errorMessage;
  final bool isSuccess;

  const AdminVisitMutationState({
    this.isLoading = false,
    this.errorMessage,
    this.isSuccess = false,
  });

  AdminVisitMutationState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool? isSuccess,
  }) {
    return AdminVisitMutationState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      isSuccess: isSuccess ?? this.isSuccess,
    );
  }
}

/// Controller managing Admin review actions (Approve / Reject) for campus visits.
class AdminVisitsController extends Notifier<AdminVisitMutationState> {
  @override
  AdminVisitMutationState build() {
    return const AdminVisitMutationState();
  }

  /// Approves a pending campus visit.
  Future<bool> approveVisit({required String visitId, String? note}) async {
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      isSuccess: false,
    );
    try {
      final repo = ref.read(campusVisitRepositoryProvider);
      await repo.reviewVisit(
        visitId: visitId,
        action: 'approve',
        reviewNote: note,
      );
      state = state.copyWith(isLoading: false, isSuccess: true);
      return true;
    } catch (e) {
      final msg = e is Failure ? e.message : e.toString();
      state = state.copyWith(isLoading: false, errorMessage: msg);
      return false;
    }
  }

  /// Rejects a pending campus visit with an explanatory note.
  Future<bool> rejectVisit({
    required String visitId,
    required String note,
  }) async {
    if (note.trim().isEmpty) {
      state = state.copyWith(
        errorMessage: 'A reason is required when rejecting a visit.',
      );
      return false;
    }

    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      isSuccess: false,
    );
    try {
      final repo = ref.read(campusVisitRepositoryProvider);
      await repo.reviewVisit(
        visitId: visitId,
        action: 'reject',
        reviewNote: note.trim(),
      );
      state = state.copyWith(isLoading: false, isSuccess: true);
      return true;
    } catch (e) {
      final msg = e is Failure ? e.message : e.toString();
      state = state.copyWith(isLoading: false, errorMessage: msg);
      return false;
    }
  }
}

final adminVisitsControllerProvider =
    NotifierProvider<AdminVisitsController, AdminVisitMutationState>(
      AdminVisitsController.new,
    );

/// Notifier for filtering admin campus visits by status in the UI.
class AdminVisitsFilterNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setFilter(String? filter) {
    state = filter;
  }
}

final adminVisitsFilterProvider =
    NotifierProvider<AdminVisitsFilterNotifier, String?>(
  AdminVisitsFilterNotifier.new,
);

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/app_user.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/services/admin_functions_service.dart';

/// Fetches a single committee member by uid for the Profile screen.
/// AutoDispose keeps this alive only while the screen is mounted.
final committeeMemberProfileProvider = FutureProvider.autoDispose
    .family<AppUser?, String>((ref, uid) async {
      final repo = ref.watch(userRepositoryProvider);
      return repo.getUserById(uid);
    });

// ---------------------------------------------------------------------------
// Manage controller state
// ---------------------------------------------------------------------------
class ManageMemberState {
  final bool isSubmitting;
  final String? errorMessage;

  const ManageMemberState({this.isSubmitting = false, this.errorMessage});

  ManageMemberState copyWith({bool? isSubmitting, String? errorMessage}) {
    return ManageMemberState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: errorMessage,
    );
  }
}

// ---------------------------------------------------------------------------
// Manage controller — calls updateCommitteeMember Cloud Function
// ---------------------------------------------------------------------------
final manageMemberControllerProvider =
    NotifierProvider<ManageMemberController, ManageMemberState>(() {
      return ManageMemberController();
    });

class ManageMemberController extends Notifier<ManageMemberState> {
  @override
  ManageMemberState build() => const ManageMemberState();

  /// Updates the committee member's profile via Cloud Function.
  /// Returns true on success.
  Future<bool> updateMember({
    required String uid,
    required String fullName,
    required String phone,
    required String expertiseTag,
    required bool active,
  }) async {
    state = state.copyWith(isSubmitting: true, errorMessage: null);
    try {
      final service = ref.read(adminFunctionsServiceProvider);
      await service.callAdminFunction<Map<String, dynamic>>(
        functionName: 'updateCommitteeMember',
        data: {
          'uid': uid,
          'fullName': fullName,
          'phone': phone,
          'expertiseTag': expertiseTag,
          'active': active,
        },
      );

      // Invalidate the member's profile and the directory list
      ref.invalidate(committeeMemberProfileProvider(uid));
      ref.invalidate(committeeMembersProvider);

      state = state.copyWith(isSubmitting: false);
      return true;
    } catch (e) {
      state = state.copyWith(isSubmitting: false, errorMessage: e.toString());
      return false;
    }
  }
}

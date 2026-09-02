import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:survey_desk/core/services/admin_functions_service.dart';
import '../../../core/errors/failures.dart';
import '../../../core/models/app_user.dart';
import '../../../core/providers/core_providers.dart';

class CommitteeManagementState {
  final AsyncValue<List<AppUser>> members;
  final String searchQuery;

  const CommitteeManagementState({
    required this.members,
    this.searchQuery = '',
  });

  CommitteeManagementState copyWith({
    AsyncValue<List<AppUser>>? members,
    String? searchQuery,
  }) {
    return CommitteeManagementState(
      members: members ?? this.members,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  List<AppUser> get filteredMembers {
    final list = members.value ?? [];
    if (searchQuery.isEmpty) return list;

    final query = searchQuery.toLowerCase();
    return list.where((member) {
      final nameMatches = member.fullName.toLowerCase().contains(query);
      final emailMatches = member.email.toLowerCase().contains(query);
      final phoneMatches = member.phone.toLowerCase().contains(query);
      final tagMatches = (member.expertiseTag ?? '').toLowerCase().contains(
        query,
      );
      return nameMatches || emailMatches || phoneMatches || tagMatches;
    }).toList();
  }
}

final committeeManagementViewModelProvider =
    NotifierProvider<CommitteeManagementViewModel, CommitteeManagementState>(
      () {
        return CommitteeManagementViewModel();
      },
    );

class CommitteeManagementViewModel extends Notifier<CommitteeManagementState> {
  @override
  CommitteeManagementState build() {
    ref.listen<AsyncValue<List<AppUser>>>(committeeMembersProvider, (
      previous,
      next,
    ) {
      state = state.copyWith(members: next);
    });

    final initialMembers = ref.read(committeeMembersProvider);
    return CommitteeManagementState(members: initialMembers);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  /// Creates a new committee member account via Cloud Functions.
  /// Returns the provisioned credentials map from the backend:
  ///   { success, uid, email, tempPassword, resetLink, message }
  /// This requires Admin privileges.
  Future<Map<String, dynamic>> createCommitteeMember({
    required String name,
    required String email,
    required String phone,
    required String expertiseTag,
  }) async {
    if (name.isEmpty ||
        email.isEmpty ||
        phone.isEmpty ||
        expertiseTag.isEmpty) {
      throw const ValidationFailure('All fields are required.');
    }

    final adminService = ref.read(adminFunctionsServiceProvider);

    final result = await adminService.callAdminFunction<Map<String, dynamic>>(
      functionName: 'createCommitteeAccount',
      data: {
        'name': name,
        'email': email,
        'phone': phone,
        'expertiseTag': expertiseTag,
      },
    );

    // result is typed as Map<String, dynamic> from the Cloud Function response.
    return Map<String, dynamic>.from(result as Map);
  }
}

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/failures.dart';
import '../../../core/models/app_user.dart';
import '../../../core/providers/core_providers.dart';
import '../../auth/viewmodel/auth_viewmodel.dart';

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
      final tagMatches = (member.expertiseTag ?? '').toLowerCase().contains(
        query,
      );
      return nameMatches || emailMatches || tagMatches;
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
  /// This requires Admin privileges.
  Future<void> createCommitteeMember({
    required String name,
    required String email,
    required String expertiseTag,
  }) async {
    final authState = ref.read(authViewModelProvider);
    if (authState.value?.isAdmin != true) {
      throw const AuthFailure('Only administrators can add committee members.');
    }

    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'createCommitteeAccount',
      );
      await callable.call({
        'name': name,
        'email': email,
        'expertiseTag': expertiseTag,
      });
      // Stream will automatically update the list.
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'already-exists') {
        throw const ValidationFailure(
          'An account with this email already exists.',
        );
      }
      throw ServerFailure(
        e.message ?? 'Failed to create committee member account.',
      );
    } catch (e) {
      throw ServerFailure('An unexpected error occurred: $e');
    }
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/campus_visit.dart';
import '../../../core/providers/core_providers.dart';

/// Streams all campus visits for the currently authenticated applicant.
final myVisitsProvider = StreamProvider.family<List<CampusVisit>, String>(
  (ref, applicantId) {
    final repo = ref.watch(campusVisitRepositoryProvider);
    return repo.watchVisitsForApplicant(applicantId);
  },
);

/// Admin: streams all campus visits, optionally filtered by status.
final adminVisitsProvider = StreamProvider.family<List<CampusVisit>, String?>(
  (ref, statusFilter) {
    final repo = ref.watch(campusVisitRepositoryProvider);
    return repo.watchAllVisits(statusFilter: statusFilter);
  },
);

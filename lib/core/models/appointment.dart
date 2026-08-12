import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/survey_type.dart';
import '../constants/appointment_status.dart';
import 'xen_details.dart';
import 'logistics.dart';
import 'kml_file.dart';
import 'permission_document.dart';

class Appointment {
  final String id;
  final String applicantId;
  final String applicantName;
  final String? applicantOrgName;
  final String applicantEmail;

  final SurveyType surveyType;
  final String? customSurveyName;
  final String state;
  final String district;
  final XenDetails xenDetails;
  final String areaName;
  final KmlFile kmlFile;

  final DateTime preferredDate;
  final DateTime? confirmedDate;
  final Logistics logistics;
  final List<PermissionDocument> permissionDocuments;

  final AppointmentStatus status;
  final String? assignedReviewerId;
  final String? assignedReviewerName;
  final String? assignedTaskMemberId;
  final String? assignedTaskMemberName;

  final String? rejectionReason;
  final String? clarificationNote;
  final String? clarificationReply;

  final DateTime createdAt;
  final DateTime updatedAt;

  const Appointment({
    required this.id,
    required this.applicantId,
    required this.applicantName,
    this.applicantOrgName,
    required this.applicantEmail,
    required this.surveyType,
    this.customSurveyName,
    required this.state,
    required this.district,
    required this.xenDetails,
    required this.areaName,
    required this.kmlFile,
    required this.preferredDate,
    this.confirmedDate,
    required this.logistics,
    required this.permissionDocuments,
    required this.status,
    this.assignedReviewerId,
    this.assignedReviewerName,
    this.assignedTaskMemberId,
    this.assignedTaskMemberName,
    this.rejectionReason,
    this.clarificationNote,
    this.clarificationReply,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Appointment.fromMap(String id, Map<String, dynamic> map) {
    final docsList = (map['permissionDocuments'] as List<dynamic>?) ?? [];
    return Appointment(
      id: id,
      applicantId: map['applicantId'] as String? ?? '',
      applicantName: map['applicantName'] as String? ?? '',
      applicantOrgName: map['applicantOrgName'] as String?,
      applicantEmail: map['applicantEmail'] as String? ?? '',
      surveyType: SurveyType.fromCode(map['surveyType'] as String? ?? ''),
      customSurveyName: map['customSurveyName'] as String?,
      state: map['state'] as String? ?? '',
      district: map['district'] as String? ?? '',
      xenDetails: XenDetails.fromMap(
        (map['xenDetails'] as Map<String, dynamic>?) ?? {},
      ),
      areaName: map['areaName'] as String? ?? '',
      kmlFile: KmlFile.fromMap((map['kmlFile'] as Map<String, dynamic>?) ?? {}),
      preferredDate:
          (map['preferredDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      confirmedDate: (map['confirmedDate'] as Timestamp?)?.toDate(),
      logistics: Logistics.fromMap(
        (map['logistics'] as Map<String, dynamic>?) ?? {},
      ),
      permissionDocuments: docsList
          .map(
            (doc) => PermissionDocument.fromMap((doc as Map<String, dynamic>)),
          )
          .toList(),
      status: AppointmentStatus.fromCode(map['status'] as String? ?? ''),
      assignedReviewerId: map['assignedReviewerId'] as String?,
      assignedReviewerName: map['assignedReviewerName'] as String?,
      assignedTaskMemberId: map['assignedTaskMemberId'] as String?,
      assignedTaskMemberName: map['assignedTaskMemberName'] as String?,
      rejectionReason: map['rejectionReason'] as String?,
      clarificationNote: map['clarificationNote'] as String?,
      clarificationReply: map['clarificationReply'] as String?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'applicantId': applicantId,
      'applicantName': applicantName,
      'applicantOrgName': applicantOrgName,
      'applicantEmail': applicantEmail,
      'surveyType': surveyType.code,
      'customSurveyName': customSurveyName,
      'state': state,
      'district': district,
      'xenDetails': xenDetails.toMap(),
      'areaName': areaName,
      'kmlFile': kmlFile.toMap(),
      'preferredDate': Timestamp.fromDate(preferredDate),
      'confirmedDate': confirmedDate != null
          ? Timestamp.fromDate(confirmedDate!)
          : null,
      'logistics': logistics.toMap(),
      'permissionDocuments': permissionDocuments.map((d) => d.toMap()).toList(),
      'status': status.code,
      'assignedReviewerId': assignedReviewerId,
      'assignedReviewerName': assignedReviewerName,
      'assignedTaskMemberId': assignedTaskMemberId,
      'assignedTaskMemberName': assignedTaskMemberName,
      'rejectionReason': rejectionReason,
      'clarificationNote': clarificationNote,
      'clarificationReply': clarificationReply,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}

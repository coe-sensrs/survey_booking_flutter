import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/hive_storage_service.dart';
import '../../../core/constants/appointment_status.dart';
import '../../../core/constants/survey_type.dart';
import '../../../core/models/appointment.dart';
import '../../../core/models/kml_file.dart';
import '../../../core/models/logistics.dart';
import '../../../core/models/permission_document.dart';
import '../../../core/models/xen_details.dart';
import '../../../core/providers/core_providers.dart';
import '../../auth/viewmodel/auth_viewmodel.dart';

class WizardStateData {
  final int currentStep;
  final String? surveyType;
  final String? customSurveyName;
  final String stateName;
  final String? district;
  final String? xenName;
  final String? xenMobile;
  final String? xenEmail;
  final String? areaName;
  final String? kmlFilePath;
  final String? kmlFileName;
  final String? kmlFileType;
  final int? kmlFileSize;
  final DateTime? startDate;
  final String? coordinatorName;
  final String? coordinatorDesignation;
  final String? driverName;
  final String? driverMobile;
  final String? vehicleNumber;
  final String? vehicleModel;
  final List<Map<String, dynamic>> permissionDocs;

  const WizardStateData({
    this.currentStep = 1,
    this.surveyType,
    this.customSurveyName,
    this.stateName = 'Punjab',
    this.district,
    this.xenName,
    this.xenMobile,
    this.xenEmail,
    this.areaName,
    this.kmlFilePath,
    this.kmlFileName,
    this.kmlFileType,
    this.kmlFileSize,
    this.startDate,
    this.coordinatorName,
    this.coordinatorDesignation,
    this.driverName,
    this.driverMobile,
    this.vehicleNumber,
    this.vehicleModel,
    this.permissionDocs = const [],
  });

  WizardStateData copyWith({
    int? currentStep,
    String? surveyType,
    String? customSurveyName,
    String? stateName,
    String? district,
    String? xenName,
    String? xenMobile,
    String? xenEmail,
    String? areaName,
    String? kmlFilePath,
    String? kmlFileName,
    String? kmlFileType,
    int? kmlFileSize,
    DateTime? startDate,
    String? coordinatorName,
    String? coordinatorDesignation,
    String? driverName,
    String? driverMobile,
    String? vehicleNumber,
    String? vehicleModel,
    List<Map<String, dynamic>>? permissionDocs,
  }) {
    return WizardStateData(
      currentStep: currentStep ?? this.currentStep,
      surveyType: surveyType ?? this.surveyType,
      customSurveyName: customSurveyName ?? this.customSurveyName,
      stateName: stateName ?? this.stateName,
      district: district ?? this.district,
      xenName: xenName ?? this.xenName,
      xenMobile: xenMobile ?? this.xenMobile,
      xenEmail: xenEmail ?? this.xenEmail,
      areaName: areaName ?? this.areaName,
      kmlFilePath: kmlFilePath ?? this.kmlFilePath,
      kmlFileName: kmlFileName ?? this.kmlFileName,
      kmlFileType: kmlFileType ?? this.kmlFileType,
      kmlFileSize: kmlFileSize ?? this.kmlFileSize,
      startDate: startDate ?? this.startDate,
      coordinatorName: coordinatorName ?? this.coordinatorName,
      coordinatorDesignation:
          coordinatorDesignation ?? this.coordinatorDesignation,
      driverName: driverName ?? this.driverName,
      driverMobile: driverMobile ?? this.driverMobile,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      vehicleModel: vehicleModel ?? this.vehicleModel,
      permissionDocs: permissionDocs ?? this.permissionDocs,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'currentStep': currentStep,
      'surveyType': surveyType,
      'customSurveyName': customSurveyName,
      'stateName': stateName,
      'district': district,
      'xenName': xenName,
      'xenMobile': xenMobile,
      'xenEmail': xenEmail,
      'areaName': areaName,
      'kmlFilePath': kmlFilePath,
      'kmlFileName': kmlFileName,
      'kmlFileType': kmlFileType,
      'kmlFileSize': kmlFileSize,
      'startDate': startDate?.toIso8601String(),
      'coordinatorName': coordinatorName,
      'coordinatorDesignation': coordinatorDesignation,
      'driverName': driverName,
      'driverMobile': driverMobile,
      'vehicleNumber': vehicleNumber,
      'vehicleModel': vehicleModel,
      'permissionDocs': permissionDocs,
    };
  }

  factory WizardStateData.fromMap(Map<String, dynamic> map) {
    return WizardStateData(
      currentStep: map['currentStep'] ?? 1,
      surveyType: map['surveyType'],
      customSurveyName: map['customSurveyName'],
      stateName: map['stateName'] ?? 'Punjab',
      district: map['district'],
      xenName: map['xenName'],
      xenMobile: map['xenMobile'],
      xenEmail: map['xenEmail'],
      areaName: map['areaName'],
      kmlFilePath: map['kmlFilePath'],
      kmlFileName: map['kmlFileName'],
      kmlFileType: map['kmlFileType'],
      kmlFileSize: map['kmlFileSize'],
      startDate: map['startDate'] != null
          ? DateTime.tryParse(map['startDate'])
          : null,
      coordinatorName: map['coordinatorName'],
      coordinatorDesignation: map['coordinatorDesignation'],
      driverName: map['driverName'],
      driverMobile: map['driverMobile'],
      vehicleNumber: map['vehicleNumber'],
      vehicleModel: map['vehicleModel'],
      permissionDocs:
          (map['permissionDocs'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [],
    );
  }
}

final bookingWizardViewModelProvider =
    NotifierProvider<BookingWizardViewModel, WizardStateData>(() {
      return BookingWizardViewModel();
    });

class BookingWizardViewModel extends Notifier<WizardStateData> {
  @override
  WizardStateData build() {
    ref.listen(authViewModelProvider, (previous, next) {
      if (next.value == null) {
        state = const WizardStateData();
      }
    });

    try {
      final raw = HiveStorageService.getWizardDraft();
      if (raw != null && raw.isNotEmpty) {
        final Map<String, dynamic> map = jsonDecode(raw);
        return WizardStateData.fromMap(map);
      }
    } catch (_) {}
    return const WizardStateData();
  }

  bool get hasDraft {
    return state.surveyType != null ||
        (state.areaName != null && state.areaName!.trim().isNotEmpty) ||
        state.currentStep > 1 ||
        state.kmlFilePath != null ||
        (state.xenName != null && state.xenName!.trim().isNotEmpty) ||
        (state.coordinatorName != null &&
            state.coordinatorName!.trim().isNotEmpty) ||
        state.permissionDocs.isNotEmpty;
  }

  Future<void> _saveDraft() async {
    try {
      await HiveStorageService.saveWizardDraft(jsonEncode(state.toMap()));
    } catch (_) {}
  }

  Future<void> clearDraft() async {
    state = const WizardStateData();
    try {
      await HiveStorageService.clearWizardDraft();
    } catch (_) {}
  }

  Future<void> startFreshSurvey() async {
    await clearDraft();
    state = const WizardStateData(currentStep: 1);
  }

  void updateState(WizardStateData newState) {
    state = newState;
    _saveDraft();
  }

  void setStep(int step) {
    state = state.copyWith(currentStep: step);
    _saveDraft();
  }

  void nextStep() {
    if (state.currentStep < 9) {
      setStep(state.currentStep + 1);
    }
  }

  void previousStep() {
    if (state.currentStep > 1) {
      setStep(state.currentStep - 1);
    }
  }

  /// Final Submission (Step 8 -> 9)
  Future<String> submitBooking({
    void Function(String stage, double progress)? onProgress,
  }) async {
    final user = ref.read(authViewModelProvider).value;
    if (user == null) throw Exception('Applicant not logged in');

    final uploadService = ref.read(storageUploadServiceProvider);
    final appointmentRepo = ref.read(appointmentRepositoryProvider);

    final totalDocs = state.permissionDocs.length;
    final totalSteps = 1 + totalDocs + 1; // KML + Docs + Firestore

    // 1. Upload KML/KMZ File
    if (state.kmlFilePath == null || state.kmlFileName == null) {
      throw Exception('KML/KMZ file is required');
    }

    final kmlFileObj = File(state.kmlFilePath!);
    if (!kmlFileObj.existsSync()) {
      throw Exception(
        'The selected KML/KMZ file (${state.kmlFileName}) is no longer accessible on this device. Please go back to Step 4 and re-select the file.',
      );
    }
    final kmlBytes = await kmlFileObj.readAsBytes();
    final tempId = DateTime.now().millisecondsSinceEpoch.toString();

    onProgress?.call(
      'Uploading Survey Map (${state.kmlFileName})...',
      0.05,
    );

    final kmlStoragePath = await uploadService.uploadKmlFile(
      appointmentId: tempId,
      filePath: state.kmlFilePath!,
      fileName: state.kmlFileName!,
      onProgress: (fileProgress) {
        final scaled = (fileProgress / totalSteps);
        onProgress?.call(
          'Uploading Survey Map (${state.kmlFileName})...',
          scaled.clamp(0.0, 1.0),
        );
      },
    );

    final kmlModel = KmlFile(
      storagePath: kmlStoragePath,
      originalFileName: state.kmlFileName!,
      fileType: state.kmlFileType ?? 'kml',
      sizeBytes: state.kmlFileSize ?? kmlBytes.length,
      uploadedAt: DateTime.now(),
    );

    // 2. Upload Permission Documents (if any)
    final List<PermissionDocument> uploadedDocs = [];
    for (int i = 0; i < totalDocs; i++) {
      final docMap = state.permissionDocs[i];
      final path = docMap['path'] as String;
      final fileName = docMap['fileName'] as String;
      final fileType = docMap['fileType'] as String;
      final file = File(path);
      if (!file.existsSync()) {
        throw Exception(
          'Permission document "$fileName" is no longer accessible on this device. Please go back to Step 7 and re-attach the document.',
        );
      }
      final bytes = await file.readAsBytes();

      final stepBase = (1.0 + i) / totalSteps;
      final stepWeight = 1.0 / totalSteps;
      onProgress?.call(
        'Uploading document ${i + 1} of $totalDocs ($fileName)...',
        stepBase,
      );

      final storagePath = await uploadService.uploadPermissionDocument(
        appointmentId: tempId,
        filePath: path,
        fileName: fileName,
        onProgress: (fileProgress) {
          final scaled = stepBase + (fileProgress * stepWeight);
          onProgress?.call(
            'Uploading document ${i + 1} of $totalDocs ($fileName)...',
            scaled.clamp(0.0, 1.0),
          );
        },
      );

      uploadedDocs.add(
        PermissionDocument(
          storagePath: storagePath,
          originalFileName: fileName,
          fileType: fileType,
          sizeBytes: bytes.length,
          uploadedAt: DateTime.now(),
        ),
      );
    }

    // 3. Construct Appointment Domain Model
    onProgress?.call(
      'Finalizing and creating booking...',
      (totalSteps - 0.5) / totalSteps,
    );

    final selectedSurveyType = SurveyType.fromCode(
      state.surveyType ?? SurveyType.socioEconomicSurvey.code,
    );

    final appointment = Appointment(
      id: '',
      applicantId: user.uid,
      applicantName: user.fullName,
      applicantOrgName: user.orgName,
      applicantEmail: user.email,
      surveyType: selectedSurveyType,
      customSurveyName: state.customSurveyName,
      state: state.stateName,
      district: state.district ?? 'Amritsar',
      xenDetails: XenDetails(
        name: state.xenName ?? '',
        mobile: state.xenMobile ?? '',
        email: state.xenEmail ?? '',
      ),
      areaName: state.areaName ?? '',
      kmlFile: kmlModel,
      preferredDate:
          state.startDate ?? DateTime.now().add(const Duration(days: 1)),
      logistics: Logistics(
        coordinatorName: state.coordinatorName ?? '',
        coordinatorDesignation: state.coordinatorDesignation ?? '',
        driverName: state.driverName ?? '',
        driverMobile: state.driverMobile ?? '',
        vehicleNumber: state.vehicleNumber ?? '',
        vehicleModel: state.vehicleModel ?? '',
      ),
      permissionDocuments: uploadedDocs,
      status: AppointmentStatus.pendingAssignment,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // 4. Save to Firestore via Repository
    final appointmentId = await appointmentRepo.submitAppointment(appointment);

    onProgress?.call('Booking submitted successfully!', 1.0);

    // 5. Clear draft after successful creation
    await clearDraft();

    return appointmentId;
  }
}

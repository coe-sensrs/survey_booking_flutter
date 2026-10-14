import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:survey_desk/core/constants/appointment_status.dart';
import 'package:survey_desk/core/constants/survey_type.dart';
import 'package:survey_desk/core/models/appointment.dart';
import 'package:survey_desk/core/models/logistics.dart';
import 'package:survey_desk/core/models/xen_details.dart';
import 'package:survey_desk/features/booking_wizard/viewmodel/booking_wizard_viewmodel.dart';

void main() {
  group('SurveyType Enum Tests', () {
    test('SurveyType values are in the exact required order', () {
      expect(SurveyType.values.length, 5);
      expect(SurveyType.values[0], SurveyType.droneSurvey);
      expect(SurveyType.values[1], SurveyType.dgpsSurvey);
      expect(SurveyType.values[2], SurveyType.bathymetrySurvey);
      expect(SurveyType.values[3], SurveyType.socioEconomicSurvey);
      expect(SurveyType.values[4], SurveyType.other);
    });

    test('SurveyType labels and codes match specification', () {
      expect(SurveyType.droneSurvey.code, 'drone_survey');
      expect(SurveyType.droneSurvey.label, 'Drone Survey');

      expect(SurveyType.dgpsSurvey.code, 'dgps_survey');
      expect(SurveyType.dgpsSurvey.label, 'DGPS Survey');

      expect(SurveyType.bathymetrySurvey.code, 'bathymetry_survey');
      expect(SurveyType.bathymetrySurvey.label, 'Bathymetry Survey');

      expect(SurveyType.socioEconomicSurvey.code, 'socio_economic_survey');
      expect(SurveyType.socioEconomicSurvey.label, 'Socio-Economic Survey');

      expect(SurveyType.other.code, 'other');
      expect(SurveyType.other.label, 'Other');
    });

    test('SurveyType.fromCode resolves exact codes', () {
      expect(SurveyType.fromCode('drone_survey'), SurveyType.droneSurvey);
      expect(SurveyType.fromCode('dgps_survey'), SurveyType.dgpsSurvey);
      expect(
        SurveyType.fromCode('bathymetry_survey'),
        SurveyType.bathymetrySurvey,
      );
      expect(
        SurveyType.fromCode('socio_economic_survey'),
        SurveyType.socioEconomicSurvey,
      );
      expect(SurveyType.fromCode('other'), SurveyType.other);
    });

    test(
      'SurveyType.fromCode provides backward compatibility for legacy codes',
      () {
        expect(
          SurveyType.fromCode('bathymetry_survey_red_line'),
          SurveyType.bathymetrySurvey,
        );
        expect(
          SurveyType.fromCode('benchmarking_dgps_survey'),
          SurveyType.dgpsSurvey,
        );
        expect(
          SurveyType.fromCode('socio_economic'),
          SurveyType.socioEconomicSurvey,
        );
        expect(SurveyType.fromCode('unrecognized_code'), SurveyType.other);
      },
    );
  });

  group('Appointment Model Nullable KmlFile Tests', () {
    test('Appointment supports null kmlFile for Socio-Economic surveys', () {
      final now = DateTime.now();
      final appointment = Appointment(
        id: 'apt_123',
        applicantId: 'app_1',
        applicantName: 'John Doe',
        applicantEmail: 'john@example.com',
        surveyType: SurveyType.socioEconomicSurvey,
        state: 'Punjab',
        district: 'Amritsar',
        xenDetails: const XenDetails(
          name: 'XEN Officer',
          mobile: '9876543210',
          email: 'xen@example.com',
        ),
        areaName: 'Amritsar Rural Zone',
        kmlFile: null,
        preferredStart: now,
        preferredEnd: now.add(const Duration(days: 2)),
        logistics: const Logistics(
          coordinatorName: 'Coord',
          coordinatorDesignation: 'Officer',
          driverName: 'Driver',
          driverMobile: '9876543211',
          vehicleNumber: 'PB02AB1234',
          vehicleModel: 'Bolero',
        ),
        permissionDocuments: const [],
        status: AppointmentStatus.pendingAssignment,
        createdAt: now,
        updatedAt: now,
      );

      expect(appointment.kmlFile, isNull);

      // Verify toMap
      final map = appointment.toMap();
      expect(map['kmlFile'], isNull);
      expect(map['surveyType'], 'socio_economic_survey');

      // Verify toJson
      final json = appointment.toJson();
      expect(json['kmlFile'], isNull);
      expect(json['surveyType'], 'socio_economic_survey');

      // Verify fromMap without kmlFile
      final fromMapApt = Appointment.fromMap('apt_123', {
        'applicantId': 'app_1',
        'applicantName': 'John Doe',
        'applicantEmail': 'john@example.com',
        'surveyType': 'socio_economic_survey',
        'state': 'Punjab',
        'district': 'Amritsar',
        'xenDetails': {
          'name': 'XEN Officer',
          'mobile': '9876543210',
          'email': 'xen@example.com',
        },
        'areaName': 'Amritsar Rural Zone',
        'kmlFile': null,
        'preferredStart': Timestamp.fromDate(now),
        'preferredEnd': Timestamp.fromDate(now.add(const Duration(days: 2))),
        'logistics': {
          'coordinatorName': 'Coord',
          'coordinatorDesignation': 'Officer',
          'driverName': 'Driver',
          'driverMobile': '9876543211',
          'vehicleNumber': 'PB02AB1234',
          'vehicleModel': 'Bolero',
        },
        'permissionDocuments': [],
        'status': 'pending_assignment',
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      });

      expect(fromMapApt.kmlFile, isNull);
      expect(fromMapApt.surveyType, SurveyType.socioEconomicSurvey);
    });

    test('Appointment deserializes kmlFile when present', () {
      final now = DateTime.now();
      final appointmentWithKml = Appointment.fromMap('apt_456', {
        'applicantId': 'app_1',
        'applicantName': 'John Doe',
        'applicantEmail': 'john@example.com',
        'surveyType': 'drone_survey',
        'state': 'Punjab',
        'district': 'Jalandhar',
        'xenDetails': {
          'name': 'XEN Officer',
          'mobile': '9876543210',
          'email': 'xen@example.com',
        },
        'areaName': 'Site Sector 4',
        'kmlFile': {
          'storagePath': 'appointments/apt_456/kml/boundary.kml',
          'originalFileName': 'boundary.kml',
          'fileType': 'kml',
          'sizeBytes': 2048,
          'uploadedAt': Timestamp.fromDate(now),
        },
        'preferredStart': Timestamp.fromDate(now),
        'preferredEnd': Timestamp.fromDate(now.add(const Duration(days: 1))),
        'logistics': {
          'coordinatorName': 'Coord',
          'coordinatorDesignation': 'Officer',
          'driverName': 'Driver',
          'driverMobile': '9876543211',
          'vehicleNumber': 'PB02AB1234',
          'vehicleModel': 'Bolero',
        },
        'permissionDocuments': [],
        'status': 'pending_assignment',
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      });

      expect(appointmentWithKml.kmlFile, isNotNull);
      expect(appointmentWithKml.kmlFile!.originalFileName, 'boundary.kml');
      expect(
        appointmentWithKml.kmlFile!.storagePath,
        'appointments/apt_456/kml/boundary.kml',
      );
      expect(appointmentWithKml.surveyType, SurveyType.droneSurvey);
    });
  });

  group('Wizard Step 4 KML Requirement Condition Tests', () {
    test('KML is not required for Socio-Economic Survey', () {
      final state = const WizardStateData(
        surveyType: 'socio_economic_survey',
        areaName: 'Zone Alpha',
        kmlFilePath: null,
        kmlFileName: null,
      );

      final isKmlRequired =
          state.surveyType != SurveyType.socioEconomicSurvey.code;
      expect(isKmlRequired, isFalse);

      // Simulation of Step 4 validation logic
      final isValid =
          (state.areaName != null && state.areaName!.trim().isNotEmpty) &&
          (!isKmlRequired ||
              (state.kmlFilePath != null && state.kmlFileName != null));

      expect(isValid, isTrue);
    });

    test('KML is strictly required for Drone and other surveys', () {
      final stateWithoutKml = const WizardStateData(
        surveyType: 'drone_survey',
        areaName: 'Zone Beta',
        kmlFilePath: null,
        kmlFileName: null,
      );

      final isKmlRequired =
          stateWithoutKml.surveyType != SurveyType.socioEconomicSurvey.code;
      expect(isKmlRequired, isTrue);

      final isValidWithoutKml =
          (stateWithoutKml.areaName != null &&
              stateWithoutKml.areaName!.trim().isNotEmpty) &&
          (!isKmlRequired ||
              (stateWithoutKml.kmlFilePath != null &&
                  stateWithoutKml.kmlFileName != null));

      expect(isValidWithoutKml, isFalse);

      final stateWithKml = stateWithoutKml.copyWith(
        kmlFilePath: '/path/to/test.kml',
        kmlFileName: 'test.kml',
      );

      final isValidWithKml =
          (stateWithKml.areaName != null &&
              stateWithKml.areaName!.trim().isNotEmpty) &&
          (!isKmlRequired ||
              (stateWithKml.kmlFilePath != null &&
                  stateWithKml.kmlFileName != null));

      expect(isValidWithKml, isTrue);
    });
  });
}

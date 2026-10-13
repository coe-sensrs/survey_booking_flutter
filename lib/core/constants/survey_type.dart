enum SurveyType {
  droneSurvey('drone_survey', 'Drone Survey'),
  dgpsSurvey('dgps_survey', 'DGPS Survey'),
  bathymetrySurvey('bathymetry_survey', 'Bathymetry Survey'),
  socioEconomicSurvey('socio_economic_survey', 'Socio-Economic Survey'),
  other('other', 'Other');

  final String code;
  final String label;

  const SurveyType(this.code, this.label);

  static SurveyType fromCode(String code) {
    // Backward compatibility for legacy database entries
    if (code == 'bathymetry_survey_red_line') {
      return SurveyType.bathymetrySurvey;
    }
    if (code == 'benchmarking_dgps_survey') {
      return SurveyType.dgpsSurvey;
    }
    if (code == 'socio_economic') {
      return SurveyType.socioEconomicSurvey;
    }

    return SurveyType.values.firstWhere(
      (e) => e.code == code,
      orElse: () => SurveyType.other,
    );
  }
}

enum SurveyType {
  socioEconomicSurvey('socio_economic_survey', 'Socio Economic Survey'),
  benchmarkingDgpsSurvey(
    'benchmarking_dgps_survey',
    'Benchmarking (DGPS Survey)',
  ),
  dgpsSurvey('dgps_survey', 'DGPS Survey'),
  bathymetrySurveyRedLine(
    'bathymetry_survey_red_line',
    'Bathymetry Survey (Red Line)',
  ),
  other('other', 'Other');

  final String code;
  final String label;

  const SurveyType(this.code, this.label);

  static SurveyType fromCode(String code) {
    return SurveyType.values.firstWhere(
      (e) => e.code == code,
      orElse: () => SurveyType.other,
    );
  }
}

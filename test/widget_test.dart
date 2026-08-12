import 'package:flutter_test/flutter_test.dart';
import 'package:survey_desk/main.dart';

void main() {
  testWidgets('App initialization smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const SurveyDeskApp());
    expect(find.byType(SurveyDeskApp), findsOneWidget);
  });
}

import 'package:dart_chromaprint_example/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('example app offers PCM and WAV file selection', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('Choose PCM file'), findsOneWidget);
    expect(find.text('Choose WAV file'), findsOneWidget);
  });
}

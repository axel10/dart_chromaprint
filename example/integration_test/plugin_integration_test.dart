import 'package:dart_chromaprint_example/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('example app calculates matching PCM and WAV fingerprints', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('PCM and WAV match'), findsOneWidget);
    expect(find.text('From PCM'), findsOneWidget);
    expect(find.text('From WAV bytes'), findsOneWidget);
  });
}

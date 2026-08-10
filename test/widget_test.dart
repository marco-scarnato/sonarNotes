import 'package:flutter_test/flutter_test.dart';
import 'package:sonar_notes/main.dart';

void main() {
  testWidgets('App renders Sonar Notes smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const SonarNotesApp());
    expect(find.text('Sonar Notes'), findsOneWidget);
  });
}

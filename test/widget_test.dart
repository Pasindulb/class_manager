
import 'package:flutter_test/flutter_test.dart';
import 'package:class_manager/main.dart'; // This import is used, as we are testing the main app widget

void main() {
  testWidgets('App loads and displays the title', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const TuitionApp()); // Updated to use TuitionApp instead of MyApp

    // Verify that the app title is displayed.
    expect(find.text('Manage Tuition Classes'), findsOneWidget);
  });
}

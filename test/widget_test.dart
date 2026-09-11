import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/main.dart';

void main() {
  testWidgets('App loads smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MusicApp());

    // Verify that the app loads and displays the Home tab.
    expect(find.text('Home'), findsOneWidget);
  });
}

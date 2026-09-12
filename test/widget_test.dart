import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/main.dart';
import 'package:music_app/services/preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('App loads smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await PreferencesService().init();

    await tester.pumpWidget(const MusicApp());

    // Verify that the app loads and displays the Listen Now tab.
    expect(find.text('Listen Now'), findsWidgets);
  });
}

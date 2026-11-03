import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/screens/main_screen.dart';
import 'package:music_app/services/preferences_service.dart';
import 'package:music_app/services/connectivity_service.dart';
import 'package:music_app/widgets/floating_nav_dock.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({'hasPromptedName': true});
    await PreferencesService().init();
    ConnectivityService().setOfflineForTesting(false);
    ConnectivityService().setQualityForTesting(NetworkQuality.good);
  });

  testWidgets('FloatingNavDock taps respond and switch tabs in MainScreen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: MainScreen(initialIndex: 0)),
    );
    await tester.pumpAndSettle();

    expect(find.byType(FloatingNavDock), findsOneWidget);

    // Initial state: Home tab (index 0)
    var dock = tester.widget<FloatingNavDock>(find.byType(FloatingNavDock));
    expect(dock.selectedIndex, 0);

    // Tap on Search tab (index 1)
    await tester.tap(find.text('Search'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    dock = tester.widget<FloatingNavDock>(find.byType(FloatingNavDock));
    expect(dock.selectedIndex, 1);

    // Tap on Library tab (index 2)
    await tester.tap(find.text('Library'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    dock = tester.widget<FloatingNavDock>(find.byType(FloatingNavDock));
    expect(dock.selectedIndex, 2);

    // Tap on Downloads tab (index 3)
    await tester.tap(find.text('Downloads'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    dock = tester.widget<FloatingNavDock>(find.byType(FloatingNavDock));
    expect(dock.selectedIndex, 3);
  });
}

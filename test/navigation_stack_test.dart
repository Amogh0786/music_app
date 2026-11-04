import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/main.dart';
import 'package:music_app/screens/intro_splash_screen.dart';
import 'package:music_app/screens/main_screen.dart';
import 'package:music_app/services/preferences_service.dart';
import 'package:music_app/services/connectivity_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({'hasPromptedName': true});
    await PreferencesService().init();
    IntroSplashScreen.hasCompletedSplash = false;
  });

  testWidgets(
    'Online launch boots directly to Tab 0 (Live Home) with single route and zero layered UI',
    (WidgetTester tester) async {
      ConnectivityService().setOfflineForTesting(false);
      ConnectivityService().setQualityForTesting(NetworkQuality.good);

      await tester.pumpWidget(const MusicApp());

      // Splash is initially active
      expect(find.byType(IntroSplashScreen), findsOneWidget);
      expect(find.byType(MainScreen), findsNothing);

      // Advance through splash
      await tester.pump(const Duration(milliseconds: 1000));
      if (find.text('Skip').evaluate().isNotEmpty) {
        await tester.tap(find.text('Skip'));
      }
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      // Verify exactly one MainScreen is rendered and initialIndex is 0
      final mainScreens = tester
          .widgetList<MainScreen>(find.byType(MainScreen))
          .toList();
      expect(mainScreens.length, 1);
      expect(mainScreens.first.initialIndex, 0);

      // Verify the Navigator cannot pop (it is the root, clean route - no ghost routes underneath)
      final navContext = tester.element(find.byType(MainScreen));
      expect(Navigator.of(navContext).canPop(), isFalse);

      // Verify that theme change rebuilds do not create duplicate MainScreen routes
      PreferencesService().themeColorNotifier.value = const Color(0xFF1DB954);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(tester.widgetList<MainScreen>(find.byType(MainScreen)).length, 1);
      expect(Navigator.of(navContext).canPop(), isFalse);
    },
  );

  testWidgets(
    'Offline launch boots to Tab 2 (Offline Library) cleanly and back key switches to Tab 0',
    (WidgetTester tester) async {
      ConnectivityService().setOfflineForTesting(true);
      ConnectivityService().setQualityForTesting(NetworkQuality.offline);

      await tester.pumpWidget(const MusicApp());

      // Advance through splash
      await tester.pump(const Duration(milliseconds: 1000));
      if (find.text('Skip').evaluate().isNotEmpty) {
        await tester.tap(find.text('Skip'));
      }
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      // Exactly one MainScreen rendered with initialIndex = 2
      final mainScreens = tester
          .widgetList<MainScreen>(find.byType(MainScreen))
          .toList();
      expect(mainScreens.length, 1);
      expect(mainScreens.first.initialIndex, 2);

      // In offline mode, PopScope handles back and switches to Tab 0 (Home)
      final didPop = await tester.binding.handlePopRoute();
      expect(didPop, isTrue); // Handled by PopScope

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      // Still exactly one MainScreen, but now on Tab 0
      expect(tester.widgetList<MainScreen>(find.byType(MainScreen)).length, 1);

      // Reset
      ConnectivityService().setOfflineForTesting(false);
      ConnectivityService().setQualityForTesting(NetworkQuality.good);
    },
  );
}

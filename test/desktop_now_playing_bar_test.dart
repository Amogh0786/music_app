import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:music_app/layouts/desktop_layout_state.dart';
import 'package:music_app/services/preferences_service.dart';
import 'package:music_app/widgets/desktop/desktop_now_playing_bar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DesktopNowPlayingBar Widget Tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = PreferencesService();
      prefs.resetForTesting();
      await prefs.init();

      DesktopLayoutState.leftSidebarWidth.value = 280.0;
      DesktopLayoutState.isLeftSidebarCollapsed.value = false;
      DesktopLayoutState.isRightPanelVisible.value = true;
      DesktopLayoutState.contextTab.value = DesktopContextTab.nowPlaying;
    });

    testWidgets('Renders all 3 regions with controls and sliders', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(bottomNavigationBar: DesktopNowPlayingBar()),
        ),
      );

      // Verify Track info region
      expect(find.text('No track playing'), findsOneWidget);

      // Verify Center Controls
      expect(find.byIcon(Icons.shuffle_rounded), findsOneWidget);
      expect(find.byIcon(Icons.skip_previous_rounded), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      expect(find.byIcon(Icons.skip_next_rounded), findsOneWidget);
      expect(find.byIcon(Icons.repeat_rounded), findsOneWidget);

      // Verify Right Utilities (Lyrics, Queue, Volume, Panel dock)
      expect(find.byIcon(Icons.lyrics_rounded), findsOneWidget);
      expect(find.byIcon(Icons.queue_music_rounded), findsOneWidget);
      expect(find.byIcon(Icons.dock_rounded), findsOneWidget);

      // Test tapping Lyrics button toggles DesktopLayoutState
      await tester.tap(find.byIcon(Icons.lyrics_rounded));
      await tester.pump();
      expect(DesktopLayoutState.contextTab.value, DesktopContextTab.lyrics);
      expect(DesktopLayoutState.isRightPanelVisible.value, true);

      // Test tapping Queue button toggles DesktopLayoutState
      await tester.tap(find.byIcon(Icons.queue_music_rounded));
      await tester.pump();
      expect(DesktopLayoutState.contextTab.value, DesktopContextTab.queue);
      expect(DesktopLayoutState.isRightPanelVisible.value, true);

      // Test tapping dock icon toggles panel visibility
      await tester.tap(find.byIcon(Icons.dock_rounded));
      await tester.pump();
      expect(DesktopLayoutState.isRightPanelVisible.value, false);
    });

    testWidgets(
      'Renders Jump Back In track when history exists and engine is idle',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        // Populate history
        await PreferencesService().addToListeningHistory({
          'id': 'test_jump_song_123',
          'title': 'Dil Kaa Jo Haal Hai',
          'author': 'Abhijeet Bhattacharya',
          'thumbnail': 'https://example.com/art.jpg',
        });

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(bottomNavigationBar: DesktopNowPlayingBar()),
          ),
        );
        await tester.pump();

        expect(find.text('JUMP BACK IN'), findsOneWidget);
        expect(find.text('Dil Kaa Jo Haal Hai'), findsOneWidget);
        expect(find.text('Abhijeet Bhattacharya'), findsOneWidget);
        expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
      },
    );

    testWidgets('Scrubber displays timestamps and renders slider safely', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(bottomNavigationBar: DesktopNowPlayingBar()),
        ),
      );
      await tester.pump();

      // Timestamps initially at 0:00
      expect(find.text('0:00'), findsNWidgets(2));
      expect(find.byType(Slider), findsWidgets);
    });

    testWidgets(
      'Propagates dynamic theme accent color to scrubber slider theme',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        const customAccent = Color(0xFF1E88E5); // Electric Blue
        PreferencesService().setThemeColor(customAccent);

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(bottomNavigationBar: DesktopNowPlayingBar()),
          ),
        );
        await tester.pump();

        final sliderTheme = tester.widget<SliderTheme>(
          find.byType(SliderTheme).first,
        );
        expect(sliderTheme.data.activeTrackColor, customAccent);
      },
    );
  });
}

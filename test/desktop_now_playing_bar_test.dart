import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/layouts/desktop_layout_state.dart';
import 'package:music_app/widgets/desktop/desktop_now_playing_bar.dart';

void main() {
  group('DesktopNowPlayingBar Widget Tests', () {
    setUp(() {
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
  });
}

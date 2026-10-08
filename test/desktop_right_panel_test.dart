import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/layouts/desktop_layout_state.dart';
import 'package:music_app/widgets/desktop/desktop_right_panel.dart';

void main() {
  group('DesktopRightPanel Widget Tests', () {
    setUp(() {
      DesktopLayoutState.leftSidebarWidth.value = 280.0;
      DesktopLayoutState.isLeftSidebarCollapsed.value = false;
      DesktopLayoutState.isRightPanelVisible.value = true;
      DesktopLayoutState.contextTab.value = DesktopContextTab.nowPlaying;
    });

    testWidgets(
      'Renders Now Playing Tab by default and closes on close button',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SizedBox(width: 280.0, child: DesktopRightPanel()),
            ),
          ),
        );

        // Verify Header
        expect(find.text('Now Playing'), findsOneWidget);
        expect(find.byIcon(Icons.close_rounded), findsOneWidget);

        // Verify Close Action
        await tester.tap(find.byIcon(Icons.close_rounded));
        await tester.pump();
        expect(DesktopLayoutState.isRightPanelVisible.value, false);
      },
    );

    testWidgets('Renders Lyrics Tab and returns via back button', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      DesktopLayoutState.contextTab.value = DesktopContextTab.lyrics;

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(width: 280.0, child: DesktopRightPanel()),
          ),
        ),
      );

      // Verify Lyrics Header and back button
      expect(find.text('Lyrics'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);

      // Tap back button
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pump();
      expect(DesktopLayoutState.contextTab.value, DesktopContextTab.nowPlaying);
    });

    testWidgets('Renders Queue Tab and displays Queue header', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      DesktopLayoutState.contextTab.value = DesktopContextTab.queue;

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(width: 280.0, child: DesktopRightPanel()),
          ),
        ),
      );

      // Header should say Queue
      expect(find.text('Queue'), findsWidgets);
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);

      // Tap back button
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pump();
      expect(DesktopLayoutState.contextTab.value, DesktopContextTab.nowPlaying);
    });
  });
}

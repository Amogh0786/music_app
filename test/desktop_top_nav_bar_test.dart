import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/layouts/desktop_layout_state.dart';
import 'package:music_app/widgets/desktop/desktop_top_nav_bar.dart';

void main() {
  group('DesktopTopNavBar Widget Tests', () {
    setUp(() {
      DesktopLayoutState.activeNavTab.value = DesktopNavTab.home;
      DesktopLayoutState.globalSearchQuery.value = '';
      DesktopLayoutState.isRightPanelVisible.value = true;
    });

    testWidgets(
      'Renders Logo, Search Pill, Shortcut Badge, and Action buttons',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: DesktopTopNavBar())),
        );

        // Verify Brand Logo
        expect(find.text('DilSe Music'), findsOneWidget);

        // Verify Search Pill
        expect(find.text('What do you want to play?'), findsOneWidget);
        expect(find.text('Ctrl+Shift+L'), findsOneWidget);

        // Verify Action icons
        expect(find.byIcon(Icons.auto_awesome_rounded), findsOneWidget);
        expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
        expect(find.byIcon(Icons.view_sidebar_rounded), findsOneWidget);
        expect(find.byIcon(Icons.person_rounded), findsOneWidget);
      },
    );

    testWidgets('Typing in search updates global search query and active tab', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: DesktopTopNavBar())),
      );

      // Enter search text
      await tester.enterText(find.byType(TextField), 'Anirudh');
      await tester.pump();

      expect(DesktopLayoutState.globalSearchQuery.value, 'Anirudh');
      expect(DesktopLayoutState.activeNavTab.value, DesktopNavTab.search);

      // Tapping logo clears search and switches to Home
      await tester.tap(find.text('DilSe Music'));
      await tester.pump();

      expect(DesktopLayoutState.globalSearchQuery.value, '');
      expect(DesktopLayoutState.activeNavTab.value, DesktopNavTab.home);
    });
  });
}

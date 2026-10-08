import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/layouts/desktop_layout_state.dart';
import 'package:music_app/layouts/desktop_main_viewport.dart';
import 'package:music_app/screens/home_screen.dart';

void main() {
  group('DesktopMainViewport Widget Tests', () {
    setUp(() {
      DesktopLayoutState.activeNavTab.value = DesktopNavTab.home;
    });

    testWidgets('Switches active screen index when activeNavTab changes', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: DesktopMainViewport())),
      );

      // Verify IndexedStack is present and initially at index 0 (HomeScreen)
      final indexedStackFinder = find.byType(IndexedStack);
      expect(indexedStackFinder, findsOneWidget);

      IndexedStack indexedStack = tester.widget<IndexedStack>(
        indexedStackFinder,
      );
      expect(indexedStack.index, 0);
      expect(find.byType(HomeScreen), findsOneWidget);

      // Switch to Search (Index 1)
      DesktopLayoutState.setNavTab(DesktopNavTab.search);
      await tester.pump();
      indexedStack = tester.widget<IndexedStack>(indexedStackFinder);
      expect(indexedStack.index, 1);

      // Switch to Library (Index 2)
      DesktopLayoutState.setNavTab(DesktopNavTab.library);
      await tester.pump();
      indexedStack = tester.widget<IndexedStack>(indexedStackFinder);
      expect(indexedStack.index, 2);

      // Switch back to Home (Index 0)
      DesktopLayoutState.setNavTab(DesktopNavTab.home);
      await tester.pump();
      indexedStack = tester.widget<IndexedStack>(indexedStackFinder);
      expect(indexedStack.index, 0);
    });
  });
}

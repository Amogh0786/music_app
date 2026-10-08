import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/layouts/desktop_app_shell.dart';
import 'package:music_app/layouts/desktop_layout_state.dart';
import 'package:music_app/widgets/desktop/desktop_resize_divider.dart';
import 'package:music_app/widgets/desktop/desktop_top_nav_bar.dart';

void main() {
  group('DesktopLayoutState Unit Tests', () {
    setUp(() {
      DesktopLayoutState.leftSidebarWidth.value = 280.0;
      DesktopLayoutState.isLeftSidebarCollapsed.value = false;
      DesktopLayoutState.isRightPanelVisible.value = true;
      DesktopLayoutState.contextTab.value = DesktopContextTab.nowPlaying;
    });

    test('updateLeftSidebarWidth clamps between 72 and 398', () {
      DesktopLayoutState.updateLeftSidebarWidth(350.0);
      expect(DesktopLayoutState.leftSidebarWidth.value, 350.0);
      expect(DesktopLayoutState.isLeftSidebarCollapsed.value, false);

      DesktopLayoutState.updateLeftSidebarWidth(500.0);
      expect(DesktopLayoutState.leftSidebarWidth.value, 398.0);
    });

    test('updateLeftSidebarWidth snaps to 72 when dragged below 120', () {
      DesktopLayoutState.updateLeftSidebarWidth(110.0);
      expect(DesktopLayoutState.leftSidebarWidth.value, 72.0);
      expect(DesktopLayoutState.isLeftSidebarCollapsed.value, true);
    });

    test('toggleLeftSidebar switches between 280 and 72', () {
      DesktopLayoutState.toggleLeftSidebar();
      expect(DesktopLayoutState.leftSidebarWidth.value, 72.0);
      expect(DesktopLayoutState.isLeftSidebarCollapsed.value, true);

      DesktopLayoutState.toggleLeftSidebar();
      expect(DesktopLayoutState.leftSidebarWidth.value, 280.0);
      expect(DesktopLayoutState.isLeftSidebarCollapsed.value, false);
    });

    test('toggleRightPanel and setContextTab work properly', () {
      DesktopLayoutState.toggleRightPanel();
      expect(DesktopLayoutState.isRightPanelVisible.value, false);

      DesktopLayoutState.setContextTab(DesktopContextTab.lyrics);
      expect(DesktopLayoutState.contextTab.value, DesktopContextTab.lyrics);
      expect(DesktopLayoutState.isRightPanelVisible.value, true);
    });
  });

  group('DesktopAppShell Widget Tests', () {
    testWidgets('Renders mobileBody on narrow screen', (tester) async {
      tester.view.physicalSize = const Size(800, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: DesktopAppShell(mobileBody: Text('Mobile Body Content')),
        ),
      );

      expect(find.text('Mobile Body Content'), findsOneWidget);
      expect(find.byType(DesktopTopNavBar), findsNothing);
    });
  });
}

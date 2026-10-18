import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/layouts/desktop_layout_state.dart';
import 'package:music_app/widgets/desktop/desktop_left_sidebar.dart';
import 'package:music_app/widgets/shimmer_loading.dart';
import 'package:music_app/screens/curated_playlist_screen.dart';

void main() {
  group('Request Handling & Door Scheduling System Tests', () {
    setUp(() {
      DesktopLayoutState.isHomeFeedComplete.value = false;
      DesktopLayoutState.prioritizedPlaylistDoor.value = null;
      DesktopLayoutState.activeNavTab.value = DesktopNavTab.home;
      DesktopLayoutState.globalSearchQuery.value = '';
    });

    test(
      'DesktopLayoutState prioritizeDoor updates prioritized door properly',
      () {
        expect(DesktopLayoutState.prioritizedPlaylistDoor.value, isNull);

        DesktopLayoutState.prioritizeDoor('daily_mix_2');
        expect(DesktopLayoutState.prioritizedPlaylistDoor.value, 'daily_mix_2');

        DesktopLayoutState.prioritizeDoor('Telugu Top Hits');
        expect(
          DesktopLayoutState.prioritizedPlaylistDoor.value,
          'Telugu Top Hits',
        );
      },
    );

    test('Search Tab & Global Query priority flags toggle accurately', () {
      expect(DesktopLayoutState.activeNavTab.value, DesktopNavTab.home);
      expect(DesktopLayoutState.globalSearchQuery.value, '');

      // Switch to search tab
      DesktopLayoutState.setNavTab(DesktopNavTab.search);
      expect(DesktopLayoutState.activeNavTab.value, DesktopNavTab.search);

      // Set search query
      DesktopLayoutState.globalSearchQuery.value = 'Anirudh';
      expect(DesktopLayoutState.globalSearchQuery.value, 'Anirudh');

      // Clear search query
      DesktopLayoutState.globalSearchQuery.value = '';
      expect(DesktopLayoutState.globalSearchQuery.value, '');

      // Switch back to home
      DesktopLayoutState.setNavTab(DesktopNavTab.home);
      expect(DesktopLayoutState.activeNavTab.value, DesktopNavTab.home);
    });

    testWidgets(
      'DesktopLeftSidebar displays ShimmerSidebarRow while Home feed is loading',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        // Expanded mode (width 280)
        DesktopLayoutState.leftSidebarWidth.value = 280.0;
        DesktopLayoutState.isLeftSidebarCollapsed.value = false;
        DesktopLayoutState.isHomeFeedComplete.value = false;

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 280,
                height: 900,
                child: DesktopLeftSidebar(width: 280),
              ),
            ),
          ),
        );

        // Verify ShimmerSidebarRow widgets are rendered in expanded mode
        expect(find.byType(ShimmerSidebarRow), findsWidgets);

        // Transition Home Feed to complete
        DesktopLayoutState.isHomeFeedComplete.value = true;
        await tester.pump();

        // Shimmer should now be replaced by actual library content
        expect(find.byType(ShimmerSidebarRow), findsNothing);
      },
    );

    testWidgets(
      'DesktopLeftSidebar in compact mode (72px) displays compact shimmer before feed completes',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        // Compact mode (width 72)
        DesktopLayoutState.leftSidebarWidth.value = 72.0;
        DesktopLayoutState.isLeftSidebarCollapsed.value = true;
        DesktopLayoutState.isHomeFeedComplete.value = false;

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 72,
                height: 900,
                child: DesktopLeftSidebar(width: 72),
              ),
            ),
          ),
        );

        // Verify compact ShimmerSidebarRow widgets are present
        expect(find.byType(ShimmerSidebarRow), findsWidgets);

        // Transition Home Feed to complete
        DesktopLayoutState.isHomeFeedComplete.value = true;
        await tester.pump();

        // Compact shimmer replaced by playlist avatars
        expect(find.byType(ShimmerSidebarRow), findsNothing);
      },
    );

    testWidgets(
      'CuratedPlaylistScreen triggers prioritizeDoor and renders ShimmerSongRow on entry',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: CuratedPlaylistScreen(
                title: 'Telugu Hits',
                subtitle: 'Top daily picks',
                query: 'Telugu Top 50',
              ),
            ),
          ),
        );

        // Verify that CuratedPlaylistScreen immediately prioritized its door
        expect(
          DesktopLayoutState.prioritizedPlaylistDoor.value,
          'Telugu Top 50',
        );

        // Verify smooth ShimmerSongRow skeleton is rendered while fetching
        expect(find.byType(ShimmerSongRow), findsWidgets);
      },
    );
  });
}

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

    testWidgets('Renders CustomPlaylistScreen when openPlaylist is invoked', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: DesktopMainViewport())),
      );

      DesktopLayoutState.openPlaylist('sample_playlist_id');
      await tester.pump();

      expect(
        DesktopLayoutState.activeNavTab.value,
        DesktopNavTab.customPlaylist,
      );
      expect(DesktopLayoutState.activePlaylistId.value, 'sample_playlist_id');

      // Close detail view
      DesktopLayoutState.closeDetailView();
      await tester.pump();
      expect(DesktopLayoutState.activeNavTab.value, DesktopNavTab.home);
      expect(DesktopLayoutState.activePlaylistId.value, null);
    });

    testWidgets('Renders ArtistProfileScreen when openArtist is invoked', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: DesktopMainViewport())),
      );

      DesktopLayoutState.openArtist('Anuv Jain');
      await tester.pump();

      expect(
        DesktopLayoutState.activeNavTab.value,
        DesktopNavTab.artistProfile,
      );
      expect(DesktopLayoutState.activeArtistName.value, 'Anuv Jain');

      // Close detail view
      DesktopLayoutState.closeDetailView();
      await tester.pump();
      expect(DesktopLayoutState.activeNavTab.value, DesktopNavTab.home);
      expect(DesktopLayoutState.activeArtistName.value, null);
    });

    testWidgets('Renders AlbumScreen when openAlbum is invoked', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: DesktopMainViewport())),
      );

      DesktopLayoutState.openAlbum(
        albumId: 'sample_album_id',
        albumTitle: 'Soundtracks',
        albumArtwork: 'https://example.com/art.jpg',
        albumArtist: 'Eddy',
      );
      await tester.pump();

      expect(DesktopLayoutState.activeNavTab.value, DesktopNavTab.album);
      expect(
        DesktopLayoutState.activeAlbumData.value?['albumId'],
        'sample_album_id',
      );

      // Close detail view
      DesktopLayoutState.closeDetailView();
      await tester.pump();
      expect(DesktopLayoutState.activeNavTab.value, DesktopNavTab.home);
      expect(DesktopLayoutState.activeAlbumData.value, null);
    });

    testWidgets(
      'Renders Liked Songs in CustomPlaylistScreen when openPlaylist(liked_songs) is invoked',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: DesktopMainViewport())),
        );

        DesktopLayoutState.openPlaylist('liked_songs');
        await tester.pumpAndSettle();

        expect(
          DesktopLayoutState.activeNavTab.value,
          DesktopNavTab.customPlaylist,
        );
        expect(DesktopLayoutState.activePlaylistId.value, 'liked_songs');
        expect(find.text('Liked Songs'), findsWidgets);

        // Close detail view
        DesktopLayoutState.closeDetailView();
        await tester.pumpAndSettle();
        expect(DesktopLayoutState.activeNavTab.value, DesktopNavTab.home);
        expect(DesktopLayoutState.activePlaylistId.value, null);
      },
    );
  });
}

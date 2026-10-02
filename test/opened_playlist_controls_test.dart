import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/screens/custom_playlist_screen.dart';
import 'package:music_app/services/music_service.dart';
import 'package:music_app/services/preferences_service.dart';
import 'package:music_app/widgets/mini_player.dart';
import 'package:music_app/widgets/playlist_action_menu.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MusicService musicService;

  setUp(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => '.',
        );
    SharedPreferences.setMockInitialValues({
      'listeningHistoryJson': '[]',
      'searchHistory': <String>[],
      'spotify_imported_playlist_ids': <String>[],
    });
    await PreferencesService().init();

    musicService = MusicService();
    musicService.customPlaylists.clear();
    musicService.customPlaylists.add({
      'id': 'test_playlist_opened',
      'name': 'Telugu Party Hits',
      'songs': [
        {
          'id': 'song_1',
          'title': 'Samajavaragamana',
          'author': 'Sid Sriram',
          'thumbnail': 'https://example.com/1.jpg',
        },
        {
          'id': 'song_2',
          'title': 'Butta Bomma',
          'author': 'Armaan Malik',
          'thumbnail': 'https://example.com/2.jpg',
        },
      ],
    });
  });

  testWidgets(
    'Opened playlist controls: Play button and More button exist, no mini-player',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: CustomPlaylistScreen(playlistId: 'test_playlist_opened'),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Verify Play button is present
      final playButtonFinder = find.widgetWithText(ElevatedButton, 'Play');
      expect(playButtonFinder, findsOneWidget);

      // 2. Verify PlaylistActionMenu (More button) is present immediately beside Play
      final moreMenuFinder = find.byType(PlaylistActionMenu);
      expect(moreMenuFinder, findsOneWidget);

      // 3. Verify No MiniPlayer is present on the screen
      expect(find.byType(MiniPlayer), findsNothing);

      // 4. Verify no separate pencil/edit or trash/delete icons beside Play button
      // Search for edit icon beside Play (should only appear inside the popup menu when opened)
      expect(find.byIcon(Icons.edit_outlined), findsNothing);
      expect(find.byIcon(Icons.edit_rounded), findsNothing);

      // 5. Tap the More button to open options
      await tester.tap(moreMenuFinder);
      await tester.pumpAndSettle();

      // 6. Verify Rename and Delete options are accessible through the More menu
      expect(find.text('Rename'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);

      // 7. Test Rename flow
      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();

      expect(find.text('Rename Playlist'), findsOneWidget);
      final dialogTextField = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      );
      await tester.enterText(dialogTextField, 'Telugu Mega Hits');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(
        musicService.customPlaylists.first['name'],
        equals('Telugu Mega Hits'),
      );
    },
  );

  testWidgets(
    'Opened playlist controls: Delete playlist pops screen after confirmation',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const CustomPlaylistScreen(
                      playlistId: 'test_playlist_opened',
                    ),
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Navigate to CustomPlaylistScreen
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Telugu Party Hits'), findsWidgets);

      // Tap More button
      await tester.tap(find.byType(PlaylistActionMenu));
      await tester.pumpAndSettle();

      // Tap Delete
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Delete Playlist'), findsOneWidget);

      // Confirm delete in dialog
      await tester.tap(find.widgetWithText(ElevatedButton, 'Delete'));
      await tester.pumpAndSettle();

      // Verify playlist is removed from musicService
      expect(musicService.customPlaylists.isEmpty, isTrue);

      // Verify screen popped back to previous route
      expect(find.text('Open'), findsOneWidget);
    },
  );
}

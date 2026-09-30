import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/screens/home_screen.dart';
import 'package:music_app/services/music_service.dart';
import 'package:music_app/services/preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.ryanheise.just_audio.methods'),
          (call) async => null,
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => '.',
        );
    final prefs = PreferencesService();
    prefs.resetForTesting();
    await prefs.init();

    final musicService = MusicService();
    musicService.resetForTesting();
  });

  group('Smart Session Persistence - PreferencesService Tests', () {
    test(
      'Saving and restoring last playback session correctly persists all data',
      () async {
        final prefs = PreferencesService();
        expect(prefs.lastPlayedSong, isNull);
        expect(prefs.lastPlayedPositionMs, equals(0));

        final songData = {
          'id': 'test_video_123',
          'title': 'Test Song Title',
          'author': 'Test Artist',
          'thumbnail': 'https://example.com/art.jpg',
          'durationMs': 210000,
        };

        final playlistData = [
          songData,
          {
            'id': 'test_video_456',
            'title': 'Second Song',
            'author': 'Second Artist',
            'thumbnail': 'https://example.com/art2.jpg',
            'durationMs': 180000,
          },
        ];

        await prefs.saveLastPlaybackSession(
          song: songData,
          positionMs: 45000,
          durationMs: 210000,
          playlist: playlistData,
          playlistIndex: 0,
          dominantColor: const Color(0xFF112233),
          vibrantColor: const Color(0xFF445566),
          darkVibrantColor: const Color(0xFF778899),
        );

        expect(prefs.lastPlayedSong, isNotNull);
        expect(prefs.lastPlayedSong!['id'], equals('test_video_123'));
        expect(prefs.lastPlayedSong!['title'], equals('Test Song Title'));
        expect(prefs.lastPlayedPositionMs, equals(45000));
        expect(prefs.lastPlayedDurationMs, equals(210000));
        expect(prefs.lastPlayedPlaylist.length, equals(2));
        expect(prefs.lastPlayedPlaylistIndex, equals(0));
        expect(
          prefs.lastPlayedDominantColor,
          equals(const Color(0xFF112233).toARGB32()),
        );

        // Update position
        await prefs.updateLastPlaybackPosition(60000, durationMs: 210000);
        expect(prefs.lastPlayedPositionMs, equals(60000));

        // Clear session
        await prefs.clearLastPlaybackSession();
        expect(prefs.lastPlayedSong, isNull);
        expect(prefs.lastPlayedPositionMs, equals(0));
        expect(prefs.lastPlayedDurationMs, equals(0));
        expect(prefs.lastPlayedPlaylist, isEmpty);
      },
    );
  });

  group('Smart Session Persistence - MusicService Session Handlers', () {
    test(
      'restoreLastPlaybackSession populates currentSong and state from PreferencesService',
      () async {
        final prefs = PreferencesService();
        final songData = {
          'id': '12345678901',
          'title': 'Restored Track',
          'author': 'Restored Artist',
          'thumbnail': 'https://example.com/thumb.jpg',
          'durationMs': 120000,
          'streamUrl': 'https://example.com/stream.mp4',
        };

        await prefs.saveLastPlaybackSession(
          song: songData,
          positionMs: 30000,
          durationMs: 120000,
          playlist: [songData],
          playlistIndex: 0,
        );

        final musicService = MusicService();
        musicService.restoreLastPlaybackSession();

        expect(musicService.currentSong, isNotNull);
        expect(musicService.currentSong!.title, equals('Restored Track'));
        expect(musicService.currentSong!.author, equals('Restored Artist'));
        expect(musicService.position.inMilliseconds, equals(30000));
        expect(musicService.duration?.inMilliseconds, equals(120000));
        expect(musicService.playlist.length, equals(1));
      },
    );

    test(
      'persistPlaybackSession saves currently playing track state without timers',
      () async {
        final prefs = PreferencesService();
        final musicService = MusicService();

        final video = Video(
          VideoId('abcdefghijk'),
          'Persisted Song',
          'Persisted Artist',
          ChannelId('UC0WP5P-fwGlLyO4yOE76T8g'),
          DateTime.now(),
          '',
          null,
          '',
          const Duration(minutes: 3),
          ThumbnailSet('abcdefghijk'),
          null,
          Engagement(0, null, null),
          false,
        );

        musicService.setPlaylistForTesting([video], initialIndex: 0);
        await musicService.persistPlaybackSession(
          pos: const Duration(seconds: 45),
          force: true,
        );

        expect(prefs.lastPlayedSong, isNotNull);
        expect(prefs.lastPlayedSong!['title'], equals('Persisted Song'));
        expect(prefs.lastPlayedPositionMs, equals(45000));
      },
    );
  });

  group('HomeScreen Quick Resume Banner UI Tests', () {
    testWidgets(
      'Quick resume banner renders when lastPlayedSong exists and not playing',
      (tester) async {
        final prefs = PreferencesService();
        final musicService = MusicService();
        musicService.resetForTesting();

        final songData = {
          'id': '12345678901',
          'title': 'Resume Melody',
          'author': 'Melody Master',
          'thumbnail': '',
          'durationMs': 200000,
        };

        await prefs.saveLastPlaybackSession(
          song: songData,
          positionMs: 50000,
          durationMs: 200000,
        );

        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: HomeScreen())),
        );
        await tester.pumpAndSettle();

        expect(find.text('JUMP BACK IN'), findsOneWidget);
        expect(find.text('Resume Melody'), findsOneWidget);
        expect(find.text('Melody Master'), findsOneWidget);
        expect(find.byIcon(Icons.play_circle_fill_rounded), findsOneWidget);
        expect(find.byIcon(Icons.close_rounded), findsOneWidget);

        // Dismiss banner
        await tester.tap(find.byIcon(Icons.close_rounded));
        await tester.pumpAndSettle();

        expect(prefs.lastPlayedSong, isNull);
        expect(find.text('JUMP BACK IN'), findsNothing);
      },
    );
  });
}

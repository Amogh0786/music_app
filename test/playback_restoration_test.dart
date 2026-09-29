import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:music_app/services/preferences_service.dart';
import 'package:music_app/services/music_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Playback State Persistence & Restoration Tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('com.ryanheise.just_audio.methods'), (call) async {
        return null;
      });
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/path_provider'), (call) async {
        return '.';
      });
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('home_widget'), (call) async {
        return null;
      });
      await PreferencesService().init();
    });

    test('PreferencesService saves and retrieves last played song session accurately', () async {
      final prefs = PreferencesService();
      expect(prefs.lastPlayedSong, isNull);
      expect(prefs.lastPlayedPositionMs, 0);
      expect(prefs.lastPlayedDurationMs, 0);

      final testSong = {
        'id': 'dQw4w9WgXcQ',
        'title': 'Never Gonna Give You Up',
        'author': 'Rick Astley',
        'durationMs': 213000,
        'thumbnail': 'https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg',
        'streamUrl': 'https://example.com/stream.m4a',
      };

      await prefs.saveLastPlaybackSession(
        song: testSong,
        positionMs: 84000,
        durationMs: 213000,
        playlist: [testSong],
        playlistIndex: 0,
        dominantColor: const Color(0xFF1E1E2C),
        vibrantColor: const Color(0xFFFA2D48),
        darkVibrantColor: const Color(0xFF101018),
      );

      expect(prefs.lastPlayedSong, isNotNull);
      expect(prefs.lastPlayedSong!['id'], 'dQw4w9WgXcQ');
      expect(prefs.lastPlayedSong!['title'], 'Never Gonna Give You Up');
      expect(prefs.lastPlayedPositionMs, 84000);
      expect(prefs.lastPlayedDurationMs, 213000);
      expect(prefs.lastPlayedPlaylist.length, 1);
      expect(prefs.lastPlayedPlaylistIndex, 0);
      expect(prefs.lastPlayedDominantColor, const Color(0xFF1E1E2C).toARGB32());
      expect(prefs.lastPlayedVibrantColor, const Color(0xFFFA2D48).toARGB32());
    });

    test('updateLastPlaybackPosition updates timestamp without clearing song info', () async {
      final prefs = PreferencesService();
      final testSong = {
        'id': 'test_song_123',
        'title': 'Samajavaragamana',
        'author': 'Sid Sriram',
        'durationMs': 240000,
      };

      await prefs.saveLastPlaybackSession(
        song: testSong,
        positionMs: 30000,
        durationMs: 240000,
      );

      await prefs.updateLastPlaybackPosition(95000, durationMs: 240000);

      expect(prefs.lastPlayedSong!['id'], 'test_song_123');
      expect(prefs.lastPlayedPositionMs, 95000);
      expect(prefs.lastPlayedDurationMs, 240000);
    });

    test('clearLastPlaybackSession completely wipes saved playback state', () async {
      final prefs = PreferencesService();
      await prefs.saveLastPlaybackSession(
        song: {'id': 'clear_me', 'title': 'Test'},
        positionMs: 12000,
        durationMs: 180000,
      );

      expect(prefs.lastPlayedSong, isNotNull);

      await prefs.clearLastPlaybackSession();

      expect(prefs.lastPlayedSong, isNull);
      expect(prefs.lastPlayedPositionMs, 0);
      expect(prefs.lastPlayedDurationMs, 0);
      expect(prefs.lastPlayedPlaylist, isEmpty);
    });

    test('End of track detection resets position to 0 if left within 2 seconds of track end', () {
      int calculatePersistedPosition(int curPosMs, int durMs) {
        if (durMs > 0 && curPosMs >= durMs - 2000) {
          return 0;
        }
        return curPosMs;
      }

      // Normal mid-song timestamp: preserved exactly
      expect(calculatePersistedPosition(102000, 225000), 102000);

      // Within 2 seconds of ending (224000 of 225000): resets to start
      expect(calculatePersistedPosition(224000, 225000), 0);

      // Exactly at ending: resets to start
      expect(calculatePersistedPosition(225000, 225000), 0);

      // Unknown duration (0): preserves position
      expect(calculatePersistedPosition(45000, 0), 45000);
    });

    test('restoreLastPlaybackSession successfully restores song and duration into MusicService', () async {
      final testSong = {
        'id': 'abc123xyz00',
        'title': 'Kurchi Madathapetti',
        'author': 'Thaman S',
        'durationMs': 210000,
        'thumbnail': 'https://example.com/thumb.jpg',
        'streamUrl': 'https://example.com/stream.m4a',
      };

      final prefs = PreferencesService();
      await prefs.saveLastPlaybackSession(
        song: testSong,
        positionMs: 75000,
        durationMs: 210000,
        dominantColor: const Color(0xFF3A1C28),
        vibrantColor: const Color(0xFFFA2D48),
      );

      final musicService = MusicService();
      musicService.restoreLastPlaybackSession();

      expect(musicService.currentSong, isNotNull);
      expect(musicService.currentSong!.id.value, 'abc123xyz00');
      expect(musicService.currentSong!.title, 'Kurchi Madathapetti');
      expect(musicService.currentSong!.author, 'Thaman S');

      // Before audio player begins live playback, position and duration report restored values
      expect(musicService.position, const Duration(milliseconds: 75000));
      expect(musicService.duration, const Duration(milliseconds: 210000));
      expect(musicService.savedPosition, const Duration(milliseconds: 75000));
      expect(musicService.savedDuration, const Duration(milliseconds: 210000));
    });
  });
}

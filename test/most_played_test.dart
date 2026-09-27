import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/services/music_service.dart';
import 'package:music_app/services/preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Real-Time Most Played Songs & Playlist Tests', () {
    late PreferencesService prefs;

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
      prefs = PreferencesService();
      prefs.resetForTesting();
      await prefs.init();
    });

    test('Recording song playback adds song to mostPlayedSongs with playCount = 1', () async {
      await prefs.addToListeningHistory({
        'id': 'track_1',
        'title': 'Samajavaragamana',
        'author': 'Sid Sriram',
        'thumbnail': 'https://example.com/thumb1.jpg',
      });

      final mostPlayed = prefs.mostPlayedSongs;
      expect(mostPlayed.length, equals(1));
      expect(mostPlayed.first['id'], equals('track_1'));
      expect(mostPlayed.first['title'], equals('Samajavaragamana'));
      expect(mostPlayed.first['author'], equals('Sid Sriram'));
      expect(mostPlayed.first['playCount'], equals(1));
    });

    test('Play count increments on repeated plays of the same song', () async {
      final song = {
        'id': 'track_fear',
        'title': 'Fear Song',
        'author': 'Anirudh Ravichander',
        'thumbnail': 'https://example.com/fear.jpg',
      };

      await prefs.addToListeningHistory(song);
      await prefs.addToListeningHistory(song);
      await prefs.addToListeningHistory(song);

      final mostPlayed = prefs.mostPlayedSongs;
      expect(mostPlayed.length, equals(1));
      expect(mostPlayed.first['playCount'], equals(3));
    });

    test('mostPlayedSongs is sorted strictly from highest to lowest play count in real time', () async {
      // Song A played 2 times
      for (int i = 0; i < 2; i++) {
        await prefs.addToListeningHistory({
          'id': 'song_a',
          'title': 'Song A',
          'author': 'Artist A',
        });
      }

      // Song B played 5 times
      for (int i = 0; i < 5; i++) {
        await prefs.addToListeningHistory({
          'id': 'song_b',
          'title': 'Song B',
          'author': 'Artist B',
        });
      }

      // Song C played 3 times
      for (int i = 0; i < 3; i++) {
        await prefs.addToListeningHistory({
          'id': 'song_c',
          'title': 'Song C',
          'author': 'Artist C',
        });
      }

      var mostPlayed = prefs.mostPlayedSongs;
      expect(mostPlayed.length, equals(3));
      expect(mostPlayed[0]['id'], equals('song_b'));
      expect(mostPlayed[0]['playCount'], equals(5));
      expect(mostPlayed[1]['id'], equals('song_c'));
      expect(mostPlayed[1]['playCount'], equals(3));
      expect(mostPlayed[2]['id'], equals('song_a'));
      expect(mostPlayed[2]['playCount'], equals(2));

      // Now Song A is streamed 6 more times (total 8 plays)
      for (int i = 0; i < 6; i++) {
        await prefs.addToListeningHistory({
          'id': 'song_a',
          'title': 'Song A',
          'author': 'Artist A',
        });
      }

      // Song A must dynamically overtake Song B as #1 in real time!
      mostPlayed = prefs.mostPlayedSongs;
      expect(mostPlayed[0]['id'], equals('song_a'));
      expect(mostPlayed[0]['playCount'], equals(8));
      expect(mostPlayed[1]['id'], equals('song_b'));
      expect(mostPlayed[1]['playCount'], equals(5));
    });

    test('mostPlayedSongs is strictly capped at maximum 100 songs', () async {
      // Play 120 unique songs
      for (int i = 1; i <= 120; i++) {
        await prefs.addToListeningHistory({
          'id': 'track_$i',
          'title': 'Track Number $i',
          'author': 'Artist $i',
        });
      }

      final mostPlayed = prefs.mostPlayedSongs;
      expect(mostPlayed.length, equals(100)); // Never exceeds 100!
    });

    test('Can contain fewer than 100 songs if user played fewer', () async {
      for (int i = 1; i <= 7; i++) {
        await prefs.addToListeningHistory({
          'id': 'track_$i',
          'title': 'Track $i',
          'author': 'Artist $i',
        });
      }

      final mostPlayed = prefs.mostPlayedSongs;
      expect(mostPlayed.length, equals(7));
    });

    test('Canonical deduplication aggregates play counts for identical songs across different IDs', () async {
      // YouTube music video upload
      await prefs.addToListeningHistory({
        'id': 'yt_vid_1',
        'title': 'Chuttamalle (From "Devara")',
        'author': 'Anirudh Ravichander, Shilpa Rao',
      });

      // JioSaavn / YouTube Music studio master upload of same track
      await prefs.addToListeningHistory({
        'id': 'jio_audio_2',
        'title': 'Chuttamalle',
        'author': 'Anirudh Ravichander',
      });

      final mostPlayed = prefs.mostPlayedSongs;
      // Should deduplicate and aggregate to 2 plays instead of 2 separate duplicate entries!
      expect(mostPlayed.length, equals(1));
      expect(mostPlayed.first['playCount'], equals(2));
    });

    test('playMostPlayedSong queues all most played tracks into playlist and plays target index', () async {
      final musicService = MusicService();

      // Seed 3 tracks
      await prefs.addToListeningHistory({
        'id': 'seed_1',
        'title': 'Hukum',
        'author': 'Anirudh',
      });
      await prefs.addToListeningHistory({
        'id': 'seed_2',
        'title': 'Srivalli',
        'author': 'Sid Sriram',
      });
      await prefs.addToListeningHistory({
        'id': 'seed_3',
        'title': 'Kesariya',
        'author': 'Arijit Singh',
      });

      final mostPlayed = prefs.mostPlayedSongs;
      expect(mostPlayed.length, equals(3));

      // Play the second track (startIndex = 1)
      musicService.playMostPlayedSong(mostPlayed[1], allSongs: mostPlayed, startIndex: 1);

      expect(musicService.playlist.length, equals(3));
      expect(musicService.currentIndex, equals(1));
      expect(musicService.playlist[0].title, equals(mostPlayed[0]['title']));
      expect(musicService.playlist[1].title, equals(mostPlayed[1]['title']));
      expect(musicService.playlist[2].title, equals(mostPlayed[2]['title']));
    });
  });
}

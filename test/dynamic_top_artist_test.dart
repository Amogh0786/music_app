import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/services/preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Dynamic Real-Time Top Artist Tests', () {
    late PreferencesService prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = PreferencesService();
      prefs.resetForTesting();
      await prefs.init();
    });

    test(
      'Plays of a song resolve canonical artists and update mostPlayedArtist in real time',
      () async {
        // User plays 2 songs by Sid Sriram
        await prefs.recordSongPlay('Sid Sriram', 'Samajavaragamana');
        await prefs.recordSongPlay(
          'Sid Sriram, Sunitha',
          'Inkem Inkem Inkem Kaavaale',
        );

        expect(prefs.mostPlayedArtist, equals('Sid Sriram'));
        expect(prefs.topArtistPlayCount, greaterThan(0));

        final topArtists = prefs.getTopPlayedArtists();
        expect(topArtists.first.key, equals('Sid Sriram'));
      },
    );

    test(
      'Top artist dynamically changes in real time when user streams another artist more',
      () async {
        // Start with Sid Sriram (1 play)
        await prefs.recordSongPlay('Sid Sriram', 'Samajavaragamana');
        expect(prefs.mostPlayedArtist, equals('Sid Sriram'));

        // User now plays 3 songs by Anirudh Ravichander
        await prefs.recordSongPlay('Anirudh Ravichander', 'Fear Song');
        await prefs.recordSongPlay(
          'Anirudh Ravichander, Shilpa Rao',
          'Chuttamalle',
        );
        await prefs.recordSongPlay('Anirudh', 'Arabic Kuthu');

        // Top Artist must dynamically flip to Anirudh Ravichander!
        expect(prefs.mostPlayedArtist, equals('Anirudh Ravichander'));
        expect(
          prefs.topArtistPlayCount,
          greaterThan(prefs.realPlaybackCounts['Sid Sriram'] ?? 0),
        );

        // User streams 5 songs by Arijit Singh
        for (int i = 0; i < 5; i++) {
          await prefs.recordSongPlay('Arijit Singh, Pritam', 'Kesariya $i');
        }

        // Top Artist must immediately flip to Arijit Singh!
        expect(prefs.mostPlayedArtist, equals('Arijit Singh'));
        expect(
          prefs.topArtistPlayCount,
          greaterThan(prefs.realPlaybackCounts['Anirudh Ravichander'] ?? 0),
        );
      },
    );

    test(
      'Filters out record label channel names and credits the genuine artist',
      () async {
        // YouTube video with record label channel "Aditya Music", artist in title
        await prefs.recordSongPlay(
          'Aditya Music',
          'Pushpa 2 - The Couple Song | Devi Sri Prasad | Shreya Ghoshal',
        );

        expect(prefs.mostPlayedArtist, isNot(equals('Aditya Music')));
        expect(prefs.realPlaybackCounts.containsKey('Aditya Music'), isFalse);
        expect(
          prefs.mostPlayedArtist,
          anyOf([equals('Devi Sri Prasad'), equals('Shreya Ghoshal')]),
        );
      },
    );

    test(
      'getTopPlayedArtists returns ranked list descending by stream count',
      () async {
        await prefs.recordSongPlay('Devi Sri Prasad', 'Pushpa Pushpa');
        await prefs.recordSongPlay('Devi Sri Prasad', 'Oo Antava');
        await prefs.recordSongPlay('Devi Sri Prasad', 'Srivalli');
        await prefs.recordSongPlay('Anirudh Ravichander', 'Hukum');

        final topList = prefs.getTopPlayedArtists(limit: 3);
        expect(topList.isNotEmpty, isTrue);
        expect(topList.first.key, equals('Devi Sri Prasad'));
        expect(topList.first.value, greaterThan(topList[1].value));
      },
    );
  });
}

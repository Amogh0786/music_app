import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:music_app/services/preferences_service.dart';
import 'package:music_app/services/studio_search_service.dart';
import 'package:music_app/services/dynamic_artist_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PreferencesService().init();
  });

  group('StudioSearchService Tests', () {
    test('StudioSearchService singleton initializes properly', () {
      final s1 = StudioSearchService();
      final s2 = StudioSearchService();
      expect(identical(s1, s2), isTrue);
    });

    test('searchSongs returns empty list on empty query', () async {
      final results = await StudioSearchService().searchSongs('   ');
      expect(results, isEmpty);
    });
  });

  group('Google/YouTube Taste Seeding Tests', () {
    test(
      'seedTasteFromYouTube populates artist counts and updates top artist',
      () async {
        final prefs = PreferencesService();

        final likedSongs = [
          Video(
            VideoId('dQw4w9WgXcQ'),
            'Kesariya',
            'Arijit Singh, Pritam',
            ChannelId('UC0WP5P-fwGlLyO4yOE76T8g'),
            DateTime.now(),
            '',
            null,
            '',
            const Duration(minutes: 4),
            ThumbnailSet('dQw4w9WgXcQ'),
            null,
            Engagement(0, null, null),
            false,
          ),
          Video(
            VideoId('9bZkp7q19f0'),
            'Apna Bana Le',
            'Arijit Singh, Sachin-Jigar',
            ChannelId('UC0WP5P-fwGlLyO4yOE76T8g'),
            DateTime.now(),
            '',
            null,
            '',
            const Duration(minutes: 3),
            ThumbnailSet('9bZkp7q19f0'),
            null,
            Engagement(0, null, null),
            false,
          ),
        ];

        final playlistSongs = [
          Video(
            VideoId('kJQP7kiw5Fk'),
            'Samajavaragamana',
            'Sid Sriram, Thaman S',
            ChannelId('UC0WP5P-fwGlLyO4yOE76T8g'),
            DateTime.now(),
            '',
            null,
            '',
            const Duration(minutes: 4),
            ThumbnailSet('kJQP7kiw5Fk'),
            null,
            Engagement(0, null, null),
            false,
          ),
        ];

        await prefs.seedTasteFromYouTube(
          likedSongs: likedSongs,
          playlistSongs: playlistSongs,
        );

        final topArtists = prefs.getTopPlayedArtists(limit: 10);
        expect(topArtists.isNotEmpty, isTrue);

        // Arijit Singh was in 2 liked songs (+5 each = +10), should be top artist
        expect(prefs.mostPlayedArtist.toLowerCase(), contains('arijit'));

        // Check dynamic artists includes seeded taste
        final dynamicArtists = DynamicArtistService().getDynamicArtists();
        expect(dynamicArtists.isNotEmpty, isTrue);
      },
    );
  });
}

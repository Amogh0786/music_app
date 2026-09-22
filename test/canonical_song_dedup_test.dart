import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/services/canonical_song_dedup.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

void main() {
  group('CanonicalSongDedup Tests', () {
    test('Cleans noisy YouTube titles accurately', () {
      const noisyTitle1 = 'Kesariya - Brahmāstra | Ranbir | Alia | Pritam | Arijit Singh | Full Song 4K';
      final clean1 = CanonicalSongDedup.cleanTitle(noisyTitle1);
      expect(clean1, equals('kesariya'));

      const noisyTitle2 = 'Tum Hi Ho (Official Video) [4K] - Aashiqui 2';
      final clean2 = CanonicalSongDedup.cleanTitle(noisyTitle2);
      expect(clean2, equals('tum hi ho'));

      const cleanJioTitle = 'Kesariya';
      final cleanJio = CanonicalSongDedup.cleanTitle(cleanJioTitle);
      expect(cleanJio, equals('kesariya'));
    });

    test('Detects duplicate songs across JioSaavn and YouTube', () {
      final isDup = CanonicalSongDedup.areDuplicateSongs(
        titleA: 'Kesariya',
        artistA: 'Pritam, Arijit Singh',
        titleB: 'Kesariya - Brahmāstra | Ranbir | Alia | Pritam | Arijit Singh | Full Song 4K',
        artistB: 'Sony Music India',
      );
      expect(isDup, isTrue);

      final isNotDup = CanonicalSongDedup.areDuplicateSongs(
        titleA: 'Kesariya',
        artistA: 'Arijit Singh',
        titleB: 'Channa Mereya',
        artistB: 'Arijit Singh',
      );
      expect(isNotDup, isFalse);
    });

    test('Deduplicates a mixed list of JioSaavn and YouTube songs', () {
      final jioSong = Video(
        VideoId('rjkrTnma000'),
        'Kesariya',
        'Pritam, Arijit Singh',
        ChannelId('UC0WP5P-fwGlLyO4yOE76T8g'),
        DateTime.now(),
        '',
        null,
        '',
        const Duration(minutes: 4),
        ThumbnailSet('rjkrTnma000'),
        null,
        Engagement(0, null, null),
        false,
      );

      final ytDupSong = Video(
        VideoId('BddP6PYo2gs'),
        'Kesariya - Brahmāstra | Ranbir | Alia | Pritam | Arijit Singh | Full Song 4K',
        'Sony Music India',
        ChannelId('UC0WP5P-fwGlLyO4yOE76T8g'),
        DateTime.now(),
        '',
        null,
        '',
        const Duration(minutes: 4, seconds: 28),
        ThumbnailSet('BddP6PYo2gs'),
        null,
        Engagement(0, null, null),
        false,
      );

      final distinctYtSong = Video(
        VideoId('ElZfdU54Cp8'),
        'Apna Bana Le',
        'Arijit Singh',
        ChannelId('UC0WP5P-fwGlLyO4yOE76T8g'),
        DateTime.now(),
        '',
        null,
        '',
        const Duration(minutes: 4, seconds: 20),
        ThumbnailSet('ElZfdU54Cp8'),
        null,
        Engagement(0, null, null),
        false,
      );

      final deduped = CanonicalSongDedup.deduplicateList(
        [jioSong],
        [ytDupSong, distinctYtSong],
      );

      expect(deduped.length, equals(1));
      expect(deduped.first.id.value, equals('ElZfdU54Cp8'));
    });

    test('Balances artist distribution across the queue', () {
      Video makeSong(String id, String artist) => Video(
            VideoId(id.padRight(11, '0')),
            'Track $id',
            artist,
            ChannelId('UC0WP5P-fwGlLyO4yOE76T8g'),
            DateTime.now(),
            '',
            null,
            '',
            const Duration(minutes: 3),
            ThumbnailSet(id.padRight(11, '0')),
            null,
            Engagement(0, null, null),
            false,
          );

      final clustered = [
        makeSong('1', 'Arijit Singh'),
        makeSong('2', 'Arijit Singh'),
        makeSong('3', 'Arijit Singh'),
        makeSong('4', 'Anirudh'),
        makeSong('5', 'Anirudh'),
        makeSong('6', 'Diljit'),
      ];

      final balanced = CanonicalSongDedup.balanceArtistDistribution(clustered);
      expect(balanced.length, equals(6));
      // First song is Arijit, second should NOT be Arijit!
      expect(balanced[0].author, equals('Arijit Singh'));
      expect(balanced[1].author, isNot(equals('Arijit Singh')));
    });
  });
}

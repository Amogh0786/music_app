import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/services/playlist_artist_filter.dart';

void main() {
  group('PlaylistArtistFilter Tests', () {
    final sampleSongs = <Map<String, dynamic>>[
      {
        'id': 'song_1',
        'title': 'Chuttamalle',
        'author': 'Anirudh Ravichander, Shilpa Rao',
      },
      {
        'id': 'song_2',
        'title': 'Fear Song',
        'author': 'Anirudh Ravichander',
      },
      {
        'id': 'song_3',
        'title': 'Samajavaragamana',
        'author': 'Sid Sriram',
      },
      {
        'id': 'song_4',
        'title': 'Srivalli',
        'author': 'Sid Sriram, Devi Sri Prasad',
      },
      {
        'id': 'song_5',
        'title': 'Inside Out',
        'author': 'The Chainsmokers',
      },
      {
        'id': 'song_6',
        'title': 'Pushpa Pushpa | Allu Arjun | Devi Sri Prasad',
        'author': 'Aditya Music', // Record label channel
      },
      {
        'id': 'song_7',
        'title': 'Kesariya',
        'author': 'Arijit Singh, Pritam',
      },
    ];

    test('Identifies and normalizes artist names ignoring punctuation', () {
      expect(PlaylistArtistFilter.isArtistMatch('ar rahman', 'A.R. Rahman'), isTrue);
      expect(PlaylistArtistFilter.isArtistMatch('a r rahman', 'A.R. Rahman'), isTrue);
      expect(PlaylistArtistFilter.isArtistMatch('rahman', 'A.R. Rahman'), isTrue);
    });

    test('Supports popular Indian music artist aliases', () {
      expect(PlaylistArtistFilter.isArtistMatch('dsp', 'Devi Sri Prasad'), isTrue);
      expect(PlaylistArtistFilter.isArtistMatch('devi sri prasad', 'DSP'), isTrue);
      expect(PlaylistArtistFilter.isArtistMatch('anirudh', 'Anirudh Ravichander'), isTrue);
      expect(PlaylistArtistFilter.isArtistMatch('spb', 'S. P. Balasubrahmanyam'), isTrue);
    });

    test('Searches by artist name and returns ONLY songs of that particular artist', () {
      // Searching "Anirudh" should return song_1 and song_2
      final resultAnirudh = PlaylistArtistFilter.searchPlaylist(
        songs: sampleSongs,
        query: 'Anirudh',
      );

      expect(resultAnirudh.isArtistSearch, isTrue);
      expect(resultAnirudh.matchedIndices, equals([0, 1]));
      final matchedIds = resultAnirudh.matchedIndices.map((i) => sampleSongs[i]['id']).toList();
      expect(matchedIds, equals(['song_1', 'song_2']));
    });

    test('Matches collaborating artists accurately', () {
      // Shilpa Rao is a collaborator on Chuttamalle
      final resultShilpa = PlaylistArtistFilter.searchPlaylist(
        songs: sampleSongs,
        query: 'Shilpa Rao',
      );

      expect(resultShilpa.isArtistSearch, isTrue);
      expect(resultShilpa.matchedIndices, equals([0]));
      expect(sampleSongs[resultShilpa.matchedIndices.first]['id'], equals('song_1'));
    });

    test('Short artist query does NOT falsely match substrings in unrelated titles', () {
      // Query "Sid" should match Sid Sriram songs (song_3, song_4)
      // but should NOT match "Inside Out" (song_5)
      final resultSid = PlaylistArtistFilter.searchPlaylist(
        songs: sampleSongs,
        query: 'Sid',
      );

      expect(resultSid.isArtistSearch, isTrue);
      final matchedIds = resultSid.matchedIndices.map((i) => sampleSongs[i]['id']).toList();
      expect(matchedIds, containsAll(['song_3', 'song_4']));
      expect(matchedIds, isNot(contains('song_5'))); // Inside Out must NOT be returned!
    });

    test('Extracts artist from YouTube title when author is a record label channel', () {
      // Song 6 author is "Aditya Music", but title contains "Devi Sri Prasad"
      final resultDsp = PlaylistArtistFilter.searchPlaylist(
        songs: sampleSongs,
        query: 'DSP',
      );

      expect(resultDsp.isArtistSearch, isTrue);
      final matchedIds = resultDsp.matchedIndices.map((i) => sampleSongs[i]['id']).toList();
      // Should match song_4 ("Devi Sri Prasad" in author) and song_6 ("Devi Sri Prasad" in title)
      expect(matchedIds, containsAll(['song_4', 'song_6']));
    });

    test('Returns empty matchedIndices when artist is not in playlist', () {
      final resultTaylor = PlaylistArtistFilter.searchPlaylist(
        songs: sampleSongs,
        query: 'Taylor Swift',
      );

      expect(resultTaylor.matchedIndices.isEmpty, isTrue);
    });

    test('Calculates top artists with song counts for fast filter chips', () {
      final topArtists = PlaylistArtistFilter.getTopArtistsWithCounts(sampleSongs);
      expect(topArtists.isNotEmpty, isTrue);

      final artistNames = topArtists.map((a) => a.name.toLowerCase()).toList();
      expect(artistNames, contains('anirudh ravichander'));
      expect(artistNames, contains('sid sriram'));
      expect(artistNames, contains('devi sri prasad'));
    });
  });
}

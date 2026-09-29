import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/services/music_service.dart';
import 'package:music_app/services/playlist_artist_filter.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Video makeVideo(String id, String title, String author) {
    return Video(
      VideoId(id),
      title,
      author,
      ChannelId('UC0WP5P-fwGlLyO4yOE76T8g'),
      DateTime.now(),
      '',
      null,
      '',
      null,
      ThumbnailSet(id),
      null,
      Engagement(0, null, null),
      false,
    );
  }

  group('Custom Playlist In-Playlist Search & Recommendation Tests', () {
    late MusicService musicService;

    setUp(() {
      musicService = MusicService();
      musicService.customPlaylists.clear();
      // Seed a test custom/imported playlist
      musicService.customPlaylists.add({
        'id': 'playlist_search_1',
        'name': 'Road Trip Telugu Hits',
        'songs': [
          {
            'id': 'aaaaaaaaaaa',
            'title': 'Chuttamalle',
            'author': 'Anirudh Ravichander, Shilpa Rao',
            'thumbnail': 'https://img.youtube.com/vi/aaaaaaaaaaa/hqdefault.jpg',
          },
          {
            'id': 'bbbbbbbbbbb',
            'title': 'Fear Song',
            'author': 'Anirudh Ravichander',
            'thumbnail': 'https://img.youtube.com/vi/bbbbbbbbbbb/hqdefault.jpg',
          },
          {
            'id': 'ccccccccccc',
            'title': 'Samajavaragamana',
            'author': 'Sid Sriram',
            'thumbnail': 'https://img.youtube.com/vi/ccccccccccc/hqdefault.jpg',
          },
        ],
      });
    });

    test('Filters in-playlist songs by title or artist query', () {
      final playlist = musicService.customPlaylists.first;
      final songs = List<Map<String, dynamic>>.from(playlist['songs']);

      // Search by title "Chuttamalle"
      const query1 = 'chuttam';
      final matches1 = songs.where((s) {
        final t = (s['title'] as String).toLowerCase();
        final a = (s['author'] as String).toLowerCase();
        return t.contains(query1) || a.contains(query1);
      }).toList();

      expect(matches1.length, equals(1));
      expect(matches1.first['id'], equals('aaaaaaaaaaa'));

      // Search by artist "Anirudh"
      const query2 = 'anirudh';
      final matches2 = songs.where((s) {
        final t = (s['title'] as String).toLowerCase();
        final a = (s['author'] as String).toLowerCase();
        return t.contains(query2) || a.contains(query2);
      }).toList();

      expect(matches2.length, equals(2));
      expect(
        matches2.map((s) => s['id']),
        containsAll(['aaaaaaaaaaa', 'bbbbbbbbbbb']),
      );
    });

    test('Identifies when searched song is absent from playlist', () {
      final playlist = musicService.customPlaylists.first;
      final songs = List<Map<String, dynamic>>.from(playlist['songs']);

      const missingQuery = 'Kesariya';
      final matches = songs.where((s) {
        final t = (s['title'] as String).toLowerCase();
        final a = (s['author'] as String).toLowerCase();
        return t.contains(missingQuery.toLowerCase()) ||
            a.contains(missingQuery.toLowerCase());
      }).toList();

      // Confirms song is absent from playlist
      expect(matches.isEmpty, isTrue);
    });

    test('Adding recommended song dynamically includes it in the playlist', () {
      final recommendedVideo = makeVideo(
        'ddddddddddd',
        'Kesariya',
        'Arijit Singh, Pritam',
      );

      // Add to playlist
      musicService.addSongToPlaylist('playlist_search_1', recommendedVideo);

      final updatedPlaylist = musicService.customPlaylists.first;
      final updatedSongs = List<Map<String, dynamic>>.from(
        updatedPlaylist['songs'],
      );

      expect(updatedSongs.length, equals(4));
      expect(updatedSongs.last['id'], equals('ddddddddddd'));
      expect(updatedSongs.last['title'], equals('Kesariya'));
      expect(updatedSongs.last['author'], equals('Arijit Singh, Pritam'));

      // Now searching "Kesariya" matches in the playlist!
      final newMatches = updatedSongs.where((s) {
        return (s['title'] as String).toLowerCase().contains('kesariya');
      }).toList();

      expect(newMatches.length, equals(1));
      expect(newMatches.first['id'], equals('ddddddddddd'));
    });

    test('Avoids adding duplicate songs to the playlist', () {
      final duplicateVideo = makeVideo(
        'aaaaaaaaaaa',
        'Chuttamalle',
        'Anirudh Ravichander',
      );

      // Try adding duplicate
      musicService.addSongToPlaylist('playlist_search_1', duplicateVideo);

      final playlist = musicService.customPlaylists.first;
      final songs = List<Map<String, dynamic>>.from(playlist['songs']);

      // Count of aaaaaaaaaaa should still be exactly 1
      final count = songs.where((s) => s['id'] == 'aaaaaaaaaaa').length;
      expect(count, equals(1));
      expect(songs.length, equals(3));
    });

    test(
      'PlaylistArtistFilter returns only songs of the particular artist searched in the playlist',
      () {
        final playlist = musicService.customPlaylists.first;
        final songs = List<Map<String, dynamic>>.from(playlist['songs']);

        // Searching for Sid Sriram should only return Sid Sriram's song, not Anirudh's
        final sidResult = PlaylistArtistFilter.searchPlaylist(
          songs: songs,
          query: 'Sid Sriram',
        );
        expect(sidResult.isArtistSearch, isTrue);
        expect(sidResult.matchedArtist, equals('Sid Sriram'));
        expect(sidResult.matchedIndices.length, equals(1));
        expect(
          songs[sidResult.matchedIndices.first]['id'],
          equals('ccccccccccc'),
        );

        // Searching for Anirudh should return both of Anirudh's songs, and none of Sid's
        final anirudhResult = PlaylistArtistFilter.searchPlaylist(
          songs: songs,
          query: 'Anirudh',
        );
        expect(anirudhResult.isArtistSearch, isTrue);
        expect(anirudhResult.matchedIndices.length, equals(2));
        final ids = anirudhResult.matchedIndices
            .map((i) => songs[i]['id'])
            .toList();
        expect(ids, equals(['aaaaaaaaaaa', 'bbbbbbbbbbb']));
      },
    );
  });
}

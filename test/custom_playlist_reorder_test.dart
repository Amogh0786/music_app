import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/services/music_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Custom Playlist Reordering & Song Removal Tests', () {
    late MusicService musicService;

    setUp(() {
      musicService = MusicService();
      musicService.customPlaylists.clear();
      // Seed a test playlist
      musicService.customPlaylists.add({
        'id': 'test_playlist_1',
        'name': 'My Telugu Favorites',
        'songs': [
          {'id': 'song_1', 'title': 'Samajavaragamana', 'author': 'Sid Sriram'},
          {'id': 'song_2', 'title': 'Butta Bomma', 'author': 'Armaan Malik'},
          {'id': 'song_3', 'title': 'Ramuloo Ramulaa', 'author': 'Anurag Kulkarni'},
          {'id': 'song_4', 'title': 'Inkem Inkem', 'author': 'Sid Sriram'},
        ],
      });
    });

    test('reorderPlaylistSongs moves an item forward properly', () {
      // Move 'Samajavaragamana' (index 0) to after 'Butta Bomma' (newIndex: 2 in ReorderableListView)
      musicService.reorderPlaylistSongs('test_playlist_1', 0, 2);

      final songs = List<Map<String, dynamic>>.from(musicService.customPlaylists.first['songs']);
      expect(songs[0]['id'], equals('song_2'));
      expect(songs[1]['id'], equals('song_1'));
      expect(songs[2]['id'], equals('song_3'));
      expect(songs[3]['id'], equals('song_4'));
    });

    test('reorderPlaylistSongs moves an item backward properly', () {
      // Move 'Ramuloo Ramulaa' (index 2) to first position (newIndex: 0)
      musicService.reorderPlaylistSongs('test_playlist_1', 2, 0);

      final songs = List<Map<String, dynamic>>.from(musicService.customPlaylists.first['songs']);
      expect(songs[0]['id'], equals('song_3'));
      expect(songs[1]['id'], equals('song_1'));
      expect(songs[2]['id'], equals('song_2'));
      expect(songs[3]['id'], equals('song_4'));
    });

    test('reorderPlaylistSongs handles out of bounds safely', () {
      // Out of bounds should safely no-op
      musicService.reorderPlaylistSongs('test_playlist_1', -1, 5);
      final songs = List<Map<String, dynamic>>.from(musicService.customPlaylists.first['songs']);
      expect(songs.length, equals(4));
    });

    test('removeSongFromPlaylist removes specific song by id', () {
      musicService.removeSongFromPlaylist('test_playlist_1', 'song_2');

      final songs = List<Map<String, dynamic>>.from(musicService.customPlaylists.first['songs']);
      expect(songs.length, equals(3));
      expect(songs.any((s) => s['id'] == 'song_2'), isFalse);
      expect(songs[0]['id'], equals('song_1'));
      expect(songs[1]['id'], equals('song_3'));
    });
  });
}

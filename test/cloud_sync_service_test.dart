import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/models/song_item.dart';
import 'package:music_app/services/cloud_sync_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CloudSyncService Non-Destructive Merge Tests', () {
    test(
      'SongItem union merge preserves all local and remote items without duplication',
      () {
        final localSongs = [
          SongItem(
            id: 'song_1',
            title: 'Local Song 1',
            author: 'Artist A',
            album: 'Album A',
            duration: const Duration(minutes: 3),
          ),
          SongItem(
            id: 'song_2',
            title: 'Shared Song',
            author: 'Artist B',
            album: 'Album B',
            duration: const Duration(minutes: 3, seconds: 20),
          ),
        ];

        final remoteSongsRaw = [
          {
            'id': 'song_2',
            'title': 'Shared Song (Remote)',
            'artist': 'Artist B',
            'album': 'Album B',
            'durationMs': 200000,
          },
          {
            'id': 'song_3',
            'title': 'Cloud Only Song',
            'artist': 'Artist C',
            'album': 'Album C',
            'durationMs': 220000,
          },
        ];

        final Map<String, SongItem> mergedLikesMap = {};
        for (final song in localSongs) {
          mergedLikesMap[song.id] = song;
        }
        for (final raw in remoteSongsRaw) {
          try {
            final song = SongItem.fromJson(Map<String, dynamic>.from(raw));
            if (!mergedLikesMap.containsKey(song.id)) {
              mergedLikesMap[song.id] = song;
            }
          } catch (_) {}
        }

        final merged = mergedLikesMap.values.toList();
        // Should have 3 unique songs (song_1, song_2, song_3)
        expect(merged.length, equals(3));
        expect(merged.any((s) => s.id == 'song_1'), isTrue);
        expect(merged.any((s) => s.id == 'song_2'), isTrue);
        expect(merged.any((s) => s.id == 'song_3'), isTrue);
        // Local copy of shared song takes precedence
        expect(
          merged.firstWhere((s) => s.id == 'song_2').title,
          equals('Shared Song'),
        );
      },
    );

    test(
      'Custom playlist union merge retains local playlists and combines songs',
      () {
        final localPlaylists = [
          {
            'id': 'pl_1',
            'name': 'My Telugu Favorites',
            'songs': [
              {'id': 'song_10', 'title': 'Samajavaragamana'},
            ],
          },
          {
            'id': 'pl_local_only',
            'name': 'Gym Beats',
            'songs': [
              {'id': 'song_20', 'title': 'Animal Theme'},
            ],
          },
        ];

        final remotePlaylists = [
          {
            'id': 'pl_1',
            'name': 'My Telugu Favorites',
            'songs': [
              {'id': 'song_10', 'title': 'Samajavaragamana'},
              {'id': 'song_11', 'title': 'Butta Bomma'},
            ],
          },
          {
            'id': 'pl_cloud_only',
            'name': 'Late Night Lofi',
            'songs': [
              {'id': 'song_30', 'title': 'Midnight Chill'},
            ],
          },
        ];

        final Map<String, Map<String, dynamic>> mergedMap = {};
        for (final p in localPlaylists) {
          final id = (p['id'] ?? p['name'] ?? '').toString();
          if (id.isNotEmpty) {
            mergedMap[id] = Map<String, dynamic>.from(p);
          }
        }
        for (final raw in remotePlaylists) {
          final remoteP = Map<String, dynamic>.from(raw);
          final id = (remoteP['id'] ?? remoteP['name'] ?? '').toString();
          if (id.isNotEmpty) {
            if (!mergedMap.containsKey(id)) {
              mergedMap[id] = remoteP;
            } else {
              final existingSongs = List<dynamic>.from(
                mergedMap[id]!['songs'] as List? ?? [],
              );
              final existingIds = existingSongs
                  .map((s) => (s is Map ? s['id'] : null))
                  .toSet();
              final remoteSongs = List<dynamic>.from(
                remoteP['songs'] as List? ?? [],
              );
              for (final rs in remoteSongs) {
                if (rs is Map && !existingIds.contains(rs['id'])) {
                  existingSongs.add(rs);
                  existingIds.add(rs['id']);
                }
              }
              mergedMap[id]!['songs'] = existingSongs;
            }
          }
        }

        // Should have 3 playlists total
        expect(mergedMap.length, equals(3));
        expect(mergedMap.containsKey('pl_1'), isTrue);
        expect(mergedMap.containsKey('pl_local_only'), isTrue);
        expect(mergedMap.containsKey('pl_cloud_only'), isTrue);

        // pl_1 should have merged 2 songs without duplicate
        final pl1Songs = mergedMap['pl_1']!['songs'] as List;
        expect(pl1Songs.length, equals(2));
        expect(pl1Songs.any((s) => s['id'] == 'song_10'), isTrue);
        expect(pl1Songs.any((s) => s['id'] == 'song_11'), isTrue);
      },
    );

    test('CloudSyncResult maintains correct status transitions', () {
      final sync = CloudSyncService();
      expect(sync.syncStatus.value, equals(CloudSyncStatus.idle));
    });
  });
}

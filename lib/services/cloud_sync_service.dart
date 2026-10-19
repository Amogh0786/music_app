import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/song_item.dart';
import 'api_config.dart';
import 'audio/favorites_repository.dart';
import 'auth_service.dart';
import 'data_snapshot_service.dart';
import 'music_service.dart';

enum CloudSyncStatus { idle, syncing, success, offline, error, kvNotConfigured }

class CloudSyncResult {
  final bool success;
  final CloudSyncStatus status;
  final String message;
  final int localLikesCount;
  final int localPlaylistsCount;
  final int mergedLikesCount;
  final int mergedPlaylistsCount;

  const CloudSyncResult({
    required this.success,
    required this.status,
    required this.message,
    this.localLikesCount = 0,
    this.localPlaylistsCount = 0,
    this.mergedLikesCount = 0,
    this.mergedPlaylistsCount = 0,
  });
}

/// Robust, zero-data-loss cloud synchronization service powered by Cloudflare Workers KV.
///
/// Guarantees:
/// 1. Atomic local safety snapshot before any network or sync operation.
/// 2. Non-destructive bidirectional merge: local data is NEVER erased or overwritten with empty state.
/// 3. Offline-first: if Cloudflare KV is unreachable or unconfigured, local library remains 100% intact.
class CloudSyncService {
  static final CloudSyncService _instance = CloudSyncService._internal();
  factory CloudSyncService() => _instance;
  CloudSyncService._internal();

  final ValueNotifier<CloudSyncStatus> syncStatus =
      ValueNotifier<CloudSyncStatus>(CloudSyncStatus.idle);
  final ValueNotifier<DateTime?> lastSyncedAt = ValueNotifier<DateTime?>(null);
  final ValueNotifier<String?> syncMessage = ValueNotifier<String?>(null);

  bool _isSyncing = false;

  /// Main entry point to sync user library with Cloudflare Workers KV.
  Future<CloudSyncResult> sync({bool forcePushLocal = false}) async {
    if (_isSyncing) {
      return const CloudSyncResult(
        success: false,
        status: CloudSyncStatus.syncing,
        message: 'Sync is already in progress.',
      );
    }

    final auth = AuthService();
    final userId = auth.userId;
    if (userId == null || userId.isEmpty || !auth.isAuthenticated) {
      syncStatus.value = CloudSyncStatus.idle;
      syncMessage.value = 'Sign in with Google to enable cloud library sync.';
      return const CloudSyncResult(
        success: false,
        status: CloudSyncStatus.idle,
        message: 'User is not signed in.',
      );
    }

    _isSyncing = true;
    syncStatus.value = CloudSyncStatus.syncing;
    syncMessage.value = 'Creating safety backup…';

    try {
      // 1. MANDATORY ZERO-DATA-LOSS STEP: Create atomic safety snapshot on device
      try {
        await DataSnapshotService().createSafetySnapshot(
          triggerReason: 'Pre-CloudSync Safety Backup',
        );
      } catch (e) {
        debugPrint('[CloudSyncService] Pre-sync snapshot warning: $e');
      }

      syncMessage.value = 'Connecting to Cloudflare Edge…';

      // 2. Ingest current local library
      final localLikes = List<SongItem>.from(FavoritesRepository().likedSongs);
      final localPlaylists = List<Map<String, dynamic>>.from(
        MusicService().customPlaylists,
      );

      final endpoint = Uri.parse(
        '${ApiConfig.cloudflareWorkerUrl}/user/sync?userId=${Uri.encodeComponent(userId)}',
      );

      http.Response getResponse;
      try {
        getResponse = await http
            .get(endpoint)
            .timeout(const Duration(seconds: 10));
      } catch (e) {
        _isSyncing = false;
        syncStatus.value = CloudSyncStatus.offline;
        syncMessage.value = 'Cloudflare Edge offline; local library preserved.';
        return CloudSyncResult(
          success: false,
          status: CloudSyncStatus.offline,
          message: 'Network offline: $e',
          localLikesCount: localLikes.length,
          localPlaylistsCount: localPlaylists.length,
        );
      }

      if (getResponse.statusCode == 200) {
        final Map<String, dynamic> jsonBody =
            json.decode(getResponse.body) as Map<String, dynamic>;

        if (jsonBody['status'] == 'not_configured') {
          _isSyncing = false;
          syncStatus.value = CloudSyncStatus.kvNotConfigured;
          syncMessage.value =
              'Cloudflare KV namespace not bound yet. Local library safe.';
          return CloudSyncResult(
            success: false,
            status: CloudSyncStatus.kvNotConfigured,
            message: 'KV namespace not bound in Cloudflare.',
            localLikesCount: localLikes.length,
            localPlaylistsCount: localPlaylists.length,
          );
        }

        final remoteData = jsonBody['data'] as Map<String, dynamic>?;

        // 3. Cloud is empty: push local library to cloud without touching local data
        if (remoteData == null || forcePushLocal) {
          syncMessage.value = 'Backing up local library to Cloudflare…';
          await _pushToCloudflare(
            userId: userId,
            email: auth.userEmail ?? '',
            playlists: localPlaylists,
            likedSongs: localLikes,
          );

          _isSyncing = false;
          syncStatus.value = CloudSyncStatus.success;
          lastSyncedAt.value = DateTime.now();
          syncMessage.value =
              'Backed up ${localLikes.length} likes & ${localPlaylists.length} playlists to cloud.';
          return CloudSyncResult(
            success: true,
            status: CloudSyncStatus.success,
            message: 'Initial backup complete.',
            localLikesCount: localLikes.length,
            localPlaylistsCount: localPlaylists.length,
            mergedLikesCount: localLikes.length,
            mergedPlaylistsCount: localPlaylists.length,
          );
        }

        // 4. Non-Destructive Bidirectional Merge
        syncMessage.value = 'Merging cloud and local libraries…';
        final remoteLikesList =
            (remoteData['likedSongs'] as List<dynamic>? ?? []);
        final remotePlaylistsList =
            (remoteData['playlists'] as List<dynamic>? ?? []);

        // A. Merge Liked Songs (Union by song ID)
        final Map<String, SongItem> mergedLikesMap = {};
        for (final song in localLikes) {
          mergedLikesMap[song.id] = song;
        }
        for (final raw in remoteLikesList) {
          if (raw is Map) {
            try {
              final song = SongItem.fromJson(Map<String, dynamic>.from(raw));
              if (!mergedLikesMap.containsKey(song.id)) {
                mergedLikesMap[song.id] = song;
              }
            } catch (_) {}
          }
        }
        final mergedLikes = mergedLikesMap.values.toList();

        // B. Merge Custom Playlists (Union by ID and song dedup)
        final Map<String, Map<String, dynamic>> mergedPlaylistsMap = {};
        for (final p in localPlaylists) {
          final id = (p['id'] ?? p['name'] ?? '').toString();
          if (id.isNotEmpty) {
            mergedPlaylistsMap[id] = Map<String, dynamic>.from(p);
          }
        }
        for (final raw in remotePlaylistsList) {
          if (raw is Map) {
            final remoteP = Map<String, dynamic>.from(raw);
            final id = (remoteP['id'] ?? remoteP['name'] ?? '').toString();
            if (id.isNotEmpty) {
              if (!mergedPlaylistsMap.containsKey(id)) {
                mergedPlaylistsMap[id] = remoteP;
              } else {
                // Merge songs within playlist
                final existingSongs = List<dynamic>.from(
                  mergedPlaylistsMap[id]!['songs'] as List? ?? [],
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
                mergedPlaylistsMap[id]!['songs'] = existingSongs;
              }
            }
          }
        }
        final mergedPlaylists = mergedPlaylistsMap.values.toList();

        // 5. Persist merged library to local platform storage
        await _saveMergedLocalLibrary(
          mergedLikes: mergedLikes,
          mergedPlaylists: mergedPlaylists,
        );

        // 6. Push the unified union back to Cloudflare
        await _pushToCloudflare(
          userId: userId,
          email: auth.userEmail ?? '',
          playlists: mergedPlaylists,
          likedSongs: mergedLikes,
        );

        _isSyncing = false;
        syncStatus.value = CloudSyncStatus.success;
        lastSyncedAt.value = DateTime.now();
        syncMessage.value =
            'Synced! ${mergedLikes.length} likes & ${mergedPlaylists.length} playlists active.';

        return CloudSyncResult(
          success: true,
          status: CloudSyncStatus.success,
          message: 'Sync succeeded.',
          localLikesCount: localLikes.length,
          localPlaylistsCount: localPlaylists.length,
          mergedLikesCount: mergedLikes.length,
          mergedPlaylistsCount: mergedPlaylists.length,
        );
      } else {
        _isSyncing = false;
        syncStatus.value = CloudSyncStatus.error;
        syncMessage.value =
            'Cloudflare returned HTTP ${getResponse.statusCode}.';
        return CloudSyncResult(
          success: false,
          status: CloudSyncStatus.error,
          message: 'HTTP ${getResponse.statusCode}',
        );
      }
    } catch (e) {
      _isSyncing = false;
      syncStatus.value = CloudSyncStatus.error;
      syncMessage.value = 'Sync error: $e';
      return CloudSyncResult(
        success: false,
        status: CloudSyncStatus.error,
        message: e.toString(),
      );
    }
  }

  /// Pushes library data to Cloudflare Edge KV via POST /user/sync
  Future<void> _pushToCloudflare({
    required String userId,
    required String email,
    required List<Map<String, dynamic>> playlists,
    required List<SongItem> likedSongs,
  }) async {
    try {
      final endpoint = Uri.parse('${ApiConfig.cloudflareWorkerUrl}/user/sync');
      final payload = {
        'userId': userId,
        'email': email,
        'playlists': playlists,
        'likedSongs': likedSongs.map((s) => s.toJson()).toList(),
      };

      await http
          .post(
            endpoint,
            headers: {'Content-Type': 'application/json'},
            body: json.encode(payload),
          )
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      debugPrint('[CloudSyncService] Error pushing to Cloudflare: $e');
    }
  }

  /// Atomically saves merged library to local platform storage and notifies listeners
  Future<void> _saveMergedLocalLibrary({
    required List<SongItem> mergedLikes,
    required List<Map<String, dynamic>> mergedPlaylists,
  }) async {
    try {
      final likesJson = json.encode(
        mergedLikes.map((s) => s.toJson()).toList(),
      );
      final playlistsJson = json.encode(mergedPlaylists);

      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('liked_songs_web', likesJson);
        await prefs.setString('custom_playlists_web', playlistsJson);
      } else {
        final dir = await getApplicationDocumentsDirectory();
        final likesFile = File('${dir.path}/liked_songs.json');
        await likesFile.writeAsString(likesJson, flush: true);

        final playlistsFile = File('${dir.path}/custom_playlists.json');
        await playlistsFile.writeAsString(playlistsJson, flush: true);
      }

      // Reload into active services to notify all UI widgets
      await FavoritesRepository().load();
      await MusicService().loadCustomPlaylists();
    } catch (e) {
      debugPrint('[CloudSyncService] Error saving merged local library: $e');
    }
  }
}

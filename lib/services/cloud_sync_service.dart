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
import 'canonical_song_dedup.dart';
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

/// Detailed set-theory comparison between local storage (L) and cloud storage (C).
class CloudSyncAnalysis {
  final bool isConfigured;
  final bool hasCloudData;
  final bool hasLocalData;
  final bool
  hasNewLocalItems; // (L \ C != ∅): local has items that cloud does not have
  final bool
  hasNewCloudItems; // (C \ L != ∅): cloud has items that local does not have
  final int localLikesCount;
  final int localPlaylistsCount;
  final int cloudLikesCount;
  final int cloudPlaylistsCount;
  final int newLocalLikesCount; // Count of likes in L not in C
  final int newLocalPlaylistsCount; // Count of playlists in L not in C
  final int newCloudLikesCount; // Count of likes in C not in L
  final int newCloudPlaylistsCount; // Count of playlists in C not in L

  const CloudSyncAnalysis({
    required this.isConfigured,
    required this.hasCloudData,
    required this.hasLocalData,
    required this.hasNewLocalItems,
    required this.hasNewCloudItems,
    required this.localLikesCount,
    required this.localPlaylistsCount,
    required this.cloudLikesCount,
    required this.cloudPlaylistsCount,
    required this.newLocalLikesCount,
    required this.newLocalPlaylistsCount,
    required this.newCloudLikesCount,
    required this.newCloudPlaylistsCount,
  });
}

/// Robust, zero-data-loss cloud synchronization service powered by Cloudflare Workers KV.
///
/// Guarantees:
/// 1. Atomic local safety snapshot before any network or sync operation.
/// 2. Non-destructive bidirectional merge with CanonicalSongDedup deduplication.
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

  /// Inspects and analyzes differences between current local library and remote cloud storage.
  /// Allows the UI to make informed decisions:
  /// - If local has no new items (L ⊆ C), avoid asking the user to back up again.
  /// - If cloud has items that local is missing (C \ L != ∅), auto-sync down silently.
  /// - Only prompt the user if there are actual unsaved local items (L \ C != ∅).
  Future<CloudSyncAnalysis> inspectSyncState() async {
    final auth = AuthService();
    final userId = auth.userId;
    final localLikes = List<SongItem>.from(FavoritesRepository().likedSongs);
    final localPlaylists = List<Map<String, dynamic>>.from(
      MusicService().customPlaylists,
    );

    if (userId == null || userId.isEmpty || !auth.isAuthenticated) {
      return CloudSyncAnalysis(
        isConfigured: false,
        hasCloudData: false,
        hasLocalData: localLikes.isNotEmpty || localPlaylists.isNotEmpty,
        hasNewLocalItems: false,
        hasNewCloudItems: false,
        localLikesCount: localLikes.length,
        localPlaylistsCount: localPlaylists.length,
        cloudLikesCount: 0,
        cloudPlaylistsCount: 0,
        newLocalLikesCount: 0,
        newLocalPlaylistsCount: 0,
        newCloudLikesCount: 0,
        newCloudPlaylistsCount: 0,
      );
    }

    try {
      final endpoint = Uri.parse(
        '${ApiConfig.cloudflareWorkerUrl}/user/sync?userId=${Uri.encodeComponent(userId)}',
      );
      final response = await http
          .get(endpoint)
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) {
        return CloudSyncAnalysis(
          isConfigured: false,
          hasCloudData: false,
          hasLocalData: localLikes.isNotEmpty || localPlaylists.isNotEmpty,
          hasNewLocalItems: false,
          hasNewCloudItems: false,
          localLikesCount: localLikes.length,
          localPlaylistsCount: localPlaylists.length,
          cloudLikesCount: 0,
          cloudPlaylistsCount: 0,
          newLocalLikesCount: 0,
          newLocalPlaylistsCount: 0,
          newCloudLikesCount: 0,
          newCloudPlaylistsCount: 0,
        );
      }

      final jsonBody = json.decode(response.body) as Map<String, dynamic>;
      if (jsonBody['status'] == 'not_configured') {
        return CloudSyncAnalysis(
          isConfigured: false,
          hasCloudData: false,
          hasLocalData: localLikes.isNotEmpty || localPlaylists.isNotEmpty,
          hasNewLocalItems: false,
          hasNewCloudItems: false,
          localLikesCount: localLikes.length,
          localPlaylistsCount: localPlaylists.length,
          cloudLikesCount: 0,
          cloudPlaylistsCount: 0,
          newLocalLikesCount: 0,
          newLocalPlaylistsCount: 0,
          newCloudLikesCount: 0,
          newCloudPlaylistsCount: 0,
        );
      }

      final remoteData = jsonBody['data'] as Map<String, dynamic>?;
      if (remoteData == null) {
        final hasLocal = localLikes.isNotEmpty || localPlaylists.isNotEmpty;
        return CloudSyncAnalysis(
          isConfigured: true,
          hasCloudData: false,
          hasLocalData: hasLocal,
          hasNewLocalItems: hasLocal,
          hasNewCloudItems: false,
          localLikesCount: localLikes.length,
          localPlaylistsCount: localPlaylists.length,
          cloudLikesCount: 0,
          cloudPlaylistsCount: 0,
          newLocalLikesCount: localLikes.length,
          newLocalPlaylistsCount: localPlaylists.length,
          newCloudLikesCount: 0,
          newCloudPlaylistsCount: 0,
        );
      }

      final remoteLikesList =
          (remoteData['likedSongs'] as List<dynamic>? ?? []);
      final remotePlaylistsList =
          (remoteData['playlists'] as List<dynamic>? ?? []);

      final List<SongItem> remoteLikes = [];
      for (final item in remoteLikesList) {
        if (item is Map) {
          try {
            remoteLikes.add(SongItem.fromJson(Map<String, dynamic>.from(item)));
          } catch (_) {}
        }
      }

      // Calculate Likes Difference L \ C
      int newLocalLikes = 0;
      for (final localSong in localLikes) {
        final existsInCloud = remoteLikes.any(
          (remoteSong) => _areSameSongs(localSong, remoteSong),
        );
        if (!existsInCloud) {
          newLocalLikes++;
        }
      }

      // Calculate Likes Difference C \ L
      int newCloudLikes = 0;
      for (final remoteSong in remoteLikes) {
        final existsInLocal = localLikes.any(
          (localSong) => _areSameSongs(localSong, remoteSong),
        );
        if (!existsInLocal) {
          newCloudLikes++;
        }
      }

      // Calculate Playlists Difference L \ C
      int newLocalPlaylists = 0;
      for (final localP in localPlaylists) {
        final matchingCloudP = remotePlaylistsList.cast<dynamic>().firstWhere(
          (p) => p is Map && _areSamePlaylists(localP, p),
          orElse: () => null,
        );

        if (matchingCloudP == null) {
          newLocalPlaylists++;
        } else {
          final localSongs = localP['songs'] as List? ?? [];
          final cloudSongs = matchingCloudP['songs'] as List? ?? [];
          final hasUnsyncedSongs = localSongs.any(
            (ls) =>
                ls is Map &&
                !cloudSongs.any((cs) => cs is Map && _areSameSongMaps(ls, cs)),
          );
          if (hasUnsyncedSongs) {
            newLocalPlaylists++;
          }
        }
      }

      int newCloudPlaylists = 0;
      for (final cloudP in remotePlaylistsList) {
        if (cloudP is! Map) continue;
        final matchingLocalP = localPlaylists.firstWhere(
          (p) => _areSamePlaylists(p, cloudP),
          orElse: () => <String, dynamic>{},
        );

        if (matchingLocalP.isEmpty) {
          newCloudPlaylists++;
        } else {
          final cloudSongs = cloudP['songs'] as List? ?? [];
          final localSongs = matchingLocalP['songs'] as List? ?? [];
          final hasMissingLocalSongs = cloudSongs.any(
            (cs) =>
                cs is Map &&
                !localSongs.any((ls) => ls is Map && _areSameSongMaps(cs, ls)),
          );
          if (hasMissingLocalSongs) {
            newCloudPlaylists++;
          }
        }
      }

      final hasCloud = remoteLikes.isNotEmpty || remotePlaylistsList.isNotEmpty;
      final hasLocal = localLikes.isNotEmpty || localPlaylists.isNotEmpty;

      return CloudSyncAnalysis(
        isConfigured: true,
        hasCloudData: hasCloud,
        hasLocalData: hasLocal,
        hasNewLocalItems: newLocalLikes > 0 || newLocalPlaylists > 0,
        hasNewCloudItems: newCloudLikes > 0 || newCloudPlaylists > 0,
        localLikesCount: localLikes.length,
        localPlaylistsCount: localPlaylists.length,
        cloudLikesCount: remoteLikes.length,
        cloudPlaylistsCount: remotePlaylistsList.length,
        newLocalLikesCount: newLocalLikes,
        newLocalPlaylistsCount: newLocalPlaylists,
        newCloudLikesCount: newCloudLikes,
        newCloudPlaylistsCount: newCloudPlaylists,
      );
    } catch (e) {
      debugPrint('[CloudSyncService] inspectSyncState error: $e');
      return CloudSyncAnalysis(
        isConfigured: false,
        hasCloudData: false,
        hasLocalData: localLikes.isNotEmpty || localPlaylists.isNotEmpty,
        hasNewLocalItems: false,
        hasNewCloudItems: false,
        localLikesCount: localLikes.length,
        localPlaylistsCount: localPlaylists.length,
        cloudLikesCount: 0,
        cloudPlaylistsCount: 0,
        newLocalLikesCount: 0,
        newLocalPlaylistsCount: 0,
        newCloudLikesCount: 0,
        newCloudPlaylistsCount: 0,
      );
    }
  }

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
        if (remoteData == null) {
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

        // 4. Non-Destructive Bidirectional Merge with Canonical Deduplication
        syncMessage.value = 'Merging cloud and local libraries…';
        final remoteLikesList =
            (remoteData['likedSongs'] as List<dynamic>? ?? []);
        final remotePlaylistsList =
            (remoteData['playlists'] as List<dynamic>? ?? []);

        // A. Merge Liked Songs (Union with zero duplicates)
        final List<SongItem> mergedLikes = [];
        for (final song in localLikes) {
          if (!mergedLikes.any((s) => _areSameSongs(s, song))) {
            mergedLikes.add(song);
          }
        }
        for (final raw in remoteLikesList) {
          if (raw is Map) {
            try {
              final song = SongItem.fromJson(Map<String, dynamic>.from(raw));
              if (!mergedLikes.any((s) => _areSameSongs(s, song))) {
                mergedLikes.add(song);
              }
            } catch (_) {}
          }
        }

        // B. Merge Custom Playlists (Union by ID / name & song dedup)
        final List<Map<String, dynamic>> mergedPlaylists = [];
        for (final p in localPlaylists) {
          final copy = Map<String, dynamic>.from(p);
          copy['songs'] = _dedupSongList(copy['songs'] as List? ?? []);
          mergedPlaylists.add(copy);
        }

        for (final raw in remotePlaylistsList) {
          if (raw is! Map) continue;
          final remoteP = Map<String, dynamic>.from(raw);
          final existingIdx = mergedPlaylists.indexWhere(
            (p) => _areSamePlaylists(p, remoteP),
          );

          if (existingIdx == -1) {
            final copy = Map<String, dynamic>.from(remoteP);
            copy['songs'] = _dedupSongList(copy['songs'] as List? ?? []);
            mergedPlaylists.add(copy);
          } else {
            final existingP = mergedPlaylists[existingIdx];
            final existingSongs = List<dynamic>.from(
              existingP['songs'] as List? ?? [],
            );
            final remoteSongs = List<dynamic>.from(
              remoteP['songs'] as List? ?? [],
            );
            for (final rs in remoteSongs) {
              if (rs is Map &&
                  !existingSongs.any(
                    (s) => s is Map && _areSameSongMaps(s, rs),
                  )) {
                existingSongs.add(rs);
              }
            }
            existingP['songs'] = _dedupSongList(existingSongs);
          }
        }

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
      await MusicService().loadLikedSongs();
      await MusicService().loadCustomPlaylists();
    } catch (e) {
      debugPrint('[CloudSyncService] Error saving merged local library: $e');
    }
  }

  static bool _areSameSongs(SongItem a, SongItem b) {
    final idA = a.id.trim();
    final idB = b.id.trim();
    if (idA.isNotEmpty && idA == idB) return true;
    return CanonicalSongDedup.areDuplicateSongs(
      titleA: a.title,
      artistA: a.author,
      titleB: b.title,
      artistB: b.author,
    );
  }

  static bool _areSameSongMaps(Map a, Map b) {
    final idA = (a['id'] ?? a['videoId'] ?? '').toString().trim();
    final idB = (b['id'] ?? b['videoId'] ?? '').toString().trim();
    if (idA.isNotEmpty && idA == idB) return true;

    final titleA = (a['title'] ?? '').toString().trim();
    final artistA = (a['author'] ?? a['artist'] ?? '').toString().trim();
    final titleB = (b['title'] ?? '').toString().trim();
    final artistB = (b['author'] ?? b['artist'] ?? '').toString().trim();

    if (titleA.isEmpty || titleB.isEmpty) return false;

    return CanonicalSongDedup.areDuplicateSongs(
      titleA: titleA,
      artistA: artistA,
      titleB: titleB,
      artistB: artistB,
    );
  }

  static bool _areSamePlaylists(Map a, Map b) {
    final idA = (a['id'] ?? '').toString().trim();
    final idB = (b['id'] ?? '').toString().trim();
    if (idA.isNotEmpty && idA == idB) return true;

    final nameA = (a['name'] ?? '').toString().trim().toLowerCase();
    final nameB = (b['name'] ?? '').toString().trim().toLowerCase();
    if (nameA.isNotEmpty && nameA == nameB) return true;

    return false;
  }

  static List<Map<String, dynamic>> _dedupSongList(List rawList) {
    final List<Map<String, dynamic>> deduped = [];
    for (final item in rawList) {
      if (item is! Map) continue;
      final songMap = Map<String, dynamic>.from(item);
      final isDup = deduped.any(
        (existing) => _areSameSongMaps(existing, songMap),
      );
      if (!isDup) {
        deduped.add(songMap);
      }
    }
    return deduped;
  }
}

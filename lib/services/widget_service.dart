import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import 'music_service.dart';
import 'audio_handler.dart';
import '../screens/custom_playlist_screen.dart';
import '../screens/player_screen.dart';

/// Background entry point invoked by HomeWidget when interactive widget controls are tapped
/// even when the application process is dead or in the background.
@pragma('vm:entry-point')
Future<void> homeWidgetBackgroundCallback(Uri? uri) async {
  WidgetsFlutterBinding.ensureInitialized();
  if (uri == null) return;
  debugPrint('[WidgetService] Background callback triggered with URI: $uri');
  await WidgetService.handleBackgroundUri(uri);
}

class WidgetService {
  static final WidgetService _instance = WidgetService._internal();
  factory WidgetService() => _instance;
  WidgetService._internal();

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  final MusicService _musicService = MusicService();
  StreamSubscription<Uri?>? _widgetClickedSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  bool _isInitialized = false;
  String? _lastCachedArtworkUrl;
  String? _lastCachedArtworkPath;
  int _lastProgressSynced = -1;
  DateTime _lastProgressSyncTime = DateTime.fromMillisecondsSinceEpoch(0);

  Uri? _pendingLaunchUri;
  Uri? get pendingLaunchUri => _pendingLaunchUri;

  /// Initializes HomeWidget listeners, background callback registration, and state bridges.
  Future<void> init() async {
    if (kIsWeb || _isInitialized) return;
    _isInitialized = true;

    try {
      await HomeWidget.setAppGroupId('group.com.example.musicApp');
    } catch (e) {
      debugPrint('[WidgetService] Warning setting iOS AppGroupId: $e');
    }

    try {
      await HomeWidget.registerInteractivityCallback(homeWidgetBackgroundCallback);
    } catch (e) {
      debugPrint('[WidgetService] Warning registering interactivity callback: $e');
    }

    // Handle initial launch from cold start
    try {
      final initialUri = await HomeWidget.initiallyLaunchedFromHomeWidget();
      if (initialUri != null) {
        debugPrint('[WidgetService] Cold start from home widget: $initialUri');
        _pendingLaunchUri = initialUri;
      }
    } catch (e) {
      debugPrint('[WidgetService] Error checking initial launch URI: $e');
    }

    // Handle runtime clicks when app is in foreground / warm state
    _widgetClickedSubscription = HomeWidget.widgetClicked.listen((Uri? uri) {
      if (uri != null) {
        debugPrint('[WidgetService] Warm launch / click from home widget: $uri');
        handleWidgetLaunchUri(uri);
      }
    });

    // Listen to MusicService state changes
    _musicService.addListener(_onMusicServiceStateChanged);

    // Throttled position listener to update widget scrubber progress
    _positionSubscription = _musicService.positionStream.listen((position) {
      _throttleScrubberSync(position);
    });

    // Initial sync
    syncWidgetData();
  }

  void _onMusicServiceStateChanged() {
    syncWidgetData();
  }

  static String formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _throttleScrubberSync(Duration position) {
    final total = _musicService.duration?.inMilliseconds ?? 0;
    if (total <= 0) return;

    final percent = ((position.inMilliseconds / total) * 100).round().clamp(0, 100);
    final now = DateTime.now();

    // Update scrubber if percent changed by at least 2% or every 3.5 seconds
    if ((percent != _lastProgressSynced && (percent - _lastProgressSynced).abs() >= 2) ||
        now.difference(_lastProgressSyncTime).inSeconds >= 4) {
      _lastProgressSynced = percent;
      _lastProgressSyncTime = now;
      final currentTimeStr = formatDuration(position);
      final totalDurationStr = formatDuration(_musicService.duration ?? Duration.zero);
      HomeWidget.saveWidgetData<int>('progress_percent', percent);
      HomeWidget.saveWidgetData<String>('current_time', currentTimeStr);
      HomeWidget.saveWidgetData<String>('total_duration', totalDurationStr);
      HomeWidget.updateWidget(
        name: 'DilSeMusicWidgetProvider',
        iOSName: 'DilSeMusicWidget',
      );
    }
  }

  /// Synchronizes complete playback, dominant color, and playlist state into HomeWidget storage.
  Future<void> syncWidgetData() async {
    if (kIsWeb || !_isInitialized) return;

    try {
      final song = _musicService.currentSong;
      final isPlaying = _musicService.isPlaying;
      final isShuffle = _musicService.isShuffle;
      final loopMode = _musicService.loopMode;
      final repeatModeStr = loopMode == LoopMode.one
          ? 'one'
          : (loopMode == LoopMode.all ? 'all' : 'off');

      final posMs = _musicService.position.inMilliseconds;
      final durMs = _musicService.duration?.inMilliseconds ?? 0;
      final progressPercent = durMs > 0 ? ((posMs / durMs) * 100).round().clamp(0, 100) : 0;
      final currentTimeStr = formatDuration(_musicService.position);
      final totalDurationStr = formatDuration(_musicService.duration ?? Duration.zero);

      // Extract dominant color and format hex string
      final dominantColor = _musicService.dominantColor;
      final dominantArgb = dominantColor.toARGB32();
      final dominantHex =
          '#${dominantArgb.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

      // 1. Save Core Playback Data
      await HomeWidget.saveWidgetData<String>('title', song?.title ?? 'DilSe Music');
      await HomeWidget.saveWidgetData<String>('artist', song?.author ?? 'Tap to play');
      await HomeWidget.saveWidgetData<bool>('is_playing', isPlaying);
      await HomeWidget.saveWidgetData<bool>('is_shuffle', isShuffle);
      await HomeWidget.saveWidgetData<String>('repeat_mode', repeatModeStr);
      await HomeWidget.saveWidgetData<int>('progress_percent', progressPercent);
      await HomeWidget.saveWidgetData<String>('current_time', currentTimeStr);
      await HomeWidget.saveWidgetData<String>('total_duration', totalDurationStr);
      await HomeWidget.saveWidgetData<int>('dominant_color', dominantArgb);
      await HomeWidget.saveWidgetData<String>('dominant_color_hex', dominantHex);

      // 2. Cache & Save Album Artwork
      if (song != null) {
        final thumbnailUrl = song.thumbnails.highResUrl;
        if (thumbnailUrl.isNotEmpty) {
          final artPath = await _cacheArtwork(thumbnailUrl, song.id.value);
          if (artPath != null) {
            await HomeWidget.saveWidgetData<String>('artwork_path', artPath);
          }
        }
      }

      // 3. Save Top 5 Playlists for bottom row
      await _syncTopPlaylists();

      // 4. Signal HomeWidget to re-render for Android and iOS
      await HomeWidget.updateWidget(
        name: 'DilSeMusicWidgetProvider',
        iOSName: 'DilSeMusicWidget',
      );
    } catch (e) {
      debugPrint('[WidgetService] Error during syncWidgetData: $e');
    }
  }

  /// Synchronizes top 5 playlists data into widget storage.
  Future<void> _syncTopPlaylists() async {
    final customList = _musicService.customPlaylists;
    final top5 = <_WidgetPlaylistItem>[];

    // Priority 1: User's custom playlists
    for (final pl in customList) {
      if (top5.length >= 5) break;
      final id = pl['id']?.toString() ?? '';
      final name = pl['name']?.toString() ?? 'Playlist';
      final songs = List<Map<String, dynamic>>.from(pl['songs'] ?? []);
      final thumb = songs.isNotEmpty ? songs.first['thumbnail']?.toString() : null;
      top5.add(_WidgetPlaylistItem(id: id, title: name, thumbnailUrl: thumb));
    }

    // Priority 2: Pad with Liked Songs and Curated Playlists
    final fallbackCandidates = [
      _WidgetPlaylistItem(
        id: 'liked',
        title: 'Liked',
        thumbnailUrl: _musicService.likedSongs.isNotEmpty
            ? _musicService.likedSongs.first['thumbnail']
            : null,
      ),
      _WidgetPlaylistItem(id: 'global_top_50', title: 'Top 50', thumbnailUrl: null),
      _WidgetPlaylistItem(id: 'trending_telugu', title: 'Telugu', thumbnailUrl: null),
      _WidgetPlaylistItem(id: 'party_hits', title: 'Party', thumbnailUrl: null),
      _WidgetPlaylistItem(id: 'chill_mix', title: 'Chill', thumbnailUrl: null),
    ];

    for (final fallback in fallbackCandidates) {
      if (top5.length >= 5) break;
      if (!top5.any((item) => item.id == fallback.id)) {
        top5.add(fallback);
      }
    }

    // Save up to 5 items to widget storage
    for (int i = 0; i < 5; i++) {
      final index = i + 1;
      if (i < top5.length) {
        final item = top5[i];
        await HomeWidget.saveWidgetData<String>('playlist_id_$index', item.id);
        await HomeWidget.saveWidgetData<String>('playlist_title_$index', item.title);

        if (item.thumbnailUrl != null && item.thumbnailUrl!.isNotEmpty) {
          final artPath = await _cacheArtwork(item.thumbnailUrl!, 'playlist_$index');
          if (artPath != null) {
            await HomeWidget.saveWidgetData<String>('playlist_art_$index', artPath);
          }
        }
      }
    }
  }

  /// Downloads and caches an image URL to local disk for widget consumption.
  Future<String?> _cacheArtwork(String url, String identifier) async {
    try {
      if (_lastCachedArtworkUrl == url &&
          _lastCachedArtworkPath != null &&
          File(_lastCachedArtworkPath!).existsSync()) {
        return _lastCachedArtworkPath;
      }

      final dir = await getApplicationSupportDirectory();
      final sanitizedId = identifier.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final targetFile = File('${dir.path}/widget_art_$sanitizedId.png');

      if (!targetFile.existsSync()) {
        final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 4));
        if (response.statusCode == 200) {
          await targetFile.writeAsBytes(response.bodyBytes);
        } else {
          return null;
        }
      }

      _lastCachedArtworkUrl = url;
      _lastCachedArtworkPath = targetFile.path;
      return targetFile.path;
    } catch (e) {
      debugPrint('[WidgetService] Artwork caching error: $e');
      return null;
    }
  }

  /// Static handler for background intents (when buttons are tapped in widget).
  static Future<void> handleBackgroundUri(Uri uri) async {
    final music = MusicService();

    // Ensure audio service is initialized if background engine just booted
    if (!kIsWeb && audioHandler == null) {
      try {
        await initAudioService();
      } catch (_) {}
    }

    final path = uri.path;
    final host = uri.host;
    final action = path.isNotEmpty ? path.replaceAll('/', '') : host;

    debugPrint('[WidgetService] Processing background action: $action');

    switch (action) {
      case 'play_pause':
        if (music.currentSong != null) {
          music.togglePlayPause();
        } else if (music.likedSongs.isNotEmpty) {
          await music.playLikedSong(music.likedSongs.first);
        } else {
          // Play popular trending songs as smart fallback
          final tracks = await music.searchSongs('Top Hits');
          if (tracks.isNotEmpty) {
            await music.playPlaylist(tracks, 0);
          }
        }
        break;

      case 'next':
        await music.nextSong();
        break;

      case 'previous':
        await music.previousSong();
        break;

      case 'shuffle':
        music.toggleShuffle();
        break;

      case 'repeat':
        music.toggleRepeat();
        break;
    }

    // Refresh widget representation immediately
    await WidgetService().syncWidgetData();
  }

  /// Routes incoming deep link URIs to the proper destination screens.
  void handleWidgetLaunchUri(Uri uri) {
    debugPrint('[WidgetService] Navigating to URI: $uri');

    // 1. Playlist Deep Link: dilse://playlist?id=...&title=...
    if (uri.host == 'playlist' || uri.path.contains('playlist')) {
      final playlistId = uri.queryParameters['id'] ?? 'liked';
      _navigateToPlaylist(playlistId);
      return;
    }

    // 2. Player Screen: dilse://player
    if (uri.host == 'player' || uri.path.contains('player')) {
      _navigateToPlayer();
      return;
    }

    // 3. In case controls were dispatched as launch intents:
    if (uri.host == 'widget' || uri.path.contains('widget')) {
      handleBackgroundUri(uri);
    }
  }

  void consumePendingLaunchUri() {
    if (_pendingLaunchUri != null) {
      final uri = _pendingLaunchUri!;
      _pendingLaunchUri = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        handleWidgetLaunchUri(uri);
      });
    }
  }

  void _navigateToPlaylist(String playlistId) {
    final nav = navigatorKey.currentState;
    if (nav == null) {
      _pendingLaunchUri = Uri.parse('dilse://playlist?id=$playlistId');
      return;
    }

    nav.push(
      MaterialPageRoute(
        builder: (_) => CustomPlaylistScreen(playlistId: playlistId),
      ),
    );
  }

  void _navigateToPlayer() {
    final nav = navigatorKey.currentState;
    if (nav == null) {
      _pendingLaunchUri = Uri.parse('dilse://player');
      return;
    }

    nav.push(
      MaterialPageRoute(
        builder: (_) => const PlayerScreen(),
      ),
    );
  }

  void dispose() {
    _musicService.removeListener(_onMusicServiceStateChanged);
    _widgetClickedSubscription?.cancel();
    _positionSubscription?.cancel();
  }
}

class _WidgetPlaylistItem {
  final String id;
  final String title;
  final String? thumbnailUrl;

  _WidgetPlaylistItem({
    required this.id,
    required this.title,
    this.thumbnailUrl,
  });
}

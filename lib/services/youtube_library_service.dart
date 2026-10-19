import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'api_config.dart';
import 'auth_service.dart';
import 'canonical_song_dedup.dart';
import 'music_service.dart';
import 'preferences_service.dart';
import 'studio_search_service.dart';
import 'youtube_music_client.dart';

/// Data class representing a YouTube Playlist owned by the user.
class YouTubePlaylist {
  final String id;
  final String title;
  final String description;
  final String thumbnailUrl;
  final int itemCount;

  const YouTubePlaylist({
    required this.id,
    required this.title,
    required this.description,
    required this.thumbnailUrl,
    required this.itemCount,
  });

  factory YouTubePlaylist.fromJson(Map<String, dynamic> json) {
    final snippet = json['snippet'] as Map<String, dynamic>? ?? {};
    final contentDetails =
        json['contentDetails'] as Map<String, dynamic>? ?? {};
    final thumbnails = snippet['thumbnails'] as Map<String, dynamic>? ?? {};

    String thumb = '';
    if (thumbnails['high'] != null && thumbnails['high']['url'] != null) {
      thumb = thumbnails['high']['url'].toString();
    } else if (thumbnails['medium'] != null &&
        thumbnails['medium']['url'] != null) {
      thumb = thumbnails['medium']['url'].toString();
    } else if (thumbnails['default'] != null &&
        thumbnails['default']['url'] != null) {
      thumb = thumbnails['default']['url'].toString();
    }

    return YouTubePlaylist(
      id: json['id']?.toString() ?? '',
      title: snippet['title']?.toString() ?? 'Untitled Playlist',
      description: snippet['description']?.toString() ?? '',
      thumbnailUrl: thumb,
      itemCount:
          int.tryParse(contentDetails['itemCount']?.toString() ?? '0') ?? 0,
    );
  }
}

/// Service to fetch the user's authentic YouTube Music library.
///
/// Invariant: Strictly READ-ONLY.
/// Queries only read-only Google endpoints with the user's OAuth access token.
/// Never mutates, likes, dislikes, or alters the user's YouTube account or recommendations.
class YouTubeLibraryService extends ChangeNotifier {
  static final YouTubeLibraryService _instance =
      YouTubeLibraryService._internal();
  factory YouTubeLibraryService() => _instance;
  YouTubeLibraryService._internal();

  static const String _apiBase = 'https://www.googleapis.com/youtube/v3';

  List<YouTubePlaylist> _cachedPlaylists = [];
  final Map<String, List<Video>> _playlistSongsCache = {};
  List<Video> _cachedLikedMusic = [];
  List<Video> _cachedLikedMusicResolvedToJio = [];
  List<Video> _cachedSupermix = [];
  List<Video> _cachedDiscoverMix = [];
  List<Video> _cachedNewReleaseMix = [];
  List<Video> _cachedForgottenTracks = [];
  bool _isLoading = false;

  /// User's cached YouTube playlists.
  List<YouTubePlaylist> get playlists => List.unmodifiable(_cachedPlaylists);

  /// User's cached Liked Music songs from YouTube.
  List<Video> get likedMusic => List.unmodifiable(_cachedLikedMusic);

  /// User's Liked Music resolved against JioSaavn 320kbps catalog, keeping only available tracks.
  List<Video> get likedMusicResolvedToJio =>
      List.unmodifiable(_cachedLikedMusicResolvedToJio);

  /// User's cached Forgotten Tracks.
  List<Video> get forgottenTracks => List.unmodifiable(_cachedForgottenTracks);

  /// Whether a fetch operation is currently in flight.
  bool get isLoading => _isLoading;

  /// Fetches the user's YouTube playlists using their Google access token.
  Future<List<YouTubePlaylist>> fetchUserPlaylists({
    bool forceRefresh = false,
  }) async {
    if (!AuthService().isAuthenticated) {
      _cachedPlaylists = [];
      notifyListeners();
      return [];
    }

    if (AuthService().isDemoMode) {
      _cachedPlaylists = const [
        YouTubePlaylist(
          id: 'yt_demo_playlist_1',
          title: 'Chill Vibes 2026',
          description: 'Acoustic and lo-fi hits for relaxation.',
          thumbnailUrl:
              'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=300',
          itemCount: 24,
        ),
        YouTubePlaylist(
          id: 'yt_demo_playlist_2',
          title: 'Late Night Hits',
          description: 'South Indian & Bollywood midnight vibes.',
          thumbnailUrl:
              'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=300',
          itemCount: 38,
        ),
        YouTubePlaylist(
          id: 'yt_demo_playlist_3',
          title: 'Acoustic Morning',
          description: 'Melodic acoustics to start the day fresh.',
          thumbnailUrl:
              'https://images.unsplash.com/photo-1447752875215-b2761acb3c5d?w=300',
          itemCount: 16,
        ),
      ];
      notifyListeners();
      return _cachedPlaylists;
    }

    // Invariant: youtube.readonly scope is retired from AuthService.
    // If not running in demo mode, do not call private user playlists endpoints.
    if (!AuthService().isDemoMode) {
      _cachedPlaylists = [];
      notifyListeners();
      return [];
    }

    if (!forceRefresh && _cachedPlaylists.isNotEmpty) {
      return _cachedPlaylists;
    }

    final token = await AuthService().getFreshAccessToken();
    if (token == null || token.isEmpty) return [];

    _isLoading = true;
    notifyListeners();

    try {
      final uri = Uri.parse(
        '$_apiBase/playlists?part=snippet,contentDetails&mine=true&maxResults=50',
      );
      final response = await http
          .get(
            uri,
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final items = data['items'] as List<dynamic>? ?? [];
        _cachedPlaylists = items
            .map(
              (item) => YouTubePlaylist.fromJson(item as Map<String, dynamic>),
            )
            .where((p) => p.id.isNotEmpty)
            .toList();
        debugPrint(
          '[YouTubeLibrary] Fetched ${_cachedPlaylists.length} playlists for user',
        );
      } else {
        debugPrint(
          '[YouTubeLibrary] Failed to fetch playlists: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('[YouTubeLibrary] Error fetching playlists: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }

    return _cachedPlaylists;
  }

  /// Fetches all songs inside a specific YouTube playlist.
  Future<List<Video>> fetchPlaylistSongs(
    String playlistId, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _playlistSongsCache.containsKey(playlistId)) {
      return _playlistSongsCache[playlistId]!;
    }

    if (AuthService().isDemoMode || playlistId.startsWith('yt_demo_')) {
      final songs = _getDemoStudioLikedTracks();
      _playlistSongsCache[playlistId] = songs;
      return songs;
    }

    final token = await AuthService().getFreshAccessToken();
    if (token == null || token.isEmpty) return [];

    try {
      final uri = Uri.parse(
        '$_apiBase/playlistItems?part=snippet,contentDetails&playlistId=$playlistId&maxResults=50',
      );
      final response = await http
          .get(
            uri,
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final items = data['items'] as List<dynamic>? ?? [];
        final List<Video> songs = [];

        for (final item in items) {
          final snippet = item['snippet'] as Map<String, dynamic>? ?? {};
          final contentDetails =
              item['contentDetails'] as Map<String, dynamic>? ?? {};
          final videoId =
              contentDetails['videoId']?.toString() ??
              snippet['resourceId']?['videoId']?.toString() ??
              '';
          if (videoId.isEmpty) continue;

          final title = snippet['title']?.toString() ?? 'Unknown Song';
          final author =
              snippet['videoOwnerChannelTitle']?.toString() ??
              snippet['channelTitle']?.toString() ??
              'Unknown Artist';

          final video = Video(
            VideoId(videoId),
            title,
            author,
            ChannelId(
              snippet['channelId']?.toString() ?? 'UC0WP5P-fwGlLyO4yOE76T8g',
            ),
            DateTime.now(),
            '',
            null,
            '',
            null,
            ThumbnailSet(videoId),
            null,
            Engagement(0, null, null),
            false,
          );

          if (CanonicalSongDedup.isGenuineSong(video)) {
            songs.add(video);
          }
        }

        final rawDeduped = CanonicalSongDedup.deduplicateList(songs);

        // Resolve tracks against JioSaavn 320kbps catalog in concurrent chunks of 6
        final List<Video> resolved = [];
        const int chunkSize = 6;
        for (int i = 0; i < rawDeduped.length; i += chunkSize) {
          final end = (i + chunkSize < rawDeduped.length)
              ? i + chunkSize
              : rawDeduped.length;
          final chunk = rawDeduped.sublist(i, end);
          final jioMatches = await Future.wait(
            chunk.map((v) => resolveTrackToJioSaavn(v)),
          );
          for (int j = 0; j < chunk.length; j++) {
            final jioMatch = jioMatches[j];
            if (jioMatch != null) {
              resolved.add(jioMatch);
            } else {
              // Retain genuine YouTube song if no direct Jio match
              resolved.add(chunk[j]);
            }
          }
        }

        final deduped = CanonicalSongDedup.deduplicateList(resolved);
        _playlistSongsCache[playlistId] = deduped;
        return deduped;
      }
    } catch (e) {
      debugPrint('[YouTubeLibrary] Error fetching playlist items: $e');
    }

    return [];
  }

  /// Fetches user's "Liked Music" tracks from YouTube (System playlist `LM`).
  Future<List<Video>> fetchLikedMusic({bool forceRefresh = false}) async {
    if (!AuthService().isAuthenticated) {
      _cachedLikedMusic = [];
      notifyListeners();
      return [];
    }

    // Invariant: youtube.readonly scope is retired from AuthService.
    if (!AuthService().isDemoMode) {
      _cachedLikedMusic = [];
      notifyListeners();
      return [];
    }

    if (!forceRefresh && _cachedLikedMusic.isNotEmpty) {
      return _cachedLikedMusic;
    }

    // Liked music lives in the special system playlist 'LM'
    final songs = await fetchPlaylistSongs('LM', forceRefresh: forceRefresh);
    if (songs.isNotEmpty) {
      _cachedLikedMusic = songs;
      notifyListeners();
      return songs;
    }

    // Fallback: Query videos with myRating=like under music category (category 10)
    final token = await AuthService().getFreshAccessToken();
    if (token == null || token.isEmpty) return [];

    try {
      final uri = Uri.parse(
        '$_apiBase/videos?part=snippet,contentDetails&myRating=like&videoCategoryId=10&maxResults=50',
      );
      final response = await http
          .get(
            uri,
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final items = data['items'] as List<dynamic>? ?? [];
        final List<Video> fallbackSongs = [];

        for (final item in items) {
          final videoId = item['id']?.toString() ?? '';
          if (videoId.isEmpty) continue;
          final snippet = item['snippet'] as Map<String, dynamic>? ?? {};
          final title = snippet['title']?.toString() ?? 'Unknown Song';
          final author =
              snippet['channelTitle']?.toString() ?? 'Unknown Artist';

          final video = Video(
            VideoId(videoId),
            title,
            author,
            ChannelId(
              snippet['channelId']?.toString() ?? 'UC0WP5P-fwGlLyO4yOE76T8g',
            ),
            DateTime.now(),
            '',
            null,
            '',
            null,
            ThumbnailSet(videoId),
            null,
            Engagement(0, null, null),
            false,
          );

          if (CanonicalSongDedup.isGenuineSong(video)) {
            fallbackSongs.add(video);
          }
        }

        _cachedLikedMusic = CanonicalSongDedup.deduplicateList(fallbackSongs);
        notifyListeners();
        return _cachedLikedMusic;
      }
    } catch (e) {
      debugPrint('[YouTubeLibrary] Error fetching liked music: $e');
    }

    return [];
  }

  /// Synchronizes authentic YouTube Music taste (Liked Music + user playlists)
  /// into the local taste matrix, dynamic artists, and personalized mixes.
  Future<void> syncGoogleTaste({bool forceRefresh = false}) async {
    if (!AuthService().isAuthenticated || !AuthService().isDemoMode) return;

    try {
      debugPrint(
        '[YouTubeLibrary] Syncing Google taste from YouTube library...',
      );
      // 1. Fetch liked music
      final liked = await fetchLikedMusic(forceRefresh: forceRefresh);

      // 2. Fetch playlists
      final userPlaylists = await fetchUserPlaylists(
        forceRefresh: forceRefresh,
      );

      // 3. Fetch songs from top 3 playlists to enrich taste breadth
      final List<Video> playlistTracks = [];
      for (final p in userPlaylists.take(3)) {
        if (p.id.isNotEmpty && p.id != 'LM') {
          final tracks = await fetchPlaylistSongs(
            p.id,
            forceRefresh: forceRefresh,
          );
          playlistTracks.addAll(tracks.take(15));
        }
      }

      // 4. Seed into PreferencesService taste matrix
      await PreferencesService().seedTasteFromYouTube(
        likedSongs: liked,
        playlistSongs: playlistTracks,
      );

      debugPrint(
        '[YouTubeLibrary] Successfully synced ${liked.length} liked songs and ${playlistTracks.length} playlist songs into taste matrix',
      );
    } catch (e) {
      debugPrint('[YouTubeLibrary] Failed to sync Google taste: $e');
    }
  }

  /// Static cache for YouTube metadata -> JioSaavn Video resolution.
  static final Map<String, Video?> _ytToJioCache = {};

  /// Resolves a single YouTube track to JioSaavn studio track by title & artist metadata.
  /// Returns null if no authentic studio match exists on JioSaavn (strictly filtering out unavailable tracks).
  Future<Video?> resolveTrackToJioSaavn(Video ytTrack) async {
    final cleanT = CanonicalSongDedup.cleanTitle(ytTrack.title);
    final cleanA = CanonicalSongDedup.cleanArtist(ytTrack.author);
    if (cleanT.isEmpty) return null;

    final cacheKey = '$cleanT|$cleanA';
    if (_ytToJioCache.containsKey(cacheKey)) {
      return _ytToJioCache[cacheKey];
    }

    try {
      final query = cleanA.isNotEmpty ? '$cleanT $cleanA' : cleanT;
      final uri = ApiConfig.jioSearchUri(query, limit: 10, page: 1);
      final response = await http
          .get(uri)
          .timeout(const Duration(seconds: 5))
          .catchError((_) => http.Response('[]', 500));

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(response.body);
        for (final item in jsonList) {
          if (item is! Map) continue;
          final songId = item['id']?.toString() ?? '';
          if (songId.isEmpty) continue;

          final rawTitle = item['title']?.toString() ?? '';
          final rawAuthor = item['author']?.toString() ?? '';
          final candCleanT = CanonicalSongDedup.cleanTitle(rawTitle);
          final candCleanA = CanonicalSongDedup.cleanArtist(rawAuthor);

          final bool titleMatches =
              candCleanT == cleanT ||
              candCleanT.contains(cleanT) ||
              cleanT.contains(candCleanT) ||
              CanonicalSongDedup.stringSimilarity(candCleanT, cleanT) >= 0.65;

          final bool artistMatches =
              cleanA.isEmpty ||
              candCleanA.contains(cleanA) ||
              cleanA.contains(candCleanA) ||
              CanonicalSongDedup.stringSimilarity(candCleanA, cleanA) >= 0.55;

          if (titleMatches && artistMatches) {
            final album = item['album']?.toString() ?? '';
            final durationSec = item['duration'] != null
                ? int.tryParse(item['duration'].toString())
                : null;
            final duration = durationSec != null
                ? Duration(seconds: durationSec)
                : null;
            final artwork = item['thumbnail']?.toString() ?? '';
            final streamUrl = item['streamUrl']?.toString() ?? '';
            final vidString = songId.length >= 11
                ? songId.substring(0, 11)
                : songId.padRight(11, '0');

            if (artwork.isNotEmpty) {
              MusicService.registerArtwork(songId, artwork);
              MusicService.registerArtwork(vidString, artwork);
            }
            if (streamUrl.isNotEmpty) {
              MusicService.cacheWebStreamUrl(songId, streamUrl);
              MusicService.cacheWebStreamUrl(vidString, streamUrl);
            }
            final albumId =
                item['album_id']?.toString() ??
                item['albumId']?.toString() ??
                '';
            if (album.isNotEmpty || albumId.isNotEmpty) {
              MusicService.registerSongAlbum(
                songId,
                albumTitle: album,
                albumId: albumId,
              );
              MusicService.registerSongAlbum(
                vidString,
                albumTitle: album,
                albumId: albumId,
              );
            }

            final resolvedVideo = Video(
              VideoId(vidString),
              CanonicalSongDedup.sanitizeDisplayTitle(
                rawTitle,
                artist: rawAuthor,
              ),
              rawAuthor,
              ChannelId('UC0WP5P-fwGlLyO4yOE76T8g'),
              DateTime.now(),
              '',
              null,
              '',
              duration,
              ThumbnailSet(vidString),
              null,
              Engagement(0, null, null),
              false,
            );

            if (CanonicalSongDedup.isGenuineSong(resolvedVideo)) {
              _ytToJioCache[cacheKey] = resolvedVideo;
              return resolvedVideo;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[YouTubeLibrary] Failed to resolve track to Jio: $e');
    }

    _ytToJioCache[cacheKey] = null;
    return null;
  }

  /// Fetches user's "Liked Music" from YouTube, parses each track's metadata through JioSaavn,
  /// and retains ONLY tracks that are genuinely available on JioSaavn in authentic 320kbps studio quality.
  Future<List<Video>> fetchLikedMusicResolvedToJio({
    bool forceRefresh = false,
  }) async {
    if (!AuthService().isAuthenticated) {
      _cachedLikedMusicResolvedToJio = [];
      notifyListeners();
      return [];
    }

    if (!forceRefresh && _cachedLikedMusicResolvedToJio.isNotEmpty) {
      return _cachedLikedMusicResolvedToJio;
    }

    if (AuthService().isDemoMode) {
      _cachedLikedMusicResolvedToJio = _getDemoStudioLikedTracks();
      notifyListeners();
      return _cachedLikedMusicResolvedToJio;
    }

    final rawLiked = await fetchLikedMusic(forceRefresh: forceRefresh);
    if (rawLiked.isEmpty) {
      _cachedLikedMusicResolvedToJio = [];
      notifyListeners();
      return [];
    }

    // Concurrently resolve in chunks of 8 workers
    final List<Video> resolvedTracks = [];
    const int chunkSize = 8;
    for (int i = 0; i < rawLiked.length; i += chunkSize) {
      final end = (i + chunkSize < rawLiked.length)
          ? i + chunkSize
          : rawLiked.length;
      final chunk = rawLiked.sublist(i, end);
      final results = await Future.wait(
        chunk.map((v) => resolveTrackToJioSaavn(v)),
      );
      for (final song in results) {
        if (song != null) {
          resolvedTracks.add(song);
        }
      }
    }

    final deduped = CanonicalSongDedup.deduplicateList(resolvedTracks);
    _cachedLikedMusicResolvedToJio = deduped;
    notifyListeners();
    return deduped;
  }

  List<Video> _getDemoStudioLikedTracks() {
    final demoData = [
      {
        'id': 'jio_demo_1',
        'title': 'Kesariya',
        'author': 'Pritam, Arijit Singh',
        'album': 'Brahmastra',
        'thumb':
            'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=300',
      },
      {
        'id': 'jio_demo_2',
        'title': 'Samajavaragamana',
        'author': 'Sid Sriram, Thaman S',
        'album': 'Ala Vaikunthapurramuloo',
        'thumb':
            'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=300',
      },
      {
        'id': 'jio_demo_3',
        'title': 'Arabic Kuthu',
        'author': 'Anirudh Ravichander',
        'album': 'Beast',
        'thumb':
            'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=300',
      },
      {
        'id': 'jio_demo_4',
        'title': 'Shape of You',
        'author': 'Ed Sheeran',
        'album': 'Divide',
        'thumb':
            'https://images.unsplash.com/photo-1447752875215-b2761acb3c5d?w=300',
      },
      {
        'id': 'jio_demo_5',
        'title': 'Naatu Naatu',
        'author': 'M. M. Keeravani, Rahul Sipligunj',
        'album': 'RRR',
        'thumb':
            'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=300',
      },
      {
        'id': 'jio_demo_6',
        'title': 'Butta Bomma',
        'author': 'Armaan Malik, Thaman S',
        'album': 'Ala Vaikunthapurramuloo',
        'thumb':
            'https://images.unsplash.com/photo-1508700115892-45ecd05ae2ad?w=300',
      },
    ];

    return demoData.map((d) {
      final vidString = d['id']!.padRight(11, '0');
      MusicService.registerArtwork(d['id']!, d['thumb']!);
      MusicService.registerArtwork(vidString, d['thumb']!);
      return Video(
        VideoId(vidString),
        d['title']!,
        d['author']!,
        ChannelId('UC0WP5P-fwGlLyO4yOE76T8g'),
        DateTime.now(),
        '',
        null,
        '',
        const Duration(minutes: 3, seconds: 45),
        ThumbnailSet(vidString),
        null,
        Engagement(0, null, null),
        false,
      );
    }).toList();
  }

  /// Fetches an endless personalized "My Supermix" tailored to the listener's genuine taste.
  /// Synthesizes recommendations from user's liked music & dynamic taste matrix.
  Future<List<Video>> fetchSupermix({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedSupermix.isNotEmpty) {
      return _cachedSupermix;
    }

    if (AuthService().isDemoMode) {
      _cachedSupermix = _getDemoStudioLikedTracks();
      notifyListeners();
      return _cachedSupermix;
    }

    try {
      final List<Video> supermixTracks = [];

      // 1. Gather seed tracks from Liked Music (or resolved liked music)
      final liked = _cachedLikedMusicResolvedToJio.isNotEmpty
          ? _cachedLikedMusicResolvedToJio
          : _cachedLikedMusic;

      if (liked.isNotEmpty) {
        // Take up to 3 seed songs to generate diverse radio streams
        final seeds = liked.take(3).toList();
        for (final seed in seeds) {
          try {
            final radio = await YouTubeMusicClient().fetchRadioTracks(
              seed.id.value,
              limit: 25,
            );
            supermixTracks.addAll(radio);
          } catch (_) {}
        }
      }

      // 2. If seed radio returned fewer than 25 tracks, supplement from taste matrix
      if (supermixTracks.length < 25) {
        final tasteSeeds = PreferencesService().getPersonalizedMixSeeds();
        for (final seedQuery in tasteSeeds.take(2)) {
          final studioHits = await StudioSearchService().searchSongs(
            seedQuery,
            limit: 20,
          );
          supermixTracks.addAll(studioHits);
        }
      }

      // 3. Fallback to daily mix configs if still sparse
      if (supermixTracks.isEmpty) {
        final mixes = PreferencesService().getDailyMixConfigs();
        if (mixes.isNotEmpty) {
          final daily = await MusicService().fetchJioDailyMix(
            mixes.first,
            limit: 35,
          );
          supermixTracks.addAll(daily);
        }
      }

      final genuine = supermixTracks
          .where((v) => CanonicalSongDedup.isGenuineSong(v))
          .toList();
      final deduped = CanonicalSongDedup.deduplicateList(genuine);
      _cachedSupermix = deduped;
      notifyListeners();
      return deduped;
    } catch (e) {
      debugPrint('[YouTubeLibrary] Error building Supermix: $e');
    }

    return [];
  }

  /// Helper to extract authentic user artists from liked songs, followed artists, and top artist.
  List<String> _extractUserArtists(List<Video> likedSongs) {
    final List<String> artists = [];
    final topArtist = PreferencesService().mostPlayedArtist;
    if (topArtist.isNotEmpty) {
      artists.add(topArtist);
    }
    for (final a in PreferencesService().followedArtists) {
      if (!artists.contains(a)) artists.add(a);
    }
    for (final song in likedSongs) {
      final clean = CanonicalSongDedup.cleanArtist(song.author);
      if (clean.isNotEmpty && !artists.contains(clean)) {
        artists.add(clean);
      }
    }
    return artists;
  }

  /// Fetches "Discover Mix" with fresh discoveries tailored to user's authentic taste,
  /// specifically surfacing tracks the user hasn't liked yet from artists and styles they love.
  Future<List<Video>> fetchDiscoverMix({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedDiscoverMix.isNotEmpty) {
      return _cachedDiscoverMix;
    }

    if (AuthService().isDemoMode) {
      _cachedDiscoverMix = _getDemoStudioLikedTracks();
      notifyListeners();
      return _cachedDiscoverMix;
    }

    try {
      final List<Video> discoverTracks = [];
      final langs = PreferencesService().preferredLanguages;
      final primaryLang = langs.isNotEmpty ? langs.first : 'Telugu';

      // 1. Gather authentic liked tracks & titles to avoid recommending what they already like
      final liked = _cachedLikedMusicResolvedToJio.isNotEmpty
          ? _cachedLikedMusicResolvedToJio
          : (await fetchLikedMusicResolvedToJio());
      final Set<String> likedTitles = liked
          .map((v) => CanonicalSongDedup.cleanTitle(v.title))
          .toSet();
      final userArtists = _extractUserArtists(liked);

      // 2. Discover related radio tracks for up to 3 liked seeds
      if (liked.isNotEmpty) {
        for (final seed in liked.take(3)) {
          try {
            final radio = await YouTubeMusicClient().fetchRadioTracks(
              seed.id.value,
              limit: 15,
            );
            discoverTracks.addAll(radio);
          } catch (_) {}
        }
      }

      // 3. Query high-quality studio hits from user's favorite artists
      for (final artist in userArtists.take(3)) {
        final hits = await StudioSearchService().searchSongs(
          '$artist hits',
          limit: 12,
        );
        discoverTracks.addAll(hits);
      }

      // 4. If user is brand new or sparse, supplement with personalized mix seeds
      if (discoverTracks.length < 20) {
        final tasteSeeds = PreferencesService().getPersonalizedMixSeeds();
        for (final seedQuery in tasteSeeds.take(2)) {
          final hits = await StudioSearchService().searchSongs(
            seedQuery,
            limit: 15,
          );
          discoverTracks.addAll(hits);
        }
      }

      // 5. Fallback: Trending in user's preferred language
      if (discoverTracks.length < 15) {
        final trending = await StudioSearchService().searchSongs(
          '$primaryLang Trending',
          limit: 20,
        );
        discoverTracks.addAll(trending);
      }

      // Filter out songs already in user's liked music (pure fresh discovery!)
      final freshDiscover = discoverTracks.where((v) {
        final cleanT = CanonicalSongDedup.cleanTitle(v.title);
        return !likedTitles.contains(cleanT) &&
            CanonicalSongDedup.isGenuineSong(v);
      }).toList();

      final deduped = CanonicalSongDedup.deduplicateList(
        freshDiscover.isNotEmpty ? freshDiscover : discoverTracks,
      );

      if (deduped.isNotEmpty) {
        _cachedDiscoverMix = deduped;
        notifyListeners();
        return deduped;
      }
    } catch (e) {
      debugPrint('[YouTubeLibrary] Error building Discover Mix: $e');
    }

    return [];
  }

  /// Fetches "New Release Mix" with the latest drops from artists the user genuinely listens to.
  Future<List<Video>> fetchNewReleaseMix({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedNewReleaseMix.isNotEmpty) {
      return _cachedNewReleaseMix;
    }

    if (AuthService().isDemoMode) {
      _cachedNewReleaseMix = _getDemoStudioLikedTracks();
      notifyListeners();
      return _cachedNewReleaseMix;
    }

    try {
      final List<Video> newTracks = [];
      final langs = PreferencesService().preferredLanguages;
      final primaryLang = langs.isNotEmpty ? langs.first : 'Telugu';

      final liked = _cachedLikedMusicResolvedToJio.isNotEmpty
          ? _cachedLikedMusicResolvedToJio
          : (await fetchLikedMusicResolvedToJio());
      final userArtists = _extractUserArtists(liked);

      // 1. Query latest releases from user's authentic favorite artists
      if (userArtists.isNotEmpty) {
        for (final artist in userArtists.take(4)) {
          final artistLatest = await StudioSearchService().searchSongs(
            '$artist new song',
            limit: 10,
          );
          newTracks.addAll(artistLatest);
        }
      }

      // 2. Supplement with personalized mix seeds
      if (newTracks.length < 20) {
        final tasteSeeds = PreferencesService().getPersonalizedMixSeeds();
        for (final seedQuery in tasteSeeds.take(2)) {
          final seedLatest = await StudioSearchService().searchSongs(
            '$seedQuery new',
            limit: 15,
          );
          newTracks.addAll(seedLatest);
        }
      }

      // 3. Fallback: Latest songs in primary language
      if (newTracks.length < 15) {
        final latest = await StudioSearchService().searchSongs(
          '$primaryLang Latest Songs',
          limit: 25,
        );
        newTracks.addAll(latest);
      }

      final genuine = newTracks
          .where((v) => CanonicalSongDedup.isGenuineSong(v))
          .toList();
      final deduped = CanonicalSongDedup.deduplicateList(genuine);
      if (deduped.isNotEmpty) {
        _cachedNewReleaseMix = deduped;
        notifyListeners();
        return deduped;
      }
    } catch (e) {
      debugPrint('[YouTubeLibrary] Error building New Release Mix: $e');
    }

    return [];
  }

  /// Fetches "Forgotten Tracks" — rediscovering past favorites from older liked music & timeless classics.
  Future<List<Video>> fetchForgottenTracks({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedForgottenTracks.isNotEmpty) {
      return _cachedForgottenTracks;
    }

    if (AuthService().isDemoMode) {
      _cachedForgottenTracks = _getDemoStudioLikedTracks().reversed.toList();
      notifyListeners();
      return _cachedForgottenTracks;
    }

    try {
      final List<Video> forgotten = [];
      final langs = PreferencesService().preferredLanguages;
      final primaryLang = langs.isNotEmpty ? langs.first : 'Telugu';

      // 1. Older Liked Music (tail half of liked songs from YouTube)
      final liked = _cachedLikedMusicResolvedToJio.isNotEmpty
          ? _cachedLikedMusicResolvedToJio
          : (await fetchLikedMusicResolvedToJio());

      if (liked.length >= 6) {
        final olderLiked = liked.skip(liked.length ~/ 2).toList();
        forgotten.addAll(olderLiked);
      } else if (liked.isNotEmpty) {
        forgotten.addAll(liked);
      }

      // 2. Timeless evergreen classics from user's favorite artists
      final userArtists = _extractUserArtists(liked);
      for (final artist in userArtists.take(3)) {
        final evergreen = await StudioSearchService().searchSongs(
          '$artist evergreen hits',
          limit: 10,
        );
        forgotten.addAll(evergreen);
      }

      // 3. Fallback: Evergreen classics in preferred language
      if (forgotten.length < 20) {
        final evergreen = await StudioSearchService().searchSongs(
          '$primaryLang Evergreen Hits',
          limit: 20,
        );
        forgotten.addAll(evergreen);
      }

      final genuine = forgotten
          .where((v) => CanonicalSongDedup.isGenuineSong(v))
          .toList();
      final deduped = CanonicalSongDedup.deduplicateList(genuine);
      if (deduped.isNotEmpty) {
        _cachedForgottenTracks = deduped;
        notifyListeners();
        return deduped;
      }
    } catch (e) {
      debugPrint('[YouTubeLibrary] Error building Forgotten Tracks: $e');
    }

    return [];
  }

  /// Clears in-memory caches when user signs out.
  void clear() {
    _cachedPlaylists = [];
    _playlistSongsCache.clear();
    _cachedLikedMusic = [];
    _cachedLikedMusicResolvedToJio = [];
    _cachedSupermix = [];
    _cachedDiscoverMix = [];
    _cachedNewReleaseMix = [];
    _cachedForgottenTracks = [];
    notifyListeners();
  }
}

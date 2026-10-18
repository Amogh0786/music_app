import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'api_config.dart';
import 'canonical_song_dedup.dart';
import 'dynamic_artist_service.dart';
import 'music_service.dart';
import 'youtube_music_client.dart';

/// Next-Generation Studio Search Service.
///
/// Implements the user-validated canonical search mechanism:
/// 1. Query YouTube Music (`WEB_REMIX`) first to obtain Google's canonical identification
///    of the exact track title and original artist (eliminating remix/cover confusion).
/// 2. Use the canonical `<Title> <Artist>` entity to query JioSaavn directly for
///    authentic, uncompressed 320kbps studio audio.
/// 3. If JioSaavn has no direct match for the canonical query, instantly fallback to
///    raw query search on JioSaavn.
/// 4. Extract remaining genuine variations, live performances, and similar songs from
///    YouTube Music, deduplicate them against the studio pool, and append them below
///    the original tracks.
class StudioSearchService {
  static final StudioSearchService _instance = StudioSearchService._internal();
  factory StudioSearchService() => _instance;
  StudioSearchService._internal();

  /// Primary search entrypoint for user search queries.
  Future<List<Video>> searchSongs(
    String rawQuery, {
    int page = 1,
    int limit = 50,
  }) async {
    final query = rawQuery.trim();
    if (query.isEmpty) return [];

    // Transparently handle artist discography if query matches a verified artist
    if (DynamicArtistService().isKnownArtist(query)) {
      final discography = await MusicService().fetchArtistDiscography(
        query,
        page: page,
      );
      if (discography.isNotEmpty) return discography;
    }

    try {
      final int jioLimit = limit.clamp(10, 60);

      // STEP 1: Query YouTube Music (Google Canonical Entity Identification)
      final ytmFuture = YouTubeMusicClient().searchSongs(query, limit: 15);

      // For page > 1, execute direct paginated JioSaavn search
      if (page > 1) {
        final paginatedResp = await http
            .get(
              ApiConfig.jioSearchUri(
                '$query hits',
                limit: jioLimit,
                page: page,
              ),
            )
            .timeout(const Duration(seconds: 8))
            .catchError((_) => http.Response('[]', 500));

        if (paginatedResp.statusCode == 200) {
          final results = _parseJioResults(paginatedResp.body, query: query);
          return CanonicalSongDedup.deduplicateList(
            results.where((v) => CanonicalSongDedup.isGenuineSong(v)).toList(),
          );
        }
        return [];
      }

      // STEP 2: Await YTM search results
      final rawYtm = await ytmFuture.catchError((_) => <Video>[]);
      final ytmResults = rawYtm
          .where((v) => CanonicalSongDedup.isGenuineSong(v))
          .toList();

      final Video? ytmAnchor = ytmResults.isNotEmpty ? ytmResults.first : null;
      List<Video> jioResults = [];

      // STEP 3: Query JioSaavn with Canonical Anchor if available
      if (ytmAnchor != null) {
        final cleanAnchorT = CanonicalSongDedup.cleanTitle(ytmAnchor.title);
        final cleanAnchorA = CanonicalSongDedup.cleanArtist(ytmAnchor.author);
        final anchorQuery = cleanAnchorA.isNotEmpty
            ? '$cleanAnchorT $cleanAnchorA'
            : cleanAnchorT;

        try {
          final anchorJioResp = await http
              .get(
                ApiConfig.jioSearchUri(anchorQuery, limit: jioLimit, page: 1),
              )
              .timeout(const Duration(seconds: 6))
              .catchError((_) => http.Response('[]', 500));

          if (anchorJioResp.statusCode == 200) {
            final parsedAnchor = _parseJioResults(
              anchorJioResp.body,
              query: query,
            );
            // Verify if JioSaavn returned tracks matching our anchor title
            final hasMatch = parsedAnchor.any((s) {
              final sTitle = CanonicalSongDedup.cleanTitle(s.title);
              return sTitle == cleanAnchorT ||
                  sTitle.contains(cleanAnchorT) ||
                  cleanAnchorT.contains(sTitle) ||
                  CanonicalSongDedup.stringSimilarity(sTitle, cleanAnchorT) >=
                      0.65;
            });

            if (hasMatch && parsedAnchor.isNotEmpty) {
              jioResults = parsedAnchor;
            }
          }
        } catch (_) {}
      }

      // STEP 4: Fallback to Raw Query on JioSaavn if anchor query returned no matches
      if (jioResults.isEmpty) {
        try {
          final rawJioResp = await http
              .get(ApiConfig.jioSearchUri(query, limit: jioLimit, page: 1))
              .timeout(const Duration(seconds: 6))
              .catchError((_) => http.Response('[]', 500));

          if (rawJioResp.statusCode == 200) {
            jioResults = _parseJioResults(rawJioResp.body, query: query);
          }
        } catch (_) {}
      }

      // Filter genuine studio songs and deduplicate JioSaavn pool
      final genuineJio = CanonicalSongDedup.deduplicateList(
        jioResults.where((v) => CanonicalSongDedup.isGenuineSong(v)).toList(),
      );

      // STEP 5: Extract genuine similar songs, live versions, and variations from YTM
      // Deduplicate YTM tracks (excluding the anchor which is already represented by Jio 320k)
      final List<Video> remainingYtm = ytmResults.length > 1
          ? ytmResults.sublist(1)
          : [];
      final dedupedYtm = CanonicalSongDedup.deduplicateList(
        genuineJio,
        remainingYtm,
      );

      // STEP 6: Combine Studio 320k Audio + Similar Songs from YTM
      final combined = <Video>[...genuineJio, ...dedupedYtm];

      // If JioSaavn returned nothing at all, return all YTM tracks directly
      if (genuineJio.isEmpty && ytmResults.isNotEmpty) {
        final ranked = _rankSearchResults(
          ytmResults,
          query,
          anchorVideo: ytmAnchor,
        );
        unawaited(MusicService().enrichArtworkForSongs(ranked));
        return ranked;
      }

      final ranked = _rankSearchResults(
        combined,
        query,
        anchorVideo: ytmAnchor,
      );

      debugPrint(
        '[StudioSearchService] Resolved "$query": ${genuineJio.length} Jio studio 320k + ${dedupedYtm.length} YTM similar songs',
      );

      // Background artwork enrichment for any incomplete thumbnails
      unawaited(MusicService().enrichArtworkForSongs(ranked));
      return ranked;
    } catch (e) {
      debugPrint('[StudioSearchService] Error searching: $e');
      // Graceful fallback to MusicService.searchSongs
      return MusicService().searchSongs(rawQuery, page: page, limit: limit);
    }
  }

  /// Parses JioSaavn JSON search response and registers artwork, stream URLs, and album metadata.
  List<Video> _parseJioResults(String body, {String? query}) {
    final List<Video> list = [];
    try {
      final List<dynamic> jsonList = json.decode(body);
      for (var item in jsonList) {
        if (item is! Map) continue;
        final songId = item['id'] as String? ?? '';
        if (songId.isEmpty) continue;

        final rawTitle = item['title'] as String? ?? 'Unknown Title';
        final rawAuthor = item['author'] as String? ?? 'DilSe Music';
        final cleanA = CanonicalSongDedup.cleanArtist(rawAuthor);
        final author = cleanA.isNotEmpty ? cleanA : rawAuthor;
        final title = CanonicalSongDedup.sanitizeDisplayTitle(
          rawTitle,
          artist: author,
        );

        final album = item['album'] as String? ?? '';
        final durationSec = item['duration'] != null
            ? int.tryParse(item['duration'].toString())
            : null;
        final duration = durationSec != null
            ? Duration(seconds: durationSec)
            : null;
        final artwork = item['thumbnail'] as String? ?? '';
        final streamUrl = item['streamUrl'] as String? ?? '';

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
        final lang = item['language'] as String? ?? '';
        if (lang.isNotEmpty) {
          CanonicalSongDedup.registerSongLanguage(songId, lang);
          CanonicalSongDedup.registerSongLanguage(vidString, lang);
        }
        final albumId =
            item['album_id']?.toString() ?? item['albumId']?.toString() ?? '';
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

        final video = Video(
          VideoId(vidString),
          title,
          author,
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

        if (CanonicalSongDedup.isGenuineSong(video)) {
          list.add(video);
        }
      }
    } catch (_) {}
    return list;
  }

  /// High-accuracy ranking ensuring exact studio matches and canonical anchors appear at the very top.
  List<Video> _rankSearchResults(
    List<Video> songs,
    String rawQuery, {
    Video? anchorVideo,
  }) {
    if (songs.isEmpty || rawQuery.trim().isEmpty) return songs;

    final cleanPool = songs
        .where((s) => CanonicalSongDedup.isGenuineSong(s))
        .toList();
    final dedupedSongs = CanonicalSongDedup.deduplicateList(cleanPool);

    final q = rawQuery.trim().toLowerCase();
    final cleanQ = CanonicalSongDedup.cleanTitle(rawQuery);

    final cleanAnchorT = anchorVideo != null
        ? CanonicalSongDedup.cleanTitle(anchorVideo.title)
        : '';

    final pool = List<Video>.from(dedupedSongs);
    pool.sort((a, b) {
      final aLower = a.title.toLowerCase().trim();
      final bLower = b.title.toLowerCase().trim();
      final aExact = aLower == q ? 1 : 0;
      final bExact = bLower == q ? 1 : 0;
      if (aExact != bExact) return bExact.compareTo(aExact);

      final cleanAT = CanonicalSongDedup.cleanTitle(a.title);
      final cleanBT = CanonicalSongDedup.cleanTitle(b.title);
      final aCleanExact = cleanAT == cleanQ ? 1 : 0;
      final bCleanExact = cleanBT == cleanQ ? 1 : 0;
      if (aCleanExact != bCleanExact) return bCleanExact.compareTo(aCleanExact);

      // Anchor boost
      if (cleanAnchorT.isNotEmpty) {
        final aAnchorMatch =
            (cleanAT == cleanAnchorT || cleanAT.contains(cleanAnchorT)) ? 1 : 0;
        final bAnchorMatch =
            (cleanBT == cleanAnchorT || cleanBT.contains(cleanAnchorT)) ? 1 : 0;
        if (aAnchorMatch != bAnchorMatch) {
          return bAnchorMatch.compareTo(aAnchorMatch);
        }
      }

      return 0;
    });

    return pool;
  }
}

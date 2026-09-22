import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'api_config.dart';
import 'canonical_song_dedup.dart';

/// Lightweight, keyless client for YouTube Music's InnerTube API (`WEB_REMIX`).
/// Provides studio release songs, clean album art, and Google's 50-track radio mixes.
class YouTubeMusicClient {
  static final YouTubeMusicClient _instance = YouTubeMusicClient._internal();
  factory YouTubeMusicClient() => _instance;
  YouTubeMusicClient._internal();

  static const String _baseUrl = 'https://music.youtube.com/youtubei/v1';

  static const Map<String, String> _headers = {
    'Content-Type': 'application/json',
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36',
    'Origin': 'https://music.youtube.com',
    'Referer': 'https://music.youtube.com/',
  };

  static const Map<String, dynamic> _context = {
    'client': {
      'clientName': 'WEB_REMIX',
      'clientVersion': '1.20240101.01.00',
      'hl': 'en',
      'gl': 'IN',
    }
  };

  /// Searches YouTube Music specifically for official studio songs (no video sketches or dialogue)
  Future<List<Video>> searchSongs(String query, {int limit = 20}) async {
    if (query.trim().isEmpty) return [];

    try {
      final uri = Uri.parse('$_baseUrl/search');
      final payload = {
        'context': _context,
        'query': query.trim(),
        // Song filter parameter to restrict to official studio releases
        'params': 'Eg-KAQwIABAAGAEgASgAMABqChAMEAMQBBAJEAo%3D',
      };

      final response = await http
          .post(uri, headers: _headers, body: json.encode(payload))
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) {
        debugPrint('[YTM] Search returned status: ${response.statusCode}');
        return [];
      }

      final data = json.decode(response.body);
      final List<Video> songs = [];

      // Navigate through InnerTube sections to extract musicResponsiveListItemRenderer items
      final contents = data['contents']?['tabbedSearchResultsRenderer']?['tabs']?[0]
              ?['tabRenderer']?['content']?['sectionListRenderer']?['contents'] ??
          [];

      for (final section in contents) {
        final items = section['musicShelfRenderer']?['contents'] ?? [];
        for (final item in items) {
          final renderer = item['musicResponsiveListItemRenderer'];
          if (renderer == null) continue;

          final song = _parseListItemRenderer(renderer);
          if (song != null) {
            songs.add(song);
            if (songs.length >= limit) break;
          }
        }
        if (songs.length >= limit) break;
      }

      debugPrint('[YTM] Found ${songs.length} clean studio tracks for: "$query"');
      return songs;
    } catch (e) {
      debugPrint('[YTM] Search error: $e');
      return [];
    }
  }

  /// Fetches Google's 50-track smart radio automix for a given [videoId]
  Future<List<Video>> fetchRadioTracks(String videoId, {int limit = 50}) async {
    if (videoId.trim().isEmpty) return [];

    // 1. First try Backend / Cloud Proxy (guarantees CORS bypass on Flutter Web)
    try {
      final proxyUri = ApiConfig.radioUri(videoId, limit: limit);
      final resp = await http.get(proxyUri).timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) {
        final List<dynamic> list = json.decode(resp.body);
        if (list.isNotEmpty) {
          final List<Video> serverTracks = [];
          for (final item in list) {
            final vid = item['id'] as String?;
            if (vid == null || vid.isEmpty || vid == videoId) continue;
            final t = item['title'] as String? ?? 'Unknown Title';
            final a = item['author'] as String? ?? 'Unknown Artist';
            final durSec = item['duration'] != null ? int.tryParse(item['duration'].toString()) : null;
            final track = Video(
              VideoId(vid),
              t,
              a,
              ChannelId('UC0WP5P-fwGlLyO4yOE76T8g'),
              DateTime.now(),
              '',
              null,
              '',
              durSec != null ? Duration(seconds: durSec) : null,
              ThumbnailSet(vid),
              null,
              Engagement(0, null, null),
              false,
            );
            if (CanonicalSongDedup.isGenuineSong(track)) {
              serverTracks.add(track);
            }
          }
          if (serverTracks.isNotEmpty) {
            debugPrint('[YTM] Retrieved ${serverTracks.length} clean radio tracks via backend proxy');
            return serverTracks;
          }
        }
      }
    } catch (e) {
      debugPrint('[YTM] Backend radio proxy failed, trying direct YTM: $e');
    }

    // 2. Direct client-side InnerTube fallback (Mobile / Desktop)
    try {
      final uri = Uri.parse('$_baseUrl/next');
      final payload = {
        'context': _context,
        'videoId': videoId,
        'playlistId': 'RDAMVM$videoId',
      };

      final response = await http
          .post(uri, headers: _headers, body: json.encode(payload))
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) {
        debugPrint('[YTM] Radio returned status: ${response.statusCode}');
        return [];
      }

      final data = json.decode(response.body);
      final tabs = data['contents']?['singleColumnMusicWatchNextResultsRenderer']
              ?['tabbedRenderer']?['watchNextTabbedResultsRenderer']?['tabs'] ??
          [];

      if (tabs.isEmpty) return [];

      final upNextItems = tabs[0]?['tabRenderer']?['content']?['musicQueueRenderer']
              ?['content']?['playlistPanelRenderer']?['contents'] ??
          [];

      final List<Video> radioTracks = [];
      for (final item in upNextItems) {
        final renderer = item['playlistPanelVideoRenderer'];
        if (renderer == null) continue;

        final vid = renderer['videoId'] as String?;
        if (vid == null || vid.isEmpty) continue;

        // Skip current seed song if returned as track 1
        if (vid == videoId && radioTracks.isNotEmpty) continue;

        final titleRuns = renderer['title']?['runs'] as List<dynamic>? ?? [];
        final title = titleRuns.isNotEmpty ? titleRuns[0]['text'] as String? ?? 'Unknown Title' : 'Unknown Title';

        final bylineRuns = renderer['longBylineText']?['runs'] as List<dynamic>? ?? [];
        final author = bylineRuns.isNotEmpty ? bylineRuns[0]['text'] as String? ?? 'Unknown Artist' : 'Unknown Artist';

        final lengthText = renderer['lengthText']?['runs']?[0]?['text'] as String? ?? '';
        final duration = _parseDuration(lengthText);

        final track = Video(
          VideoId(vid),
          title,
          author,
          ChannelId('UC0WP5P-fwGlLyO4yOE76T8g'),
          DateTime.now(),
          '',
          null,
          '',
          duration,
          ThumbnailSet(vid),
          null,
          Engagement(0, null, null),
          false,
        );

        if (CanonicalSongDedup.isGenuineSong(track)) {
          radioTracks.add(track);
        }

        if (radioTracks.length >= limit) break;
      }

      debugPrint('[YTM] Extracted ${radioTracks.length} radio automix tracks for seed: $videoId');
      return radioTracks;
    } catch (e) {
      debugPrint('[YTM] Radio fetch error: $e');
      return [];
    }
  }

  Video? _parseListItemRenderer(Map<String, dynamic> renderer) {
    try {
      final flexColumns = renderer['flexColumns'] as List<dynamic>? ?? [];
      if (flexColumns.isEmpty) return null;

      // 1. Title
      final titleColumn = flexColumns[0]['musicResponsiveListItemFlexColumnRenderer'];
      final titleRuns = titleColumn?['text']?['runs'] as List<dynamic>? ?? [];
      if (titleRuns.isEmpty) return null;
      final title = titleRuns[0]['text'] as String? ?? 'Unknown Title';

      // 2. VideoId & Navigation
      String? videoId;
      final playNav = renderer['overlay']?['musicItemThumbnailOverlayRenderer']
          ?['content']?['musicPlayButtonRenderer']?['playNavigationEndpoint'];
      videoId = playNav?['watchEndpoint']?['videoId'] as String?;

      if (videoId == null) {
        final titleNav = titleRuns[0]['navigationEndpoint'];
        videoId = titleNav?['watchEndpoint']?['videoId'] as String?;
      }

      if (videoId == null || videoId.isEmpty) return null;

      // 3. Artist & Duration
      String author = 'Unknown Artist';
      Duration? duration;

      if (flexColumns.length > 1) {
        final subColumn = flexColumns[1]['musicResponsiveListItemFlexColumnRenderer'];
        final subRuns = subColumn?['text']?['runs'] as List<dynamic>? ?? [];
        if (subRuns.isNotEmpty) {
          author = subRuns[0]['text'] as String? ?? 'Unknown Artist';
        }

        // Duration is often the last text run
        if (subRuns.length > 2) {
          final lastText = subRuns.last['text'] as String? ?? '';
          duration = _parseDuration(lastText);
        }
      }

      return Video(
        VideoId(videoId),
        title,
        author,
        ChannelId('UC0WP5P-fwGlLyO4yOE76T8g'),
        DateTime.now(),
        '',
        null,
        '',
        duration,
        ThumbnailSet(videoId),
        null,
        Engagement(0, null, null),
        false,
      );
    } catch (_) {
      return null;
    }
  }

  Duration? _parseDuration(String text) {
    if (text.isEmpty) return null;
    final parts = text.trim().split(':');
    if (parts.length == 2) {
      final m = int.tryParse(parts[0]) ?? 0;
      final s = int.tryParse(parts[1]) ?? 0;
      return Duration(minutes: m, seconds: s);
    } else if (parts.length == 3) {
      final h = int.tryParse(parts[0]) ?? 0;
      final m = int.tryParse(parts[1]) ?? 0;
      final s = int.tryParse(parts[2]) ?? 0;
      return Duration(hours: h, minutes: m, seconds: s);
    }
    return null;
  }
}

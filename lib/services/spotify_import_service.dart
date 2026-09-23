import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:archive/archive.dart';
import 'canonical_song_dedup.dart';
import 'music_service.dart';
import 'preferences_service.dart';

/// Represents a track exported from Spotify via Exportify or similar CSV tools
class ExportifyTrack {
  final String spotifyId;
  final String trackName;
  final String artistName;
  final String albumName;
  final int durationMs;
  final double danceability;
  final double energy;
  final double valence;
  final double tempo;
  final double acousticness;
  final double instrumentalness;
  final int popularity;

  ExportifyTrack({
    required this.spotifyId,
    required this.trackName,
    required this.artistName,
    required this.albumName,
    this.durationMs = 0,
    this.danceability = 0.5,
    this.energy = 0.5,
    this.valence = 0.5,
    this.tempo = 120.0,
    this.acousticness = 0.5,
    this.instrumentalness = 0.0,
    this.popularity = 50,
  });

  Map<String, dynamic> toJson() => {
        'spotifyId': spotifyId,
        'trackName': trackName,
        'artistName': artistName,
        'albumName': albumName,
        'durationMs': durationMs,
        'danceability': danceability,
        'energy': energy,
        'valence': valence,
        'tempo': tempo,
        'acousticness': acousticness,
        'instrumentalness': instrumentalness,
        'popularity': popularity,
      };

  factory ExportifyTrack.fromJson(Map<String, dynamic> json) => ExportifyTrack(
        spotifyId: json['spotifyId'] as String? ?? '',
        trackName: json['trackName'] as String? ?? '',
        artistName: json['artistName'] as String? ?? '',
        albumName: json['albumName'] as String? ?? '',
        durationMs: (json['durationMs'] as num?)?.toInt() ?? 0,
        danceability: (json['danceability'] as num?)?.toDouble() ?? 0.5,
        energy: (json['energy'] as num?)?.toDouble() ?? 0.5,
        valence: (json['valence'] as num?)?.toDouble() ?? 0.5,
        tempo: (json['tempo'] as num?)?.toDouble() ?? 120.0,
        acousticness: (json['acousticness'] as num?)?.toDouble() ?? 0.5,
        instrumentalness: (json['instrumentalness'] as num?)?.toDouble() ?? 0.0,
        popularity: (json['popularity'] as num?)?.toInt() ?? 50,
      );
}

/// Represents a distinct playlist extracted from an Exportify CSV or ZIP archive
class ExportifyPlaylist {
  final String name;
  final List<ExportifyTrack> tracks;
  bool isSelected;

  ExportifyPlaylist({
    required this.name,
    required this.tracks,
    this.isSelected = true,
  });

  double get avgEnergy {
    if (tracks.isEmpty) return 0.5;
    return tracks.map((t) => t.energy).reduce((a, b) => a + b) / tracks.length;
  }

  double get avgValence {
    if (tracks.isEmpty) return 0.5;
    return tracks.map((t) => t.valence).reduce((a, b) => a + b) / tracks.length;
  }

  double get avgDanceability {
    if (tracks.isEmpty) return 0.5;
    return tracks.map((t) => t.danceability).reduce((a, b) => a + b) / tracks.length;
  }

  double get avgTempo {
    if (tracks.isEmpty) return 120.0;
    return tracks.map((t) => t.tempo).reduce((a, b) => a + b) / tracks.length;
  }
}

/// User's consolidated acoustic feature profile derived from their music library
class UserAudioProfile {
  final double avgDanceability;
  final double avgEnergy;
  final double avgValence;
  final double avgTempo;
  final double avgAcousticness;
  final int tracksAnalyzed;

  const UserAudioProfile({
    this.avgDanceability = 0.5,
    this.avgEnergy = 0.5,
    this.avgValence = 0.5,
    this.avgTempo = 110.0,
    this.avgAcousticness = 0.5,
    this.tracksAnalyzed = 0,
  });

  Map<String, dynamic> toJson() => {
        'avgDanceability': avgDanceability,
        'avgEnergy': avgEnergy,
        'avgValence': avgValence,
        'avgTempo': avgTempo,
        'avgAcousticness': avgAcousticness,
        'tracksAnalyzed': tracksAnalyzed,
      };

  factory UserAudioProfile.fromJson(Map<String, dynamic> json) => UserAudioProfile(
        avgDanceability: (json['avgDanceability'] as num?)?.toDouble() ?? 0.5,
        avgEnergy: (json['avgEnergy'] as num?)?.toDouble() ?? 0.5,
        avgValence: (json['avgValence'] as num?)?.toDouble() ?? 0.5,
        avgTempo: (json['avgTempo'] as num?)?.toDouble() ?? 110.0,
        avgAcousticness: (json['avgAcousticness'] as num?)?.toDouble() ?? 0.5,
        tracksAnalyzed: (json['tracksAnalyzed'] as num?)?.toInt() ?? 0,
      );
}

/// High-performance RFC 4180 CSV parser tailored for Exportify exports
class ExportifyCsvParser {
  /// Parses an Exportify .zip export archive containing multiple playlist CSVs
  static List<ExportifyPlaylist> parseZipBytes(List<int> zipBytes) {
    try {
      final archive = ZipDecoder().decodeBytes(zipBytes);
      final playlists = <ExportifyPlaylist>[];

      for (final file in archive) {
        if (file.isFile && file.name.toLowerCase().endsWith('.csv')) {
          String rawName = file.name;
          if (rawName.contains('/')) rawName = rawName.split('/').last;
          if (rawName.contains(r'\')) rawName = rawName.split(r'\').last;
          final cleanName = rawName.replaceAll(RegExp(r'\.csv$', caseSensitive: false), '').trim();
          if (cleanName.isEmpty) continue;

          final contentBytes = file.content as List<int>;
          final contentStr = utf8.decode(contentBytes, allowMalformed: true);
          final tracks = parse(contentStr);
          if (tracks.isNotEmpty) {
            playlists.add(ExportifyPlaylist(name: cleanName, tracks: tracks));
          }
        }
      }
      return playlists;
    } catch (e) {
      debugPrint('[ExportifyParser] Error decoding zip archive: $e');
      return [];
    }
  }

  /// Parses standard Exportify CSV text content into a list of [ExportifyTrack]
  static List<ExportifyTrack> parse(String csvContent) {
    if (csvContent.trim().isEmpty) return [];

    // Strip UTF-8 Byte Order Mark if present (common in Excel/Windows exports)
    String cleanCsv = csvContent;
    if (cleanCsv.startsWith('\uFEFF')) {
      cleanCsv = cleanCsv.substring(1);
    }

    final lines = _splitCsvLines(cleanCsv);
    if (lines.isEmpty) return [];

    final headerTokens = _parseCsvRow(lines[0]);
    final columnMap = <String, int>{};

    for (int i = 0; i < headerTokens.length; i++) {
      final token = headerTokens[i].toLowerCase().trim();
      columnMap[token] = i;
    }

    // Dynamic column index resolution
    final trackNameIdx = _findColumnIndex(columnMap, ['track name', 'track', 'song', 'title', 'name']);
    final artistIdx = _findColumnIndex(columnMap, ['artist name(s)', 'artist name', 'artist', 'artists']);
    final albumIdx = _findColumnIndex(columnMap, ['album name', 'album']);
    final durationIdx = _findColumnIndex(columnMap, ['track duration (ms)', 'duration (ms)', 'duration', 'duration_ms']);
    final spotifyIdIdx = _findColumnIndex(columnMap, ['spotify id', 'track uri', 'spotify uri', 'id', 'uri']);
    final danceIdx = _findColumnIndex(columnMap, ['danceability']);
    final energyIdx = _findColumnIndex(columnMap, ['energy']);
    final valenceIdx = _findColumnIndex(columnMap, ['valence']);
    final tempoIdx = _findColumnIndex(columnMap, ['tempo']);
    final acousticIdx = _findColumnIndex(columnMap, ['acousticness']);
    final instrumentalIdx = _findColumnIndex(columnMap, ['instrumentalness']);
    final popularityIdx = _findColumnIndex(columnMap, ['popularity']);

    if (trackNameIdx == -1 && artistIdx == -1) {
      debugPrint('[ExportifyParser] Warning: CSV missing required Track Name or Artist columns');
      return [];
    }

    final tracks = <ExportifyTrack>[];

    for (int r = 1; r < lines.length; r++) {
      final line = lines[r].trim();
      if (line.isEmpty) continue;

      final row = _parseCsvRow(line);
      if (row.isEmpty) continue;

      final trackName = _getValue(row, trackNameIdx, defaultValue: 'Unknown Track');
      final artistName = _getValue(row, artistIdx, defaultValue: 'Unknown Artist');
      if (trackName.isEmpty && artistName.isEmpty) continue;

      final albumName = _getValue(row, albumIdx, defaultValue: '');
      final spotifyId = _getValue(row, spotifyIdIdx, defaultValue: '');

      final durationMs = int.tryParse(_getValue(row, durationIdx, defaultValue: '0')) ?? 0;
      final danceability = double.tryParse(_getValue(row, danceIdx, defaultValue: '0.5')) ?? 0.5;
      final energy = double.tryParse(_getValue(row, energyIdx, defaultValue: '0.5')) ?? 0.5;
      final valence = double.tryParse(_getValue(row, valenceIdx, defaultValue: '0.5')) ?? 0.5;
      final tempo = double.tryParse(_getValue(row, tempoIdx, defaultValue: '120.0')) ?? 120.0;
      final acousticness = double.tryParse(_getValue(row, acousticIdx, defaultValue: '0.5')) ?? 0.5;
      final instrumentalness = double.tryParse(_getValue(row, instrumentalIdx, defaultValue: '0.0')) ?? 0.0;
      final popularity = int.tryParse(_getValue(row, popularityIdx, defaultValue: '50')) ?? 50;

      tracks.add(ExportifyTrack(
        spotifyId: spotifyId,
        trackName: trackName,
        artistName: artistName,
        albumName: albumName,
        durationMs: durationMs,
        danceability: danceability.clamp(0.0, 1.0),
        energy: energy.clamp(0.0, 1.0),
        valence: valence.clamp(0.0, 1.0),
        tempo: tempo.clamp(40.0, 240.0),
        acousticness: acousticness.clamp(0.0, 1.0),
        instrumentalness: instrumentalness.clamp(0.0, 1.0),
        popularity: popularity.clamp(0, 100),
      ));
    }

    return tracks;
  }

  static int _findColumnIndex(Map<String, int> map, List<String> aliases) {
    for (final alias in aliases) {
      if (map.containsKey(alias)) return map[alias]!;
      for (final entry in map.entries) {
        if (entry.key.contains(alias)) return entry.value;
      }
    }
    return -1;
  }

  static String _getValue(List<String> row, int index, {String defaultValue = ''}) {
    if (index >= 0 && index < row.length) {
      return row[index].trim();
    }
    return defaultValue;
  }

  /// Splits lines while respecting multi-line values enclosed in quotes
  static List<String> _splitCsvLines(String text) {
    final lines = <String>[];
    final buffer = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      if (char == '"') {
        inQuotes = !inQuotes;
        buffer.write(char);
      } else if ((char == '\n' || char == '\r') && !inQuotes) {
        if (char == '\r' && i + 1 < text.length && text[i + 1] == '\n') {
          i++; // Skip \n in \r\n
        }
        if (buffer.isNotEmpty) {
          lines.add(buffer.toString());
          buffer.clear();
        }
      } else {
        buffer.write(char);
      }
    }

    if (buffer.isNotEmpty) {
      lines.add(buffer.toString());
    }

    return lines;
  }

  /// Parses a single CSV row into fields respecting commas inside quotes and escaped quotes
  static List<String> _parseCsvRow(String line) {
    final fields = <String>[];
    final buffer = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final char = line[i];

      if (char == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          buffer.write('"'); // Escaped double quote ("")
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == ',' && !inQuotes) {
        fields.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }
    fields.add(buffer.toString());
    return fields;
  }
}

/// Service that coordinates high-performance background Exportify CSV ingestion,
/// Taste Matrix calibration, and concurrent 320kbps studio track resolution with JioSaavn.
/// Extends ChangeNotifier so UI screens and global banners can observe live progress.
class SpotifyImportService extends ChangeNotifier {
  static final SpotifyImportService _instance = SpotifyImportService._internal();
  factory SpotifyImportService() => _instance;
  SpotifyImportService._internal();

  final MusicService _musicService = MusicService();
  final PreferencesService _prefs = PreferencesService();

  // --- Background Observable State ---
  bool _isImporting = false;
  bool get isImporting => _isImporting;

  int _totalPlaylists = 0;
  int get totalPlaylists => _totalPlaylists;

  int _completedPlaylists = 0;
  int get completedPlaylists => _completedPlaylists;

  int _totalTracks = 0;
  int get totalTracks => _totalTracks;

  int _processedTracks = 0;
  int get processedTracks => _processedTracks;

  int _resolvedTracks = 0;
  int get resolvedTracks => _resolvedTracks;

  String _currentPlaylistName = '';
  String get currentPlaylistName => _currentPlaylistName;

  String _currentTrackName = '';
  String get currentTrackName => _currentTrackName;

  double _overallProgress = 0.0;
  double get overallProgress => _overallProgress;

  String _statusMessage = '';
  String get statusMessage => _statusMessage;

  bool _isCancelled = false;
  bool get isCancelled => _isCancelled;

  bool _hasFinished = false;
  bool get hasFinished => _hasFinished;

  String? _lastImportedPlaylistId;
  String? get lastImportedPlaylistId => _lastImportedPlaylistId;

  String? _lastImportedPlaylistName;
  String? get lastImportedPlaylistName => _lastImportedPlaylistName;

  int _lastSuccessCount = 0;
  int get lastSuccessCount => _lastSuccessCount;

  int _lastTotalCount = 0;
  int get lastTotalCount => _lastTotalCount;

  List<Map<String, dynamic>> _lastImportedPlaylists = [];
  List<Map<String, dynamic>> get lastImportedPlaylists => List.unmodifiable(_lastImportedPlaylists);

  // Cross-playlist deduplication query cache (0ms instant resolution for overlapping tracks)
  final Map<String, Video?> _resolvedTrackCache = {};
  int _cacheHitCount = 0;
  int get cacheHitCount => _cacheHitCount;

  void clearCache() {
    _resolvedTrackCache.clear();
    _cacheHitCount = 0;
  }

  void cancelImport() {
    if (_isImporting && !_isCancelled) {
      _isCancelled = true;
      _statusMessage = 'Cancelling import... Saving loaded tracks...';
      notifyListeners();
    }
  }

  void resetFinishedState() {
    _hasFinished = false;
    _lastImportedPlaylistId = null;
    _lastImportedPlaylistName = null;
    notifyListeners();
  }

  static String _normalizeTrackKey(String title, String artist) {
    final cleanTitle = title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final cleanArtist = artist.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    return '${cleanTitle}_$cleanArtist';
  }

  /// High-performance concurrent resolver with in-memory caching and order preservation
  Future<List<Video>> resolveTracksConcurrently({
    required List<ExportifyTrack> tracks,
    int concurrency = 8,
    void Function(int completed, String songTitle)? onProgress,
    void Function(List<Video> currentResolvedSongs)? onSongsUpdated,
  }) async {
    if (tracks.isEmpty) return [];
    final results = List<Video?>.filled(tracks.length, null);
    int nextIndex = 0;
    int completedCount = 0;
    int lastFlushedCount = 0;

    Future<void> worker() async {
      while (true) {
        if (_isCancelled) break;
        int i;
        if (nextIndex >= tracks.length) break;
        i = nextIndex++;

        final track = tracks[i];
        final key = _normalizeTrackKey(track.trackName, track.artistName);

        Video? song;
        if (_resolvedTrackCache.containsKey(key)) {
          song = _resolvedTrackCache[key];
          _cacheHitCount++;
        } else {
          final query = '${track.trackName} ${track.artistName}'.trim();
          try {
            final searchResults = await _musicService.searchSongs(query, page: 1);
            if (searchResults.isNotEmpty) {
              song = searchResults.firstWhere(
                (v) => CanonicalSongDedup.isGenuineSong(v),
                orElse: () => searchResults.first,
              );
            }
          } catch (e) {
            debugPrint('[SpotifyImport] Search error for "$query": $e');
          }
          _resolvedTrackCache[key] = song;
        }

        results[i] = song;
        completedCount++;
        onProgress?.call(completedCount, track.trackName);

        // Periodically flush resolved songs (every 5 new tracks or when cancelled) to keep playlist live
        if (onSongsUpdated != null && (completedCount - lastFlushedCount >= 5 || _isCancelled)) {
          lastFlushedCount = completedCount;
          final current = results.whereType<Video>().toList();
          onSongsUpdated(current);
        }

        // Polite 20ms stagger between worker iterations to avoid sudden rate limits
        await Future.delayed(const Duration(milliseconds: 20));
      }
    }

    final poolSize = concurrency.clamp(1, tracks.length);
    final workers = List.generate(poolSize, (_) => worker());
    await Future.wait(workers);

    final finalResolved = results.whereType<Video>().toList();
    if (onSongsUpdated != null) {
      onSongsUpdated(finalResolved);
    }

    return finalResolved;
  }

  /// Starts persistent background import for a single Exportify CSV
  Future<void> startBackgroundSingleImport({
    required String playlistName,
    required List<ExportifyTrack> tracks,
    bool calibrateTaste = true,
  }) async {
    if (_isImporting) return;
    _isImporting = true;
    _isCancelled = false;
    _hasFinished = false;
    _totalPlaylists = 1;
    _completedPlaylists = 0;
    _totalTracks = tracks.length;
    _processedTracks = 0;
    _resolvedTracks = 0;
    _currentPlaylistName = playlistName;
    _currentTrackName = '';
    _overallProgress = 0.05;
    _statusMessage = 'Calibrating Taste Matrix...';
    _lastImportedPlaylists = [];
    notifyListeners();

    try {
      if (calibrateTaste && tracks.isNotEmpty) {
        await _prefs.importExportifyTasteData(tracks);
      }

      final cleanName = playlistName.trim().isNotEmpty ? playlistName.trim() : 'Exportify Mix';
      final pid = _musicService.createPlaylist(cleanName);

      final resolved = await resolveTracksConcurrently(
        tracks: tracks,
        concurrency: 8,
        onProgress: (done, title) {
          _processedTracks = done;
          _currentTrackName = title;
          _overallProgress = (_processedTracks / (_totalTracks > 0 ? _totalTracks : 1)).clamp(0.05, 0.99);
          _statusMessage = 'Matching $done of $_totalTracks studio tracks:\n"$title"';
          notifyListeners();
        },
        onSongsUpdated: (currentSongs) {
          _resolvedTracks = currentSongs.length;
          _musicService.setPlaylistSongs(pid, currentSongs, commit: true);
        },
      );

      if (resolved.isNotEmpty) {
        _musicService.setPlaylistSongs(pid, resolved, commit: true);
        _resolvedTracks = resolved.length;
        _completedPlaylists = 1;
        _lastImportedPlaylistId = pid;
        _lastImportedPlaylistName = cleanName;
        _lastSuccessCount = resolved.length;
        _lastTotalCount = tracks.length;
        _statusMessage = _isCancelled
            ? 'Import cancelled. Saved ${resolved.length} tracks into "$cleanName".'
            : 'Successfully imported ${resolved.length} of ${tracks.length} tracks into "$cleanName"!';
      } else if (_isCancelled) {
        await _musicService.deletePlaylist(pid);
        _lastImportedPlaylistId = null;
        _lastImportedPlaylistName = null;
        _lastSuccessCount = 0;
        _statusMessage = 'Import cancelled. No tracks were loaded.';
      }
      _hasFinished = true;
      _overallProgress = 1.0;
    } catch (e) {
      _statusMessage = 'Import error: $e';
    } finally {
      _isImporting = false;
      notifyListeners();
    }
  }

  /// Starts persistent background import for multiple playlists extracted from a .zip file.
  /// 1. Calibrates Taste Matrix across entire library in <100ms
  /// 2. Creates playlists on-demand as each playlist import begins (no empty ghost playlists)
  /// 3. Concurrently resolves tracks (8 workers) with cross-playlist caching
  /// 4. Streams resolved songs in real-time and commits on cancel so zero loaded tracks are lost
  Future<void> startBackgroundMultiImport({
    required List<ExportifyPlaylist> playlists,
    bool calibrateTaste = true,
  }) async {
    if (_isImporting) return;
    _isImporting = true;
    _isCancelled = false;
    _hasFinished = false;
    _totalPlaylists = playlists.length;
    _completedPlaylists = 0;
    _totalTracks = playlists.fold<int>(0, (sum, p) => sum + p.tracks.length);
    _processedTracks = 0;
    _resolvedTracks = 0;
    _currentPlaylistName = 'Calibrating Taste Matrix...';
    _currentTrackName = '';
    _overallProgress = 0.02;
    _statusMessage = 'Calibrating Taste Matrix across ${playlists.length} playlists ($_totalTracks tracks)...';
    _lastImportedPlaylists = [];
    notifyListeners();

    try {
      // 1. Instant taste calibration across entire library
      if (calibrateTaste) {
        final allTracks = playlists.expand((p) => p.tracks).toList();
        if (allTracks.isNotEmpty) {
          await _prefs.importExportifyTasteData(allTracks);
        }
      }

      _overallProgress = 0.05;
      notifyListeners();

      // 2. High-speed concurrent resolution across playlists
      for (int pIdx = 0; pIdx < playlists.length; pIdx++) {
        if (_isCancelled) break;
        final pl = playlists[pIdx];
        _currentPlaylistName = pl.name;
        notifyListeners();

        // Create playlist on demand as it starts
        final pid = _musicService.createPlaylist(pl.name);

        int prevProcessedBeforeThisPl = _processedTracks;
        final resolvedThisPl = await resolveTracksConcurrently(
          tracks: pl.tracks,
          concurrency: 8,
          onProgress: (doneInPl, title) {
            _processedTracks = prevProcessedBeforeThisPl + doneInPl;
            _currentTrackName = title;
            _overallProgress = (_processedTracks / (_totalTracks > 0 ? _totalTracks : 1)).clamp(0.05, 0.99);
            _statusMessage = 'Playlist ${pIdx + 1} of ${playlists.length} ("${pl.name}")\nSong $doneInPl of ${pl.tracks.length}: "$title"';
            notifyListeners();
          },
          onSongsUpdated: (currentSongs) {
            _musicService.setPlaylistSongs(pid, currentSongs, commit: true);
          },
        );

        if (resolvedThisPl.isNotEmpty) {
          // Always commit all resolved songs so far to the playlist
          _musicService.setPlaylistSongs(pid, resolvedThisPl, commit: true);
          _resolvedTracks += resolvedThisPl.length;
          _completedPlaylists++;

          _lastImportedPlaylists.add({
            'id': pid,
            'name': pl.name,
            'total': pl.tracks.length,
            'resolved': resolvedThisPl.length,
          });
        } else if (_isCancelled) {
          // If cancelled before even 1 song was resolved in this playlist, delete empty playlist
          await _musicService.deletePlaylist(pid);
        }

        if (_isCancelled) break;
        notifyListeners();
      }

      _hasFinished = true;
      _overallProgress = 1.0;
      if (_lastImportedPlaylists.isNotEmpty) {
        _lastImportedPlaylistId = _lastImportedPlaylists.first['id'] as String?;
        _lastImportedPlaylistName = _lastImportedPlaylists.length == 1
            ? _lastImportedPlaylists.first['name'] as String?
            : '${_lastImportedPlaylists.length} Playlists';
      }
      _lastSuccessCount = _resolvedTracks;
      _lastTotalCount = _totalTracks;
      _statusMessage = _isCancelled
          ? 'Import stopped. Saved $_completedPlaylists playlists ($_resolvedTracks songs).'
          : 'Successfully imported ${playlists.length} playlists ($_resolvedTracks of $_totalTracks songs)!';
    } catch (e) {
      _statusMessage = 'Import error: $e';
    } finally {
      _isImporting = false;
      notifyListeners();
    }
  }

  /// Starts persistent background import for a Spotify URL
  Future<void> startBackgroundUrlImport({
    required String playlistId,
    required String playlistName,
    required List<String> rawTrackQueries,
  }) async {
    if (_isImporting) return;
    _isImporting = true;
    _isCancelled = false;
    _hasFinished = false;
    _totalPlaylists = 1;
    _completedPlaylists = 0;
    _totalTracks = rawTrackQueries.length;
    _processedTracks = 0;
    _resolvedTracks = 0;
    _currentPlaylistName = playlistName;
    _currentTrackName = '';
    _overallProgress = 0.05;
    _statusMessage = 'Starting Spotify URL import for "$playlistName"...';
    _lastImportedPlaylists = [];
    notifyListeners();

    try {
      final cleanName = playlistName.trim().isNotEmpty ? playlistName.trim() : 'Spotify Playlist';
      final pid = _musicService.createPlaylist(cleanName);
      final tracks = rawTrackQueries.map((q) => ExportifyTrack(
        spotifyId: '',
        trackName: q,
        artistName: '',
        albumName: '',
      )).toList();

      final resolved = await resolveTracksConcurrently(
        tracks: tracks,
        concurrency: 8,
        onProgress: (done, title) {
          _processedTracks = done;
          _currentTrackName = title;
          _overallProgress = (_processedTracks / (_totalTracks > 0 ? _totalTracks : 1)).clamp(0.05, 0.99);
          _statusMessage = 'Matching $done of $_totalTracks tracks:\n"$title"';
          notifyListeners();
        },
        onSongsUpdated: (currentSongs) {
          _resolvedTracks = currentSongs.length;
          _musicService.setPlaylistSongs(pid, currentSongs, commit: true);
        },
      );

      if (resolved.isNotEmpty) {
        _musicService.setPlaylistSongs(pid, resolved, commit: true);
        _resolvedTracks = resolved.length;
        _completedPlaylists = 1;
        _lastImportedPlaylistId = pid;
        _lastImportedPlaylistName = cleanName;
        _lastSuccessCount = resolved.length;
        _lastTotalCount = rawTrackQueries.length;
        _statusMessage = _isCancelled
            ? 'Import cancelled. Saved ${resolved.length} tracks into "$cleanName".'
            : 'Successfully imported ${resolved.length} of ${rawTrackQueries.length} tracks into "$cleanName"!';
      } else if (_isCancelled) {
        await _musicService.deletePlaylist(pid);
        _lastImportedPlaylistId = null;
        _lastImportedPlaylistName = null;
        _lastSuccessCount = 0;
        _statusMessage = 'Import cancelled. No tracks were loaded.';
      }
      _hasFinished = true;
      _overallProgress = 1.0;
    } catch (e) {
      _statusMessage = 'Import error: $e';
    } finally {
      _isImporting = false;
      notifyListeners();
    }
  }

  /// Resolves Exportify tracks against JioSaavn 320kbps studio catalog (backwards compatibility)
  Future<List<Video>> batchResolveToJioSaavn(
    List<ExportifyTrack> tracks, {
    Function(int current, int total, String songTitle)? onProgress,
    bool stopOnError = false,
  }) async {
    return resolveTracksConcurrently(
      tracks: tracks,
      concurrency: 8,
      onProgress: (completed, title) {
        onProgress?.call(completed, tracks.length, title);
      },
    );
  }

  /// Complete one-step ingestion for a single playlist (backwards compatibility)
  Future<Map<String, dynamic>> importAndCalibrate({
    required String playlistName,
    required List<ExportifyTrack> tracks,
    Function(int current, int total, String songTitle)? onProgress,
  }) async {
    await startBackgroundSingleImport(
      playlistName: playlistName,
      tracks: tracks,
      calibrateTaste: true,
    );
    return {
      'playlistId': _lastImportedPlaylistId,
      'playlistName': _lastImportedPlaylistName,
      'totalTracks': _lastTotalCount,
      'successCount': _lastSuccessCount,
      'audioProfile': _prefs.audioProfile,
    };
  }

  /// Batch imports multiple playlists extracted from a .zip file (backwards compatibility)
  Future<Map<String, dynamic>> importMultiplePlaylists({
    required List<ExportifyPlaylist> playlists,
    required bool calibrateTaste,
    Function(int currentPlaylist, int totalPlaylists, int currentTrack, int totalTracksInPlaylist, String trackName)? onProgress,
  }) async {
    await startBackgroundMultiImport(
      playlists: playlists,
      calibrateTaste: calibrateTaste,
    );
    return {
      'playlists': _lastImportedPlaylists,
      'totalPlaylists': _totalPlaylists,
      'grandTotalResolved': _resolvedTracks,
      'totalTracks': _totalTracks,
      'audioProfile': _prefs.audioProfile,
    };
  }
}

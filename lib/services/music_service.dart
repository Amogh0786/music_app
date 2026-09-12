import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:palette_generator/palette_generator.dart';
import 'preferences_service.dart';

class MusicService extends ChangeNotifier {
  static final MusicService _instance = MusicService._internal();
  factory MusicService() => _instance;

  MusicService._internal() {
    _initAudioPlayer();
    loadDownloadedSongs();
  }

  final YoutubeExplode _yt = YoutubeExplode();
  final AudioPlayer _audioPlayer = AudioPlayer();

  Video? _currentSong;
  List<Video> _playlist = [];
  int _currentIndex = 0;
  bool _isLoading = false;
  bool _isShuffle = false;
  LoopMode _loopMode = LoopMode.off;
  List<Map<String, String>> _likedSongs = [];

  String? _cachedLyrics;
  String? _cachedLyricsSongId;
  bool _isFetchingLyrics = false;

  // Palette Extraction
  Color _dominantColor = const Color(0xFF1E1E2C);
  Color _vibrantColor = const Color(0xFFFA2D48);

  // Sleep Timer
  Timer? _sleepTimer;
  Timer? _sleepCountdownTimer;
  Duration? _sleepRemaining;
  bool _stopAtEndOfTrack = false;

  Video? get currentSong => _currentSong;
  List<Video> get playlist => _playlist;
  int get currentIndex => _currentIndex;
  bool get isLoading => _isLoading;
  bool get isShuffle => _isShuffle;
  LoopMode get loopMode => _loopMode;
  List<Map<String, String>> get likedSongs => _likedSongs;
  AudioPlayer get audioPlayer => _audioPlayer;
  String? get cachedLyrics => _cachedLyrics;
  bool get isFetchingLyrics => _isFetchingLyrics;

  Color get dominantColor => _dominantColor;
  Color get vibrantColor => _vibrantColor;

  bool get isSleepTimerActive => _sleepTimer != null || _stopAtEndOfTrack;
  Duration? get sleepRemaining => _sleepRemaining;
  bool get stopAtEndOfTrack => _stopAtEndOfTrack;

  String get sleepTimerLabel {
    if (_stopAtEndOfTrack) return 'End of Track';
    if (_sleepRemaining != null) {
      final mins = _sleepRemaining!.inMinutes;
      final secs = _sleepRemaining!.inSeconds.remainder(60).toString().padLeft(2, '0');
      return '$mins:$secs';
    }
    return 'Off';
  }

  Future<void> fetchLyrics(Video song) async {
    if (_cachedLyricsSongId == song.id.value && _cachedLyrics != null) return;

    _isFetchingLyrics = true;
    _cachedLyrics = null;
    _cachedLyricsSongId = song.id.value;
    notifyListeners();

    try {
      final title = song.title.replaceAll(RegExp(r'\(.*?\)|\[.*?\]'), '').trim();
      final artist = song.author.replaceAll(' - Topic', '').trim();
      final url = Uri.parse('https://lrclib.net/api/search?q=${Uri.encodeComponent("$title $artist")}');

      final response = await http.get(url, headers: {'User-Agent': 'Mozilla/5.0'}).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final List<dynamic> results = json.decode(response.body);
        if (results.isNotEmpty) {
          final first = results.first;
          _cachedLyrics = first['plainLyrics'] ?? first['syncedLyrics'] ?? 'No lyrics available.';
        } else {
          _cachedLyrics = 'No lyrics found for this track.';
        }
      } else {
        _cachedLyrics = 'No lyrics available.';
      }
    } catch (e) {
      _cachedLyrics = 'No lyrics available for this track.';
    } finally {
      _isFetchingLyrics = false;
      notifyListeners();
    }
  }

  static String getHdThumbnail(String videoId) {
    return 'https://i.ytimg.com/vi/$videoId/maxresdefault.jpg';
  }

  bool _isTransitioning = false;
  bool _isFetchingNextQueue = false;

  void _initAudioPlayer() {
    _audioPlayer.playerStateStream.listen((state) async {
      if (state.processingState == ProcessingState.completed) {
        if (_isTransitioning) return;
        _isTransitioning = true;
        debugPrint('[AudioPlayer] Track completed. Advancing to next song…');
        try {
          await nextSong();
        } catch (e) {
          debugPrint('[AudioPlayer] Error advancing song on completion: $e');
        } finally {
          _isTransitioning = false;
        }
      }
    });
    loadLikedSongs();
  }

  Future<void> loadLikedSongs() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/liked_songs.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        final List<dynamic> jsonList = json.decode(content);
        _likedSongs = jsonList.map((e) => Map<String, String>.from(e)).toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading liked songs: $e');
    }
  }

  void toggleLike(Video song) async {
    final exists = _likedSongs.any((s) => s['id'] == song.id.value);
    if (exists) {
      _likedSongs.removeWhere((s) => s['id'] == song.id.value);
    } else {
      _likedSongs.add({
        'id': song.id.value,
        'title': song.title,
        'author': song.author,
        'thumbnail': getHdThumbnail(song.id.value),
      });
    }
    notifyListeners();

    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/liked_songs.json');
      await file.writeAsString(json.encode(_likedSongs));
    } catch (e) {
      debugPrint('Error saving liked songs: $e');
    }
  }

  void seekRelative(Duration offset) {
    final current = _audioPlayer.position;
    final target = current + offset;
    _audioPlayer.seek(target);
  }

  void toggleShuffle() {
    _isShuffle = !_isShuffle;
    _audioPlayer.setShuffleModeEnabled(_isShuffle);
    notifyListeners();
  }

  void toggleRepeat() {
    if (_loopMode == LoopMode.off) {
      _loopMode = LoopMode.all;
    } else if (_loopMode == LoopMode.all) {
      _loopMode = LoopMode.one;
    } else {
      _loopMode = LoopMode.off;
    }
    _audioPlayer.setLoopMode(_loopMode);
    notifyListeners();
  }

  Future<List<Video>> searchSongs(String query, {int page = 1}) async {
    if (query.trim().isEmpty) return [];

    try {
      final response = await http
          .get(Uri.parse('http://10.0.2.2:8000/search?q=${Uri.encodeComponent(query)}&page=$page&limit=20'))
          .timeout(const Duration(seconds: 10));


      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(response.body);
        final List<Video> results = [];

        for (var item in jsonList) {
          final videoId = item['id'] as String;
          final title = item['title'] as String? ?? 'Unknown Title';
          final author = item['author'] as String? ?? 'Unknown Artist';
          final durationSec = item['duration'] != null ? int.tryParse(item['duration'].toString()) : null;
          final duration = durationSec != null ? Duration(seconds: durationSec) : null;

          results.add(
            Video(
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
            ),
          );
        }
        debugPrint('[Backend Search] Returned ${results.length} items for "$query" (page $page)');
        return results;
      }
    } catch (e) {
      debugPrint('Backend search error: $e');
    }
    return [];
  }

  /// Live query suggestions while typing (up to [limit] suggestions)
  Future<List<String>> fetchSuggestions(String query, {int limit = 8}) async {
    if (query.trim().isEmpty) return [];
    try {
      final response = await http
          .get(Uri.parse('http://10.0.2.2:8000/suggestions?q=${Uri.encodeComponent(query)}&limit=$limit'))
          .timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(response.body);
        return jsonList.map((e) => e.toString()).toList();
      }
    } catch (e) {
      debugPrint('fetchSuggestions error: $e');
    }
    return [];
  }

  /// Reports track completion for collaborative filtering co-occurrence
  Future<void> reportTrackFinished(String currentId, String nextId) async {
    try {
      await http.post(
        Uri.parse('http://10.0.2.2:8000/track_finished'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'current_id': currentId, 'next_id': nextId}),
      ).timeout(const Duration(seconds: 5));
      debugPrint('[Collaborative] Reported track transition: $currentId -> $nextId');
    } catch (e) {
      debugPrint('reportTrackFinished error: $e');
    }
  }

  /// Fetches the next 20 songs using collaborative patterns, genre, and radio
  Future<List<Video>> fetchNextCandidates(String videoId, {int limit = 20}) async {
    try {
      final response = await http
          .get(Uri.parse('http://10.0.2.2:8000/next_candidates?v=$videoId&limit=$limit'))
          .timeout(const Duration(seconds: 12));
      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(response.body);
        final List<Video> results = [];
        for (var item in jsonList) {
          final vid = item['id'] as String;
          final title = item['title'] as String? ?? 'Unknown Title';
          final author = item['author'] as String? ?? 'Unknown Artist';
          final durationSec = item['duration'] != null ? int.tryParse(item['duration'].toString()) : null;
          results.add(
            Video(
              VideoId(vid),
              title,
              author,
              ChannelId('UC0WP5P-fwGlLyO4yOE76T8g'),
              DateTime.now(),
              '',
              null,
              '',
              durationSec != null ? Duration(seconds: durationSec) : null,
              ThumbnailSet(vid),
              null,
              Engagement(0, null, null),
              false,
            ),
          );
        }
        return results;
      }
    } catch (e) {
      debugPrint('fetchNextCandidates error: $e');
    }
    return [];
  }




  Future<void> _extractPalette(String videoId) async {
    try {
      final imageUrl = getHdThumbnail(videoId);
      final palette = await PaletteGenerator.fromImageProvider(
        NetworkImage(imageUrl),
        size: const Size(120, 120),
        maximumColorCount: 12,
      ).timeout(const Duration(seconds: 4));

      final dominant = palette.dominantColor?.color ?? palette.vibrantColor?.color ?? const Color(0xFF1E1E2C);
      final vibrant = palette.vibrantColor?.color ?? palette.lightVibrantColor?.color ?? dominant;

      _dominantColor = dominant;
      _vibrantColor = vibrant;
      notifyListeners();
    } catch (e) {
      debugPrint('[Palette] Extraction error: $e');
    }
  }

  void startSleepTimer(Duration duration) {
    cancelSleepTimer();
    _sleepRemaining = duration;
    _stopAtEndOfTrack = false;
    notifyListeners();

    _sleepCountdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_sleepRemaining != null && _sleepRemaining!.inSeconds > 0) {
        _sleepRemaining = _sleepRemaining! - const Duration(seconds: 1);
        notifyListeners();
      } else {
        timer.cancel();
      }
    });

    _sleepTimer = Timer(duration, () {
      _stopPlayback();
    });
  }

  void setStopAtEndOfTrack(bool enable) {
    cancelSleepTimer();
    _stopAtEndOfTrack = enable;
    notifyListeners();
  }

  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepCountdownTimer?.cancel();
    _sleepCountdownTimer = null;
    _sleepRemaining = null;
    _stopAtEndOfTrack = false;
    notifyListeners();
  }

  void _stopPlayback() {
    _audioPlayer.pause();
    cancelSleepTimer();
    notifyListeners();
  }

  Future<void> playPlaylist(List<Video> playlist, int index) async {
    _playlist = List.from(playlist);
    _currentIndex = index;
    if (_currentIndex >= 0 && _currentIndex < _playlist.length) {
      await playSong(_playlist[_currentIndex], updateQueue: false);
    }
  }

  void _checkAndPreloadNextQueue() {
    // When 5 or fewer songs remain after current playing song, silently load next 20 songs
    if ((_playlist.length - (_currentIndex + 1)) <= 5 && _currentSong != null) {
      final seedSong = _playlist.isNotEmpty ? _playlist.last : _currentSong!;
      _fetchNextRecommendations(seedSong);
    }
  }

  Future<void> nextSong() async {
    if (_stopAtEndOfTrack) {
      debugPrint('[SleepTimer] Reached end of current track. Stopping playback.');
      _stopPlayback();
      return;
    }

    if (_playlist.isNotEmpty && _currentIndex + 1 < _playlist.length) {
      final prevSong = _currentSong;
      _currentIndex++;
      final nextTrack = _playlist[_currentIndex];
      if (prevSong != null) {
        reportTrackFinished(prevSong.id.value, nextTrack.id.value);
      }
      await playSong(nextTrack, updateQueue: false);
      _checkAndPreloadNextQueue();
    } else if (_currentSong != null) {
      debugPrint('[Queue] End of queue reached. Fetching next recommendations…');
      _isLoading = true;
      notifyListeners();
      await _fetchNextRecommendations(_currentSong!);
      if (_currentIndex + 1 < _playlist.length) {
        final prevSong = _currentSong;
        _currentIndex++;
        final nextTrack = _playlist[_currentIndex];
        if (prevSong != null) {
          reportTrackFinished(prevSong.id.value, nextTrack.id.value);
        }
        await playSong(nextTrack, updateQueue: false);
        _checkAndPreloadNextQueue();
      } else {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> previousSong() async {
    if (_playlist.isNotEmpty && _currentIndex - 1 >= 0) {
      _currentIndex--;
      await playSong(_playlist[_currentIndex], updateQueue: false);
    }
  }

  // Full browser headers to avoid CDN 403s and throttling
  static const Map<String, String> _ytHeaders = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
        'AppleWebKit/537.36 (KHTML, like Gecko) '
        'Chrome/125.0.0.0 Safari/537.36',
    'Accept': '*/*',
    'Accept-Language': 'en-US,en;q=0.9',
    'Origin': 'https://www.youtube.com',
    'Referer': 'https://www.youtube.com/',
  };

  /// Fetches the stream URL from the backend.
  /// [bustCache] forces the backend to re-extract the URL (used on retry).
  Future<String?> _fetchStreamUrl(String videoId, {bool bustCache = false}) async {
    try {
      if (bustCache) {
        // Tell backend to discard its cached URL for this video
        await http.delete(Uri.parse('http://10.0.2.2:8000/cache/$videoId'))
            .timeout(const Duration(seconds: 3));
      }
      final response = await http
          .get(Uri.parse('http://10.0.2.2:8000/stream_url?v=$videoId'))
          .timeout(const Duration(seconds: 20));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['url'] as String?;
      }
    } catch (e) {
      debugPrint('_fetchStreamUrl error: $e');
    }
    return null;
  }

  Future<void> playSong(Video song, {bool updateQueue = true}) async {
    _isLoading = true;
    _currentSong = song;

    if (updateQueue) {
      final existingIndex = _playlist.indexWhere((item) => item.id == song.id);
      if (existingIndex != -1) {
        _currentIndex = existingIndex;
      } else {
        _playlist = [song];
        _currentIndex = 0;
      }
    }
    notifyListeners();

    // Trigger palette extraction asynchronously
    _extractPalette(song.id.value);

    // Track play count and history for personalization algorithm
    PreferencesService().recordSongPlay(song.author, song.title);

    try {
      final proxyUrl = 'http://10.0.2.2:8000/stream/${song.id.value}.m4a';
      debugPrint('[Play] Setting audio source to local proxy: $proxyUrl');

      await _audioPlayer.stop();

      try {
        await _audioPlayer.setAudioSource(
          AudioSource.uri(Uri.parse(proxyUrl)),
          preload: true,
        );
      } catch (proxyError) {
        debugPrint('[Play] Proxy error ($proxyError), falling back to direct stream…');
        final directUrl = await _fetchStreamUrl(song.id.value);
        if (directUrl != null) {
          await _audioPlayer.setAudioSource(
            AudioSource.uri(Uri.parse(directUrl), headers: _ytHeaders),
            preload: true,
          );
        } else {
          rethrow;
        }
      }

      debugPrint('[Play] Starting playback…');
      await _audioPlayer.play();
      _isLoading = false;
      notifyListeners();

      _checkAndPreloadNextQueue();
    } catch (e, st) {
      debugPrint('[Play] Error playing song: $e\n$st');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _fetchNextRecommendations(Video song) async {
    if (_isFetchingNextQueue) return;
    _isFetchingNextQueue = true;
    try {
      debugPrint('[Recommendations] Silently fetching next 20 songs for ${song.title}…');
      final candidates = await fetchNextCandidates(song.id.value, limit: 20);

      if (candidates.isNotEmpty) {
        int added = 0;
        for (var track in candidates) {
          if (!_playlist.any((item) => item.id.value == track.id.value)) {
            _playlist.add(track);
            added++;
          }
        }
        debugPrint('[Queue] Appended $added recommended tracks. Total in queue: ${_playlist.length}');
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error fetching recommendations: $e');
    } finally {
      _isFetchingNextQueue = false;
    }
  }

  List<Map<String, String>> _downloadedSongs = [];
  bool _isDownloading = false;

  List<Map<String, String>> get downloadedSongs => _downloadedSongs;
  bool get isDownloading => _isDownloading;

  Future<void> loadDownloadedSongs() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/downloads.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        final List<dynamic> jsonList = json.decode(content);
        _downloadedSongs = jsonList.map((e) => Map<String, String>.from(e)).toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading downloaded songs: $e');
    }
  }

  Future<bool> downloadSong(Video song) async {
    _isDownloading = true;
    notifyListeners();

    try {
      final streamUrl = await _fetchStreamUrl(song.id.value);
      if (streamUrl == null) return false;

        // Download stream bytes
        final audioResponse = await http.get(
          Uri.parse(streamUrl),
          headers: _ytHeaders,
        );

        if (audioResponse.statusCode == 200) {
          final dir = await getApplicationDocumentsDirectory();
          final filePath = '${dir.path}/${song.id.value}.m4a';
          final file = File(filePath);
          await file.writeAsBytes(audioResponse.bodyBytes);

          final songInfo = {
            'id': song.id.value,
            'title': song.title,
            'author': song.author,
            'thumbnail': song.thumbnails.highResUrl,
            'localPath': filePath,
          };

          _downloadedSongs.removeWhere((item) => item['id'] == song.id.value);
          _downloadedSongs.add(songInfo);

          final jsonFile = File('${dir.path}/downloads.json');
          await jsonFile.writeAsString(json.encode(_downloadedSongs));

          debugPrint('Successfully downloaded song to $filePath');
          notifyListeners();
          return true;
        }
    } catch (e) {
      debugPrint('Error downloading song: $e');
    } finally {
      _isDownloading = false;
      notifyListeners();
    }
    return false;
  }

  Future<void> playDownloadedSong(Map<String, String> songData) async {
    _isLoading = true;
    // Create a dummy Video object for UI consistency
    _currentSong = Video(
      VideoId(songData['id']!),
      songData['title']!,
      songData['author']!,
      ChannelId('UC0WP5P-fwGlLyO4yOE76T8g'),
      DateTime.now(),
      '',
      null,
      '',
      null,
      ThumbnailSet(songData['id']!),
      null,
      Engagement(0, null, null),
      false,
    );
    notifyListeners();

    try {
      await _audioPlayer.setFilePath(songData['localPath']!);
      await _audioPlayer.play();
    } catch (e) {
      debugPrint('Error playing downloaded song: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void togglePlayPause() {
    if (_audioPlayer.playing) {
      _audioPlayer.pause();
    } else {
      _audioPlayer.play();
    }
    notifyListeners();
  }
}

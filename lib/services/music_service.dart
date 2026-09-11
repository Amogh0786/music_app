import 'dart:convert';
import 'dart:io';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

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

  Video? get currentSong => _currentSong;
  List<Video> get playlist => _playlist;
  int get currentIndex => _currentIndex;
  bool get isLoading => _isLoading;
  bool get isShuffle => _isShuffle;
  LoopMode get loopMode => _loopMode;
  List<Map<String, String>> get likedSongs => _likedSongs;
  AudioPlayer get audioPlayer => _audioPlayer;

  static String getHdThumbnail(String videoId) {
    return 'https://i.ytimg.com/vi/$videoId/maxresdefault.jpg';
  }

  void _initAudioPlayer() {
    _audioPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        nextSong(); // Infinite Auto-Play next recommended track
      }
      notifyListeners();
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

  Future<List<Video>> searchSongs(String query) async {
    if (query.trim().isEmpty) return [];
    
    try {
      // Search YouTube
      final searchList = await _yt.search.search(query);
      debugPrint('Found ${searchList.length} items from YouTube search');
      
      final filteredList = searchList.where((video) => video.duration != null).toList();
      debugPrint('After filtering null durations: ${filteredList.length} items');
      
      return filteredList;
    } catch (e) {
      debugPrint('Error searching YouTube: $e');
      return [];
    }
  }


  Future<void> playPlaylist(List<Video> playlist, int index) async {
    _playlist = playlist;
    _currentIndex = index;
    if (_currentIndex >= 0 && _currentIndex < _playlist.length) {
      await playSong(_playlist[_currentIndex]);
    }
  }

  Future<void> nextSong() async {
    if (_playlist.isNotEmpty && _currentIndex + 1 < _playlist.length) {
      _currentIndex++;
      await playSong(_playlist[_currentIndex]);
    }
  }

  Future<void> previousSong() async {
    if (_playlist.isNotEmpty && _currentIndex - 1 >= 0) {
      _currentIndex--;
      await playSong(_playlist[_currentIndex]);
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

  Future<void> playSong(Video song) async {
    _isLoading = true;
    _currentSong = song;
    notifyListeners();

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

      _fetchNextRecommendations(song);
    } catch (e, st) {
      debugPrint('[Play] Error playing song: $e\n$st');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _fetchNextRecommendations(Video song) async {
    try {
      debugPrint('Fetching YouTube auto-play recommendations for ${song.title}');
      final relatedList = await _yt.videos.getRelatedVideos(song);
      if (relatedList != null && relatedList.isNotEmpty) {
        final newTracks = relatedList.where((v) => v.duration != null).toList();
        for (var track in newTracks) {
          if (!_playlist.any((item) => item.id == track.id)) {
            _playlist.add(track);
          }
        }
        debugPrint('Added ${newTracks.length} auto-play recommended songs to queue!');
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error fetching recommendations: $e');
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

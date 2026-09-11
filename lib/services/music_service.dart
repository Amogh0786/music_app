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

  Video? get currentSong => _currentSong;
  List<Video> get playlist => _playlist;
  int get currentIndex => _currentIndex;
  bool get isLoading => _isLoading;
  AudioPlayer get audioPlayer => _audioPlayer;

  void _initAudioPlayer() {
    // Listen to player state changes to notify UI
    _audioPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        nextSong(); // Auto play next song when current finishes
      }
      notifyListeners();
    });
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

  Future<void> playSong(Video song) async {
    _isLoading = true;
    _currentSong = song;
    notifyListeners();

    try {
      debugPrint('Step 1: Asking Python backend for stream URL for ${song.id.value}');
      
      // 10.0.2.2 is the special IP Android Emulator uses to access the Mac's localhost
      final response = await http.get(Uri.parse('http://10.0.2.2:8000/stream_url?v=${song.id.value}'));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final streamUrl = data['url'];
        
        debugPrint('Step 2: Received direct stream URL from yt-dlp!');
        
        await _audioPlayer.setAudioSource(
          AudioSource.uri(
            Uri.parse(streamUrl),
            headers: {
              'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36',
            },
          ),
        );
        
        debugPrint('Step 3: Playing audio via just_audio');
        await _audioPlayer.play();
      } else {
        debugPrint('Backend error: ${response.body}');
      }
    } catch (e, stackTrace) {
      debugPrint('Error playing song: $e');
      debugPrint('Stack trace: $stackTrace');
    } finally {
      _isLoading = false;
      notifyListeners();
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
      final response = await http.get(Uri.parse('http://10.0.2.2:8000/stream_url?v=${song.id.value}'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final streamUrl = data['url'];

        // Download stream bytes
        final audioResponse = await http.get(
          Uri.parse(streamUrl),
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          },
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

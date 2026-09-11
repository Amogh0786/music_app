import 'dart:convert';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class MusicService extends ChangeNotifier {
  static final MusicService _instance = MusicService._internal();
  factory MusicService() => _instance;

  MusicService._internal() {
    _initAudioPlayer();
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

  void togglePlayPause() {
    if (_audioPlayer.playing) {
      _audioPlayer.pause();
    } else {
      _audioPlayer.play();
    }
    notifyListeners();
  }
}

import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/material.dart';

class MusicService extends ChangeNotifier {
  static final MusicService _instance = MusicService._internal();
  factory MusicService() => _instance;

  MusicService._internal() {
    _initAudioPlayer();
  }

  final YoutubeExplode _yt = YoutubeExplode();
  final AudioPlayer _audioPlayer = AudioPlayer();

  Video? _currentSong;
  bool _isLoading = false;

  Video? get currentSong => _currentSong;
  bool get isLoading => _isLoading;
  AudioPlayer get audioPlayer => _audioPlayer;

  void _initAudioPlayer() {
    // Listen to player state changes to notify UI
    _audioPlayer.playerStateStream.listen((state) {
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

  Future<void> playSong(Video song) async {
    _isLoading = true;
    _currentSong = song;
    notifyListeners();

    try {
      debugPrint('Step 1: Getting manifest for ${song.id}');
      var manifest = await _yt.videos.streamsClient.getManifest(song.id);
      
      debugPrint('Step 2: Checking audio streams. Count: ${manifest.audioOnly.length}');
      if (manifest.audioOnly.isEmpty) {
        debugPrint('Error: No audio streams found in manifest.');
        return;
      }

      var streamInfo = manifest.audioOnly.withHighestBitrate();
      debugPrint('Step 3: Selected stream URL: ${streamInfo.url}');

      debugPrint('Step 4: Passing URL to audio player');
      await _audioPlayer.setUrl(streamInfo.url.toString());
      
      debugPrint('Step 5: Playing audio');
      await _audioPlayer.play();
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

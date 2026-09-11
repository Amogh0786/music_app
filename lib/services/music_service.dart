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
      debugPrint('Step 1: Setting up proxy stream for ${song.id}');
      var manifest = await _yt.videos.streamsClient.getManifest(song.id);
      
      debugPrint('Step 2: Checking audio streams. Count: ${manifest.audioOnly.length}');
      if (manifest.audioOnly.isEmpty) {
        debugPrint('Error: No audio streams found in manifest.');
        return;
      }

      // ExoPlayer sometimes struggles to decode chunked .webm (Opus/Vorbis) streams.
      // We force it to use .mp4 (M4A / AAC) which ExoPlayer handles perfectly.
      var streamInfo = manifest.audioOnly
          .where((stream) => stream.container.name == 'mp4')
          .withHighestBitrate();
          
      debugPrint('Step 3: Selected stream URL: ${streamInfo.url}');
      
      // Instead of giving ExoPlayer the URL (which gets 403 Forbidden), 
      // we download the stream via Dart and pipe it directly to ExoPlayer!
      await _audioPlayer.setAudioSource(YoutubeAudioSource(streamInfo.url.toString()));
      
      debugPrint('Step 4: Playing audio via Dart proxy');
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

/// A custom AudioSource that pipes the YouTube stream through Dart's HTTP client
/// This completely bypasses the ExoPlayer 403 Forbidden error!
class YoutubeAudioSource extends StreamAudioSource {
  final String url;

  YoutubeAudioSource(this.url);

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0;
    
    final req = http.Request('GET', Uri.parse(url));
    // ExoPlayer requires Range requests for seeking and buffering.
    // This was the missing piece that caused the SocketTimeout!
    req.headers['Range'] = 'bytes=$start-${end != null ? end - 1 : ''}';
    req.headers['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36';

    final response = await http.Client().send(req);
    
    int? sourceLength;
    final contentRange = response.headers['content-range'];
    if (contentRange != null && contentRange.contains('/')) {
      sourceLength = int.tryParse(contentRange.split('/').last);
    }

    return StreamAudioResponse(
      sourceLength: sourceLength,
      contentLength: response.contentLength,
      offset: start,
      stream: response.stream,
      contentType: response.headers['content-type'] ?? 'audio/mp4',
    );
  }
}

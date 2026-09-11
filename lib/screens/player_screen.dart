import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../services/music_service.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  final MusicService _musicService = MusicService();

  @override
  void initState() {
    super.initState();
    _musicService.addListener(_onStateChanged);
  }

  @override
  void dispose() {
    _musicService.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    if (mounted) setState(() {});
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) return '0:00';
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final song = _musicService.currentSong;
    final isPlaying = _musicService.audioPlayer.playing;
    final isLoading = _musicService.isLoading && !isPlaying;
    final isLiked = song != null && _musicService.likedSongs.any((s) => s['id'] == song.id.value);
    final hdThumbnail = song != null ? MusicService.getHdThumbnail(song.id.value) : '';

    if (song == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: Text('No song active', style: TextStyle(color: Colors.white))),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Dynamic Ambient Blurred Album Art Background (Apple Music Signature)
          Positioned.fill(
            child: Image.network(
              hdThumbnail,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Image.network(song.thumbnails.highResUrl, fit: BoxFit.cover),
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
              child: Container(
                color: Colors.black.withOpacity(0.55),
              ),
            ),
          ),

          // 2. Main Player Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Column(
                children: [
                  // Top Grabber & Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white70, size: 32),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Container(
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.white30,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      IconButton(
                        icon: _musicService.isDownloading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Icon(
                                _musicService.downloadedSongs.any((s) => s['id'] == song.id.value)
                                    ? Icons.download_done
                                    : Icons.arrow_circle_down_outlined,
                                color: _musicService.downloadedSongs.any((s) => s['id'] == song.id.value)
                                    ? const Color(0xFF1DB954)
                                    : Colors.white70,
                                size: 26,
                              ),
                        onPressed: _musicService.isDownloading
                            ? null
                            : () async {
                                final success = await _musicService.downloadSong(song);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        success ? 'Saved to Offline Library!' : 'Download failed.',
                                      ),
                                    ),
                                  );
                                }
                              },
                      ),
                    ],
                  ),
                  const Spacer(),

                  // HD 1080p Album Artwork Card
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.82,
                      height: MediaQuery.of(context).size.width * 0.82,
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.6),
                            blurRadius: 25,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Image.network(
                        hdThumbnail,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Image.network(song.thumbnails.highResUrl, fit: BoxFit.cover),
                      ),
                    ),
                  ),
                  const Spacer(),

                  // Song Title & Artist Info + Like Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              song.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              song.author,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          isLiked ? Icons.favorite : Icons.favorite_border,
                          color: isLiked ? const Color(0xFFE63946) : Colors.white70,
                          size: 28,
                        ),
                        onPressed: () => _musicService.toggleLike(song),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Interactive Progress Bar (Scrubber)
                  StreamBuilder<Duration>(
                    stream: _musicService.audioPlayer.positionStream,
                    builder: (context, snapshotPosition) {
                      final position = snapshotPosition.data ?? Duration.zero;
                      return StreamBuilder<Duration?>(
                        stream: _musicService.audioPlayer.durationStream,
                        builder: (context, snapshotDuration) {
                          final duration = snapshotDuration.data ?? song.duration ?? Duration.zero;
                          double progress = 0.0;
                          if (duration.inMilliseconds > 0) {
                            progress = (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
                          }

                          return Column(
                            children: [
                              SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 4,
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                                  activeTrackColor: Colors.white,
                                  inactiveTrackColor: Colors.white.withOpacity(0.2),
                                  thumbColor: Colors.white,
                                ),
                                child: Slider(
                                  value: progress,
                                  onChanged: (value) {
                                    final seekPos = Duration(
                                      milliseconds: (value * duration.inMilliseconds).round(),
                                    );
                                    _musicService.audioPlayer.seek(seekPos);
                                  },
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(_formatDuration(position), style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
                                    Text(_formatDuration(duration), style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 12),

                  // Secondary Controls (-10s, +10s, Shuffle, Repeat)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.shuffle,
                          color: _musicService.isShuffle ? const Color(0xFF1DB954) : Colors.white54,
                          size: 22,
                        ),
                        onPressed: () => _musicService.toggleShuffle(),
                      ),
                      IconButton(
                        icon: const Icon(Icons.replay_10, color: Colors.white70, size: 28),
                        onPressed: () => _musicService.seekRelative(const Duration(seconds: -10)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.forward_10, color: Colors.white70, size: 28),
                        onPressed: () => _musicService.seekRelative(const Duration(seconds: 10)),
                      ),
                      IconButton(
                        icon: Icon(
                          _musicService.loopMode == LoopMode.one
                              ? Icons.repeat_one
                              : Icons.repeat,
                          color: _musicService.loopMode != LoopMode.off ? const Color(0xFF1DB954) : Colors.white54,
                          size: 22,
                        ),
                        onPressed: () => _musicService.toggleRepeat(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Main Playback Controls (Prev, Play/Pause, Next)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.skip_previous_rounded, color: Colors.white, size: 44),
                        onPressed: () => _musicService.previousSong(),
                      ),
                      Container(
                        width: 72,
                        height: 72,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: isLoading
                            ? const Padding(
                                padding: EdgeInsets.all(20.0),
                                child: CircularProgressIndicator(color: Colors.black, strokeWidth: 3),
                              )
                            : IconButton(
                                icon: Icon(
                                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                  color: Colors.black,
                                  size: 44,
                                ),
                                onPressed: () => _musicService.togglePlayPause(),
                              ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 44),
                        onPressed: () => _musicService.nextSong(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

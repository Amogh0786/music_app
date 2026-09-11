import 'package:flutter/material.dart';
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
    if (duration == null) return '--:--';
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final song = _musicService.currentSong;
    final isPlaying = _musicService.audioPlayer.playing;
    final isLoading = _musicService.isLoading;

    if (song == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF121212),
        body: Center(child: Text('No song playing', style: TextStyle(color: Colors.white))),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF2C3E50),
                Color(0xFF121212),
              ],
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            children: [
              // Top Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 32),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Column(
                    children: [
                      Text(
                        'PLAYING FROM SEARCH',
                        style: TextStyle(color: Colors.grey[400], fontSize: 10, letterSpacing: 1),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'YouTube Audio',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ],
                  ),
                  Row(
                    children: [
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
                                    : Icons.file_download_outlined,
                                color: _musicService.downloadedSongs.any((s) => s['id'] == song.id.value)
                                    ? const Color(0xFF1DB954)
                                    : Colors.white,
                              ),
                        onPressed: _musicService.isDownloading
                            ? null
                            : () async {
                                final success = await _musicService.downloadSong(song);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        success ? 'Downloaded to offline library!' : 'Download failed.',
                                      ),
                                    ),
                                  );
                                }
                              },
                      ),
                      IconButton(
                        icon: const Icon(Icons.more_vert, color: Colors.white),
                        onPressed: () {},
                      ),
                    ],
                  ),
                ],
              ),
              const Spacer(),

              // Album Art
              Container(
                width: MediaQuery.of(context).size.width * 0.8,
                height: MediaQuery.of(context).size.width * 0.8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                  image: DecorationImage(
                    image: NetworkImage(song.thumbnails.highResUrl),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const Spacer(),

              // Title and Artist
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
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          song.author,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.favorite_border, color: Colors.white, size: 28),
                    onPressed: () {},
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Progress Bar
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
                              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                              activeTrackColor: const Color(0xFF1DB954),
                              inactiveTrackColor: Colors.grey[800],
                              thumbColor: Colors.white,
                            ),
                            child: Slider(
                              value: progress,
                              onChanged: (value) {
                                final seekPosition = Duration(
                                  milliseconds: (value * duration.inMilliseconds).round(),
                                );
                                _musicService.audioPlayer.seek(seekPosition);
                              },
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(_formatDuration(position), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                Text(_formatDuration(duration), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 10),

              // Playback Controls
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    icon: const Icon(Icons.shuffle, color: Colors.grey, size: 24),
                    onPressed: () {},
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_previous, color: Colors.white, size: 36),
                    onPressed: () => _musicService.previousSong(),
                  ),
                  Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(
                      color: Color(0xFF1DB954),
                      shape: BoxShape.circle,
                    ),
                    child: isLoading
                        ? const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: CircularProgressIndicator(color: Colors.black, strokeWidth: 3),
                          )
                        : IconButton(
                            icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.black, size: 36),
                            onPressed: () => _musicService.togglePlayPause(),
                          ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_next, color: Colors.white, size: 36),
                    onPressed: () => _musicService.nextSong(),
                  ),
                  IconButton(
                    icon: const Icon(Icons.repeat, color: Colors.grey, size: 24),
                    onPressed: () {},
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

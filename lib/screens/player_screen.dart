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
  bool _showLyrics = false;
  double? _dragValue;

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

  String _cleanLyrics(String? raw) {
    if (raw == null) return 'No lyrics available.';
    // Strip [01:23.45] style LRC timestamp tags
    final cleaned = raw.replaceAll(RegExp(r'\[\d+:\d+(\.\d+)?\]'), '').trim();
    return cleaned.isEmpty ? 'No lyrics available.' : cleaned;
  }

  void _toggleLyrics(Video song) {
    setState(() {
      _showLyrics = !_showLyrics;
    });
    if (_showLyrics) {
      _musicService.fetchLyrics(song);
    }
  }

  void _showQueueSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final playlist = _musicService.playlist;
        final currentIndex = _musicService.currentIndex;

        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E24),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: Colors.white10),
          ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white38,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Up Next',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        '${playlist.length} Tracks',
                        style: TextStyle(color: Colors.grey[400], fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white12, height: 1),
                Expanded(
                  child: playlist.isEmpty
                      ? const Center(
                          child: Text('Queue is empty', style: TextStyle(color: Colors.white54)),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: playlist.length,
                          itemBuilder: (context, index) {
                            final song = playlist[index];
                            final isCurrent = index == currentIndex;
                            final hdThumbnail = MusicService.getHdThumbnail(song.id.value);

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  hdThumbnail,
                                  width: 46,
                                  height: 46,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Image.network(
                                    song.thumbnails.lowResUrl,
                                    width: 46,
                                    height: 46,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              title: Text(
                                song.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isCurrent ? Theme.of(context).primaryColor : Colors.white,
                                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                                  fontSize: 14,
                                ),
                              ),
                              subtitle: Text(
                                song.author,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isCurrent ? Theme.of(context).primaryColor.withValues(alpha: 0.8) : Colors.grey[400],
                                  fontSize: 12,
                                ),
                              ),
                              trailing: isCurrent
                                  ? Icon(Icons.equalizer, color: Theme.of(context).primaryColor, size: 24)
                                  : Text(
                                      _formatDuration(song.duration),
                                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                                    ),
                              onTap: () {
                                Navigator.pop(context);
                                _musicService.playPlaylist(playlist, index);
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      );
  }

  void _showSleepTimerSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E24).withValues(alpha: 0.95),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white38,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.bedtime, color: Color(0xFFFA2D48), size: 22),
                        SizedBox(width: 10),
                        Text(
                          'Sleep Timer',
                          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    if (_musicService.isSleepTimerActive)
                      Text(
                        _musicService.sleepTimerLabel,
                        style: const TextStyle(color: Color(0xFFFA2D48), fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_musicService.isSleepTimerActive)
                  ListTile(
                    leading: const Icon(Icons.timer_off_outlined, color: Colors.redAccent),
                    title: const Text('Turn Off Timer', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                    subtitle: Text('Active: ${_musicService.sleepTimerLabel}', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                    onTap: () {
                      _musicService.cancelSleepTimer();
                      Navigator.pop(context);
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.timer_outlined, color: Colors.white),
                  title: const Text('15 Minutes', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    _musicService.startSleepTimer(const Duration(minutes: 15));
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.timer_outlined, color: Colors.white),
                  title: const Text('30 Minutes', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    _musicService.startSleepTimer(const Duration(minutes: 30));
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.timer_outlined, color: Colors.white),
                  title: const Text('45 Minutes', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    _musicService.startSleepTimer(const Duration(minutes: 45));
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.timer_outlined, color: Colors.white),
                  title: const Text('1 Hour', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    _musicService.startSleepTimer(const Duration(hours: 1));
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.music_note_outlined, color: Colors.white),
                  title: const Text('End of Current Track', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    _musicService.setStopAtEndOfTrack(true);
                    Navigator.pop(context);
                  },
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
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
          // 1. Dynamic Album Palette Ambient Liquid Gradient Background
          Positioned.fill(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 800),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    _musicService.dominantColor.withValues(alpha: 0.85),
                    _musicService.vibrantColor.withValues(alpha: 0.45),
                    const Color(0xFF121212),
                    Colors.black,
                  ],
                  stops: const [0.0, 0.45, 0.8, 1.0],
                ),
              ),
            ),
          ),
          // Ambient Glow Spheres
          Positioned(
            top: -60,
            left: -60,
            width: 320,
            height: 320,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 800),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _musicService.dominantColor.withValues(alpha: 0.5),
              ),
            ),
          ),
          Positioned(
            top: 220,
            right: -80,
            width: 360,
            height: 360,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 800),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _musicService.vibrantColor.withValues(alpha: 0.4),
              ),
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 55, sigmaY: 55),
              child: Container(
                color: Colors.black.withValues(alpha: 0.35),
              ),
            ),
          ),

          // 2. Main Player Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Column(
                children: [
                  // Top Grabber & Header Actions
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
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              _showLyrics ? Icons.music_note : Icons.lyrics_outlined,
                              color: _showLyrics ? Theme.of(context).primaryColor : Colors.white70,
                              size: 24,
                            ),
                            onPressed: () => _toggleLyrics(song),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.bedtime_outlined,
                              color: _musicService.isSleepTimerActive ? Theme.of(context).primaryColor : Colors.white70,
                              size: 24,
                            ),
                            onPressed: () => _showSleepTimerSheet(context),
                          ),
                          IconButton(
                            icon: const Icon(Icons.queue_music_rounded, color: Colors.white70, size: 24),
                            onPressed: () => _showQueueSheet(context),
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
                    ],
                  ),

                  const Spacer(),

                  // Center Content: Either Album Art OR Interactive Apple Lyrics View
                  if (!_showLyrics)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: MediaQuery.of(context).size.width * 0.82,
                        height: MediaQuery.of(context).size.width * 0.82,
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.6),
                              blurRadius: 25,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Image.network(
                          hdThumbnail,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Image.network(song.thumbnails.highResUrl, fit: BoxFit.cover),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      flex: 8,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: _musicService.isFetchingLyrics
                            ? Center(
                                child: CircularProgressIndicator(color: Theme.of(context).primaryColor),
                              )
                            : SingleChildScrollView(
                                physics: const BouncingScrollPhysics(),
                                child: Text(
                                  _cleanLyrics(_musicService.cachedLyrics),
                                  textAlign: TextAlign.left,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    height: 1.8,
                                    letterSpacing: 0.2,
                                  ),
                                ),
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
                                color: Colors.white.withValues(alpha: 0.7),
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

                  // Scrubber Bar
                  StreamBuilder<Duration>(
                    stream: _musicService.audioPlayer.positionStream,
                    builder: (context, snapshot) {
                      final position = snapshot.data ?? Duration.zero;
                      final duration = _musicService.audioPlayer.duration ?? Duration.zero;
                      double progress = 0.0;
                      if (duration.inMilliseconds > 0) {
                        progress = (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
                      }

                      final displayPosition = _dragValue != null
                          ? Duration(milliseconds: (_dragValue! * duration.inMilliseconds).toInt())
                          : position;

                      return Column(
                        children: [
                          SliderTheme(
                            data: const SliderThemeData(
                              trackHeight: 4,
                              thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
                              overlayShape: RoundSliderOverlayShape(overlayRadius: 14),
                              activeTrackColor: Colors.white,
                              inactiveTrackColor: Colors.white24,
                              thumbColor: Colors.white,
                            ),
                            child: Slider(
                              value: _dragValue ?? progress,
                              onChanged: (val) {
                                setState(() {
                                  _dragValue = val;
                                });
                              },
                              onChangeEnd: (val) {
                                final newPosition = Duration(milliseconds: (val * duration.inMilliseconds).toInt());
                                _musicService.audioPlayer.seek(newPosition);
                                setState(() {
                                  _dragValue = null;
                                });
                              },
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(_formatDuration(displayPosition), style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12)),
                                Text(_formatDuration(duration), style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12)),
                              ],
                            ),
                          ),
                        ],
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

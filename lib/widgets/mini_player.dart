import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/music_service.dart';
import '../screens/player_screen.dart';
import 'animated_equalizer.dart';

class MiniPlayer extends StatefulWidget {
  const MiniPlayer({super.key});

  @override
  State<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<MiniPlayer> {
  final MusicService _musicService = MusicService();

  @override
  void initState() {
    super.initState();
    _musicService.addListener(_onMusicStateChanged);
  }

  @override
  void dispose() {
    _musicService.removeListener(_onMusicStateChanged);
    super.dispose();
  }

  void _onMusicStateChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final song = _musicService.currentSong;
    final isPlaying = _musicService.audioPlayer.playing;
    final isLoading = _musicService.isLoading && !isPlaying;
    final hdThumbnail = song != null ? MusicService.getHdThumbnail(song.id.value) : '';

    if (song == null && !isLoading) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const PlayerScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              const begin = Offset(0.0, 1.0);
              const end = Offset.zero;
              const curve = Curves.easeOutCubic;
              var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
              return SlideTransition(position: animation.drive(tween), child: child);
            },
          ),
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 600),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        height: 64,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _musicService.vibrantColor.withValues(alpha: 0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: _musicService.dominantColor.withValues(alpha: 0.35),
              blurRadius: 16,
              spreadRadius: 1,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 600),
              color: Color.alphaBlend(
                _musicService.dominantColor.withValues(alpha: 0.25),
                const Color(0xFF202025).withValues(alpha: 0.88),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(

                children: [
                  // Album Thumbnail
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: song != null
                          ? Image.network(
                              hdThumbnail,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Image.network(song.thumbnails.lowResUrl, fit: BoxFit.cover),
                            )
                          : Container(color: Colors.grey[800]),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Song Title and Artist
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                song?.title ?? 'Loading...',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  letterSpacing: -0.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            AnimatedEqualizer(
                              isPlaying: isPlaying,
                              color: Theme.of(context).primaryColor,
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          song?.author ?? '',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // Control Buttons (Play/Pause & Next)
                  isLoading
                      ? const Padding(
                          padding: EdgeInsets.all(12.0),
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          ),
                        )
                      : IconButton(
                          icon: Icon(
                            isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 30,
                          ),
                          onPressed: () => _musicService.togglePlayPause(),
                        ),
                  IconButton(
                    icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 28),
                    onPressed: () => _musicService.nextSong(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

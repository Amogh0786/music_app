import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
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

  void _openPlayerScreen() {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 380),
        reverseTransitionDuration: const Duration(milliseconds: 320),
        pageBuilder: (context, animation, secondaryAnimation) => const PlayerScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutQuart,
            reverseCurve: Curves.easeInQuart,
          );
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.0, 1.0),
              end: Offset.zero,
            ).animate(curved),
            child: FadeTransition(
              opacity: Tween<double>(begin: 0.5, end: 1.0).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final song = _musicService.currentSong;
    final isPlaying = _musicService.isPlaying;
    final processingState = _musicService.audioPlayer.processingState;
    final isBuffering = !kIsWeb && (processingState == ProcessingState.buffering || processingState == ProcessingState.loading);
    final isLoading = !isPlaying && (_musicService.isLoading || isBuffering);
    final hdThumbnail = song != null ? MusicService.getHdThumbnail(song.id.value) : '';

    if (song == null && !isLoading) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: _openPlayerScreen,
      onVerticalDragEnd: (details) {
        if (details.primaryVelocity != null && details.primaryVelocity! < -120) {
          _openPlayerScreen();
        }
      },
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity != null) {
          if (details.primaryVelocity! < -200) {
            HapticFeedback.mediumImpact();
            _musicService.nextSong();
          } else if (details.primaryVelocity! > 200) {
            HapticFeedback.mediumImpact();
            _musicService.previousSong();
          }
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 600),
        margin: const EdgeInsets.only(left: 16, right: 16, bottom: 4),
        height: 66,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: _musicService.vibrantColor.withValues(alpha: 0.35),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: _musicService.dominantColor.withValues(alpha: 0.4),
              blurRadius: 18,
              spreadRadius: 1,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
            child: Container(
              color: Color.alphaBlend(
                _musicService.dominantColor.withValues(alpha: 0.28),
                const Color(0xFF1E1E24).withValues(alpha: 0.90),
              ),
              child: Stack(
                children: [
                  // Main Player Content Row
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        // Album Thumbnail with Hero Tag
                        Hero(
                          tag: 'player_artwork_${song?.id.value}',
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: SizedBox(
                              width: 48,
                              height: 48,
                              child: song != null
                                  ? Image.network(
                                      hdThumbnail,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => Image.network(
                                        song.thumbnails.lowResUrl,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : Container(color: Colors.grey[850]),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Song Title, Equalizer, and Artist
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
                                  color: Colors.white.withValues(alpha: 0.65),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
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
                                  size: 32,
                                ),
                                onPressed: () {
                                  HapticFeedback.mediumImpact();
                                  _musicService.togglePlayPause();
                                },
                              ),
                        IconButton(
                          icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 28),
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            _musicService.nextSong();
                          },
                        ),
                      ],
                    ),
                  ),

                  // Ultra-Thin Glowing Progress Bar on the bottom edge
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: StreamBuilder<Duration>(
                      stream: _musicService.positionStream,
                      builder: (context, snapshot) {
                        final position = snapshot.data ?? Duration.zero;
                        final duration = _musicService.duration ?? Duration.zero;
                        double progress = 0.0;
                        if (duration.inMilliseconds > 0) {
                          progress = (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
                        }

                        return FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: progress,
                          child: Container(
                            height: 2.5,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  _musicService.vibrantColor,
                                  Theme.of(context).primaryColor,
                                  Colors.white,
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: _musicService.vibrantColor.withValues(alpha: 0.8),
                                  blurRadius: 4,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
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

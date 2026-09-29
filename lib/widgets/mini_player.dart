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

class _MiniPlayerState extends State<MiniPlayer> with SingleTickerProviderStateMixin {
  final MusicService _musicService = MusicService();
  double _dragOffset = 0.0;
  bool _isDraggingHorizontal = false;

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
        transitionDuration: const Duration(milliseconds: 440),
        reverseTransitionDuration: const Duration(milliseconds: 380),
        pageBuilder: (context, animation, secondaryAnimation) => const PlayerScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curve = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInOutCubic,
          );

          final scale = Tween<double>(begin: 0.90, end: 1.0).animate(curve);
          final slide = Tween<Offset>(
            begin: const Offset(0.0, 0.85),
            end: Offset.zero,
          ).animate(curve);
          final fade = Tween<double>(begin: 0.0, end: 1.0).animate(curve);

          return SlideTransition(
            position: slide,
            child: ScaleTransition(
              scale: scale,
              alignment: Alignment.bottomCenter,
              child: FadeTransition(
                opacity: fade,
                child: child,
              ),
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

    final dominantColor = _musicService.dominantColor;
    final vibrantColor = _musicService.vibrantColor;

    return RepaintBoundary(
      child: GestureDetector(
        onTap: _openPlayerScreen,
        onVerticalDragEnd: (details) {
          if (details.primaryVelocity != null && details.primaryVelocity! < -120) {
            _openPlayerScreen();
          }
        },
        onHorizontalDragStart: (_) {
          setState(() {
            _isDraggingHorizontal = true;
          });
        },
        onHorizontalDragUpdate: (details) {
          setState(() {
            // Apply rubber-band damping to drag offset
            _dragOffset += details.primaryDelta ?? 0;
            _dragOffset = _dragOffset.clamp(-80.0, 80.0);
          });
        },
        onHorizontalDragEnd: (details) {
          if (_dragOffset < -40 || (details.primaryVelocity != null && details.primaryVelocity! < -250)) {
            HapticFeedback.mediumImpact();
            _musicService.nextSong();
          } else if (_dragOffset > 40 || (details.primaryVelocity != null && details.primaryVelocity! > 250)) {
            HapticFeedback.mediumImpact();
            _musicService.previousSong();
          }
          setState(() {
            _dragOffset = 0.0;
            _isDraggingHorizontal = false;
          });
        },
        onHorizontalDragCancel: () {
          setState(() {
            _dragOffset = 0.0;
            _isDraggingHorizontal = false;
          });
        },
        child: AnimatedContainer(
          duration: _isDraggingHorizontal ? Duration.zero : const Duration(milliseconds: 300),
          curve: Curves.easeOutBack,
          transform: Matrix4.translationValues(_dragOffset, 0, 0),
          margin: const EdgeInsets.only(left: 14, right: 14, bottom: 4),
          height: 66,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.55),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: vibrantColor.withValues(alpha: 0.28),
                blurRadius: 18,
                spreadRadius: 1,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: Color.alphaBlend(
                    dominantColor.withValues(alpha: 0.25),
                    const Color(0xEA101018),
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                    width: 0.9,
                  ),
                ),
                child: Stack(
                  children: [
                    // Main Player Content Row
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Row(
                        children: [
                          // Album Thumbnail with Hero Tag & Specular Rim
                          Hero(
                            tag: 'player_artwork_${song?.id.value}',
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.18),
                                  width: 0.8,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.4),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: song != null
                                    ? Image.network(
                                        hdThumbnail,
                                        fit: BoxFit.cover,
                                        filterQuality: FilterQuality.medium,
                                        cacheWidth: 140,
                                        cacheHeight: 140,
                                        errorBuilder: (_, _, _) => Image.network(
                                          song.thumbnails.lowResUrl,
                                          fit: BoxFit.cover,
                                          cacheWidth: 140,
                                          cacheHeight: 140,
                                        ),
                                      )
                                    : Container(color: Colors.grey[900]),
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
                                    if (isPlaying) ...[
                                      Padding(
                                        padding: const EdgeInsets.only(right: 6),
                                        child: AnimatedEqualizer(
                                          isPlaying: true,
                                          color: vibrantColor,
                                        ),
                                      ),
                                    ],
                                    Expanded(
                                      child: Hero(
                                        tag: 'player_title_${song?.id.value}',
                                        child: Material(
                                          color: Colors.transparent,
                                          child: Text(
                                            song?.title ?? 'Loading...',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14,
                                              letterSpacing: -0.3,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
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

                          // Control Buttons (Previous, Play/Pause & Next)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.skip_previous_rounded, color: Colors.white70, size: 24),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                visualDensity: VisualDensity.compact,
                                onPressed: () {
                                  HapticFeedback.lightImpact();
                                  _musicService.previousSong();
                                },
                              ),
                              const SizedBox(width: 2),
                              isLoading
                                  ? const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 6.0),
                                      child: SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                                      ),
                                    )
                                  : Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        customBorder: const CircleBorder(),
                                        onTap: () {
                                          HapticFeedback.mediumImpact();
                                          _musicService.togglePlayPause();
                                        },
                                        child: Container(
                                          width: 38,
                                          height: 38,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Colors.white.withValues(alpha: 0.12),
                                            border: Border.all(
                                              color: Colors.white.withValues(alpha: 0.20),
                                              width: 1.0,
                                            ),
                                          ),
                                          child: Center(
                                            child: Icon(
                                              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                              color: Colors.white,
                                              size: 24,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                              const SizedBox(width: 2),
                              IconButton(
                                icon: const Icon(Icons.skip_next_rounded, color: Colors.white70, size: 24),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                visualDensity: VisualDensity.compact,
                                onPressed: () {
                                  HapticFeedback.lightImpact();
                                  _musicService.nextSong();
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Ultra-Thin Glowing Radiant Progress Bar on the bottom edge
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: StreamBuilder<Duration>(
                        stream: _musicService.positionStream,
                        builder: (context, snapshot) {
                          final position = snapshot.data ?? _musicService.position;
                          final duration = _musicService.duration ?? (_musicService.currentSong?.duration ?? Duration.zero);
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
                                    vibrantColor,
                                    Theme.of(context).primaryColor,
                                    Colors.white,
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: vibrantColor.withValues(alpha: 0.9),
                                    blurRadius: 5,
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
      ),
    );
  }
}

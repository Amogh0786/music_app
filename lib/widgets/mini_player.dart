import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:just_audio/just_audio.dart';
import '../services/music_service.dart';
import '../screens/player_screen.dart';

class MiniPlayer extends StatefulWidget {
  const MiniPlayer({super.key});

  /// Screen-level visibility policy. When false, the mini-player hides itself.
  static final ValueNotifier<bool> isVisible = ValueNotifier<bool>(true);

  /// Temporarily hides the mini-player while a specific screen is active.
  static void hide() {
    isVisible.value = false;
  }

  /// Restores mini-player visibility when leaving a screen.
  static void show() {
    isVisible.value = true;
  }

  @override
  State<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<MiniPlayer> {
  final MusicService _musicService = MusicService();

  @override
  void initState() {
    super.initState();
    _musicService.addListener(_onMusicStateChanged);
    MiniPlayer.isVisible.addListener(_onVisibilityChanged);
  }

  @override
  void dispose() {
    _musicService.removeListener(_onMusicStateChanged);
    MiniPlayer.isVisible.removeListener(_onVisibilityChanged);
    super.dispose();
  }

  void _onVisibilityChanged() {
    if (!mounted) return;
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
      WidgetsBinding.instance.scheduleFrame();
    } else {
      setState(() {});
    }
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
        pageBuilder: (context, animation, secondaryAnimation) =>
            const PlayerScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curve = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInOutCubic,
          );

          final scale = Tween<double>(begin: 0.88, end: 1.0).animate(curve);
          final slide = Tween<Offset>(
            begin: const Offset(0.0, 0.88),
            end: Offset.zero,
          ).animate(curve);
          final fade = Tween<double>(begin: 0.0, end: 1.0).animate(curve);

          return SlideTransition(
            position: slide,
            child: ScaleTransition(
              scale: scale,
              alignment: Alignment.bottomCenter,
              child: FadeTransition(opacity: fade, child: child),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!MiniPlayer.isVisible.value) {
      return const SizedBox.shrink();
    }

    final song = _musicService.currentSong;
    final isPlaying = _musicService.isPlaying;
    final processingState = _musicService.audioPlayer.processingState;
    final isBuffering =
        !kIsWeb &&
        (processingState == ProcessingState.buffering ||
            processingState == ProcessingState.loading);
    final isLoading = !isPlaying && (_musicService.isLoading || isBuffering);
    final hdThumbnail = song != null
        ? MusicService.getHdThumbnail(song.id.value)
        : '';

    if (song == null && !isLoading) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: _openPlayerScreen,
      onVerticalDragEnd: (details) {
        if (details.primaryVelocity != null &&
            details.primaryVelocity! < -120) {
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
      child: RepaintBoundary(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 600),
          margin: const EdgeInsets.only(left: 16, right: 16, bottom: 4),
          height: 66,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.10),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF161622).withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                  width: 1,
                ),
              ),
              child: Stack(
                children: [
                  // Main Player Content Row
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        // Album Thumbnail
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                            width: 48,
                            height: 48,
                            child: (hdThumbnail.isNotEmpty)
                                ? Image.network(
                                    hdThumbnail,
                                    fit: BoxFit.cover,
                                    cacheWidth: 120,
                                    cacheHeight: 120,
                                    errorBuilder: (_, _, _) =>
                                        (song != null &&
                                            song
                                                .thumbnails
                                                .highResUrl
                                                .isNotEmpty)
                                        ? Image.network(
                                            song.thumbnails.highResUrl,
                                            fit: BoxFit.cover,
                                            cacheWidth: 120,
                                            cacheHeight: 120,
                                            errorBuilder: (_, _, _) =>
                                                (song
                                                    .thumbnails
                                                    .lowResUrl
                                                    .isNotEmpty)
                                                ? Image.network(
                                                    song.thumbnails.lowResUrl,
                                                    fit: BoxFit.cover,
                                                    cacheWidth: 120,
                                                    cacheHeight: 120,
                                                    errorBuilder: (_, _, _) =>
                                                        Container(
                                                          color: const Color(
                                                            0xFF1E1E28,
                                                          ),
                                                          child: const Icon(
                                                            Icons
                                                                .music_note_rounded,
                                                            color:
                                                                Colors.white38,
                                                          ),
                                                        ),
                                                  )
                                                : Container(
                                                    color: const Color(
                                                      0xFF1E1E28,
                                                    ),
                                                    child: const Icon(
                                                      Icons.music_note_rounded,
                                                      color: Colors.white38,
                                                    ),
                                                  ),
                                          )
                                        : Container(
                                            color: const Color(0xFF1E1E28),
                                            child: const Icon(
                                              Icons.music_note_rounded,
                                              color: Colors.white38,
                                            ),
                                          ),
                                  )
                                : Container(
                                    color: const Color(0xFF1E1E28),
                                    child: const Icon(
                                      Icons.music_note_rounded,
                                      color: Colors.white38,
                                    ),
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
                              Text(
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
                              icon: const Icon(
                                Icons.skip_previous_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
                              visualDensity: VisualDensity.compact,
                              onPressed: () {
                                HapticFeedback.lightImpact();
                                _musicService.previousSong();
                              },
                            ),
                            const SizedBox(width: 2),
                            isLoading
                                ? const Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 6.0,
                                    ),
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    ),
                                  )
                                : IconButton(
                                    icon: Icon(
                                      isPlaying
                                          ? Icons.pause_rounded
                                          : Icons.play_arrow_rounded,
                                      color: Colors.white,
                                      size: 30,
                                    ),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                      minWidth: 36,
                                      minHeight: 36,
                                    ),
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () {
                                      HapticFeedback.mediumImpact();
                                      _musicService.togglePlayPause();
                                    },
                                  ),
                            const SizedBox(width: 2),
                            IconButton(
                              icon: const Icon(
                                Icons.skip_next_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
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

                  // Ultra-Thin Glowing Progress Bar on the bottom edge
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: StreamBuilder<Duration?>(
                      stream: _musicService.durationStream,
                      initialData: _musicService.duration,
                      builder: (context, durSnapshot) {
                        return StreamBuilder<Duration>(
                          stream: _musicService.positionStream,
                          initialData: _musicService.position,
                          builder: (context, snapshot) {
                            final position = snapshot.data ?? Duration.zero;
                            final duration =
                                durSnapshot.data ??
                                _musicService.duration ??
                                Duration.zero;
                            double progress = 0.0;
                            if (duration.inMilliseconds > 0) {
                              progress =
                                  (position.inMilliseconds /
                                          duration.inMilliseconds)
                                      .clamp(0.0, 1.0);
                            }

                            return FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: progress,
                              child: Container(
                                height: 2.5,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            );
                          },
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

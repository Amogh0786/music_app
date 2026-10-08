import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../../layouts/desktop_layout_state.dart';
import '../../services/music_service.dart';

/// Spotify-grade 90px Edge-to-Edge Bottom Now Playing Deck (#now-playing-bar).
///
/// Features:
/// 1. Left (Flex 3): Track Artwork squircle, title/artist, interactive Like button.
/// 2. Center (Flex 5): Shuffle, Prev, Master Play/Pause, Next, Repeat + Isolated Scrubber.
/// 3. Right (Flex 3): Synced Lyrics, Queue, Volume slider with mute toggle, Side panel dock.
///
/// PERFORMANCE GUARANTEE: High-frequency position stream ticks are strictly isolated to
/// the [_DesktopTimelineScrubber] micro-widget to ensure zero full-deck or shell repaints.
class DesktopNowPlayingBar extends StatelessWidget {
  const DesktopNowPlayingBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 90.0,
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      decoration: BoxDecoration(
        color: const Color(0xFF0B0B0F),
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1.0,
          ),
        ),
      ),
      child: const Row(
        children: [
          // Region 1: Left Track Info + Like Button (Flex: 3, Min-width: 180px)
          Expanded(flex: 3, child: _DesktopTrackInfoSection()),

          // Region 2: Center Controls + Scrubber (Flex: 5, Max-width: 722px)
          Expanded(flex: 5, child: _DesktopCenterPlaybackSection()),

          // Region 3: Right System Utilities + Volume (Flex: 3)
          Expanded(flex: 3, child: _DesktopUtilitiesSection()),
        ],
      ),
    );
  }
}

/// Region 1: Left Track Info Section (Listens only to track metadata & like changes).
class _DesktopTrackInfoSection extends StatelessWidget {
  const _DesktopTrackInfoSection();

  @override
  Widget build(BuildContext context) {
    final musicService = MusicService();

    return AnimatedBuilder(
      animation: musicService,
      builder: (context, _) {
        final song = musicService.currentSong;
        if (song == null) {
          return Row(
            children: [
              Container(
                width: 56.0,
                height: 56.0,
                decoration: BoxDecoration(
                  color: const Color(0xFF161622),
                  borderRadius: BorderRadius.circular(6.0),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
                child: const Icon(
                  Icons.music_note_rounded,
                  color: Colors.white24,
                  size: 24.0,
                ),
              ),
              const SizedBox(width: 12.0),
              const Expanded(
                child: Text(
                  'No track playing',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 13.0,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          );
        }

        final hdThumbnail = MusicService.getHdThumbnail(song.id.value);
        final artworkUrl = hdThumbnail.isNotEmpty
            ? hdThumbnail
            : (song.thumbnails.lowResUrl.isNotEmpty
                  ? song.thumbnails.lowResUrl
                  : '');
        final isLiked = musicService.isLiked(song.id.value);

        return Row(
          children: [
            // 56x56 Squircle Album Artwork
            ClipRRect(
              borderRadius: BorderRadius.circular(6.0),
              child: Container(
                width: 56.0,
                height: 56.0,
                color: const Color(0xFF161622),
                child: artworkUrl.isNotEmpty
                    ? Image.network(
                        artworkUrl,
                        fit: BoxFit.cover,
                        cacheWidth: 120,
                        cacheHeight: 120,
                        errorBuilder: (_, _, _) => const Icon(
                          Icons.music_note_rounded,
                          color: Colors.white38,
                          size: 24.0,
                        ),
                      )
                    : const Icon(
                        Icons.music_note_rounded,
                        color: Colors.white38,
                        size: 24.0,
                      ),
              ),
            ),
            const SizedBox(width: 12.0),

            // Track Title & Artist Name
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3.0),
                  Text(
                    song.author,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.65),
                      fontSize: 12.0,
                      fontWeight: FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Interactive Like Button
            IconButton(
              tooltip: isLiked
                  ? 'Remove from Liked Songs'
                  : 'Save to Liked Songs',
              icon: Icon(
                isLiked
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                color: isLiked
                    ? const Color(0xFFFA2D48)
                    : Colors.white.withValues(alpha: 0.6),
                size: 20.0,
              ),
              onPressed: () => musicService.toggleLike(song),
            ),
          ],
        );
      },
    );
  }
}

/// Region 2: Center Controls and Timeline Scrubber.
class _DesktopCenterPlaybackSection extends StatelessWidget {
  const _DesktopCenterPlaybackSection();

  @override
  Widget build(BuildContext context) {
    final musicService = MusicService();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 722.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Top Controls Row
            AnimatedBuilder(
              animation: musicService,
              builder: (context, _) {
                final isShuffle = musicService.isShuffle;
                final isPlaying = musicService.isPlaying;
                final isLoading = musicService.isLoading;
                final isRepeat = musicService.loopMode != LoopMode.off;
                final isRepeatOne = musicService.loopMode == LoopMode.one;

                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Shuffle Button
                    IconButton(
                      tooltip: isShuffle ? 'Disable Shuffle' : 'Enable Shuffle',
                      icon: Icon(
                        Icons.shuffle_rounded,
                        color: isShuffle
                            ? const Color(0xFFFA2D48)
                            : Colors.white.withValues(alpha: 0.6),
                        size: 19.0,
                      ),
                      onPressed: () => musicService.toggleShuffle(),
                    ),

                    // Previous Track Button
                    IconButton(
                      tooltip: 'Previous Track',
                      icon: const Icon(
                        Icons.skip_previous_rounded,
                        color: Colors.white,
                        size: 24.0,
                      ),
                      onPressed: () => musicService.previousSong(),
                    ),
                    const SizedBox(width: 6.0),

                    // Master Play/Pause Button (36x36 Circular White Pill)
                    GestureDetector(
                      onTap: () => musicService.togglePlayPause(),
                      child: Container(
                        width: 36.0,
                        height: 36.0,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: isLoading
                              ? const SizedBox(
                                  width: 18.0,
                                  height: 18.0,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: Colors.black,
                                  ),
                                )
                              : Icon(
                                  isPlaying
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  color: Colors.black,
                                  size: 22.0,
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6.0),

                    // Next Track Button
                    IconButton(
                      tooltip: 'Next Track',
                      icon: const Icon(
                        Icons.skip_next_rounded,
                        color: Colors.white,
                        size: 24.0,
                      ),
                      onPressed: () => musicService.nextSong(),
                    ),

                    // Repeat Mode Button
                    IconButton(
                      tooltip: isRepeatOne
                          ? 'Repeat One'
                          : (isRepeat ? 'Repeat All' : 'Enable Repeat'),
                      icon: Icon(
                        isRepeatOne
                            ? Icons.repeat_one_rounded
                            : Icons.repeat_rounded,
                        color: isRepeat
                            ? const Color(0xFFFA2D48)
                            : Colors.white.withValues(alpha: 0.6),
                        size: 19.0,
                      ),
                      onPressed: () => musicService.toggleRepeat(),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 2.0),

            // Bottom Timeline Scrubber Row (Isolated Micro-Widget)
            const _DesktopTimelineScrubber(),
          ],
        ),
      ),
    );
  }
}

/// Isolated Micro-Subtree for high-frequency scrubber updates.
/// Rebuilds ONLY this widget when playback position ticks.
class _DesktopTimelineScrubber extends StatefulWidget {
  const _DesktopTimelineScrubber();

  @override
  State<_DesktopTimelineScrubber> createState() =>
      _DesktopTimelineScrubberState();
}

class _DesktopTimelineScrubberState extends State<_DesktopTimelineScrubber> {
  final MusicService _musicService = MusicService();
  double? _dragPositionSeconds;

  String _formatDuration(Duration? d) {
    if (d == null || d.inSeconds <= 0) return '0:00';
    final minutes = d.inMinutes;
    final seconds = d.inSeconds.remainder(60);
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration>(
      stream: _musicService.audioPlayer.positionStream,
      builder: (context, snapshot) {
        final position = snapshot.data ?? Duration.zero;
        final totalDuration =
            _musicService.audioPlayer.duration ??
            _musicService.currentSong?.duration ??
            Duration.zero;

        final posSec = position.inMilliseconds / 1000.0;
        final durSec = totalDuration.inMilliseconds / 1000.0;

        final maxVal = durSec > 0 ? durSec : 1.0;
        final currentVal = (_dragPositionSeconds ?? posSec).clamp(0.0, maxVal);

        return Row(
          children: [
            // Elapsed Timestamp
            SizedBox(
              width: 42.0,
              child: Text(
                _formatDuration(
                  Duration(milliseconds: (currentVal * 1000).toInt()),
                ),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 11.0,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
                textAlign: TextAlign.right,
              ),
            ),
            const SizedBox(width: 8.0),

            // Interactive Progress Slider
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3.5,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 5.5,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 10.0,
                  ),
                  activeTrackColor: const Color(0xFFFA2D48),
                  inactiveTrackColor: Colors.white.withValues(alpha: 0.15),
                  thumbColor: Colors.white,
                  overlayColor: const Color(0xFFFA2D48).withValues(alpha: 0.2),
                ),
                child: Slider(
                  value: currentVal,
                  min: 0.0,
                  max: maxVal,
                  onChangeStart: (val) {
                    setState(() => _dragPositionSeconds = val);
                  },
                  onChanged: (val) {
                    setState(() => _dragPositionSeconds = val);
                  },
                  onChangeEnd: (val) {
                    final target = Duration(milliseconds: (val * 1000).toInt());
                    _musicService.audioPlayer.seek(target);
                    setState(() => _dragPositionSeconds = null);
                  },
                ),
              ),
            ),
            const SizedBox(width: 8.0),

            // Total Duration Timestamp
            SizedBox(
              width: 42.0,
              child: Text(
                _formatDuration(totalDuration),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 11.0,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
                textAlign: TextAlign.left,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Region 3: Right System Utilities and Volume Controls.
class _DesktopUtilitiesSection extends StatefulWidget {
  const _DesktopUtilitiesSection();

  @override
  State<_DesktopUtilitiesSection> createState() =>
      _DesktopUtilitiesSectionState();
}

class _DesktopUtilitiesSectionState extends State<_DesktopUtilitiesSection> {
  final MusicService _musicService = MusicService();
  double _lastVolume = 1.0;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Synced Lyrics Toggle
        ValueListenableBuilder<DesktopContextTab>(
          valueListenable: DesktopLayoutState.contextTab,
          builder: (context, tab, _) {
            return ValueListenableBuilder<bool>(
              valueListenable: DesktopLayoutState.isRightPanelVisible,
              builder: (context, isVisible, _) {
                final active = isVisible && tab == DesktopContextTab.lyrics;
                return IconButton(
                  tooltip: 'Lyrics',
                  icon: Icon(
                    Icons.lyrics_rounded,
                    color: active
                        ? const Color(0xFFFA2D48)
                        : Colors.white.withValues(alpha: 0.6),
                    size: 19.0,
                  ),
                  onPressed: () {
                    if (active) {
                      DesktopLayoutState.toggleRightPanel();
                    } else {
                      DesktopLayoutState.setContextTab(
                        DesktopContextTab.lyrics,
                      );
                    }
                  },
                );
              },
            );
          },
        ),

        // Queue Toggle
        ValueListenableBuilder<DesktopContextTab>(
          valueListenable: DesktopLayoutState.contextTab,
          builder: (context, tab, _) {
            return ValueListenableBuilder<bool>(
              valueListenable: DesktopLayoutState.isRightPanelVisible,
              builder: (context, isVisible, _) {
                final active = isVisible && tab == DesktopContextTab.queue;
                return IconButton(
                  tooltip: 'Queue',
                  icon: Icon(
                    Icons.queue_music_rounded,
                    color: active
                        ? const Color(0xFFFA2D48)
                        : Colors.white.withValues(alpha: 0.6),
                    size: 19.0,
                  ),
                  onPressed: () {
                    if (active) {
                      DesktopLayoutState.toggleRightPanel();
                    } else {
                      DesktopLayoutState.setContextTab(DesktopContextTab.queue);
                    }
                  },
                );
              },
            );
          },
        ),

        const SizedBox(width: 8.0),

        // Volume Mute / Unmute Button
        StreamBuilder<double>(
          stream: _musicService.audioPlayer.volumeStream,
          builder: (context, snapshot) {
            final volume = snapshot.data ?? _musicService.audioPlayer.volume;
            final isMuted = volume <= 0.001;

            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: isMuted ? 'Unmute' : 'Mute',
                  icon: Icon(
                    isMuted
                        ? Icons.volume_off_rounded
                        : (volume < 0.5
                              ? Icons.volume_down_rounded
                              : Icons.volume_up_rounded),
                    color: Colors.white.withValues(alpha: 0.6),
                    size: 19.0,
                  ),
                  onPressed: () {
                    if (isMuted) {
                      _musicService.audioPlayer.setVolume(
                        _lastVolume > 0 ? _lastVolume : 1.0,
                      );
                    } else {
                      _lastVolume = volume;
                      _musicService.audioPlayer.setVolume(0.0);
                    }
                  },
                ),

                // Sleek 96px Volume Slider
                SizedBox(
                  width: 96.0,
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3.5,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 4.5,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 8.0,
                      ),
                      activeTrackColor: Colors.white,
                      inactiveTrackColor: Colors.white.withValues(alpha: 0.15),
                      thumbColor: Colors.white,
                      overlayColor: Colors.white.withValues(alpha: 0.15),
                    ),
                    child: Slider(
                      value: volume.clamp(0.0, 1.0),
                      min: 0.0,
                      max: 1.0,
                      onChanged: (val) {
                        _lastVolume = val;
                        _musicService.audioPlayer.setVolume(val);
                      },
                    ),
                  ),
                ),
              ],
            );
          },
        ),

        const SizedBox(width: 6.0),

        // Right Panel Visibility Toggle
        IconButton(
          tooltip: 'Toggle Now Playing Panel',
          icon: Icon(
            Icons.dock_rounded,
            color: Colors.white.withValues(alpha: 0.6),
            size: 19.0,
          ),
          onPressed: () => DesktopLayoutState.toggleRightPanel(),
        ),
      ],
    );
  }
}

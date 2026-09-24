import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../services/music_service.dart';
import '../services/preferences_service.dart';
import '../widgets/vinyl_record_player.dart';
import '../widgets/waveform_scrubber.dart';
import '../widgets/song_options_bottom_sheet.dart';
import '../widgets/equalizer_bottom_sheet.dart';
import '../widgets/animated_lyrics.dart';


class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with TickerProviderStateMixin {
  final MusicService _musicService = MusicService();
  final PreferencesService _prefs = PreferencesService();

  late AnimationController _ambientController;
  late AnimationController _bubbleController;
  late PageController _pageController;
  bool _isUserDraggingPage = false;
  bool _showLyrics = false;

  @override
  void initState() {
    super.initState();
    _musicService.addListener(_onStateChanged);
    _prefs.addListener(_onStateChanged);

    final initialPage = _musicService.playlist.isNotEmpty
        ? _musicService.currentIndex.clamp(0, _musicService.playlist.length - 1)
        : 0;
    _pageController = PageController(
      initialPage: initialPage,
      viewportFraction: 0.82,
    );

    // Continuous slow rotation for living ambient aura
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
    )..repeat();

    // Subtle fluid bubble movement controller for bottom glass bar
    _bubbleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();
  }

  @override
  void dispose() {
    _ambientController.dispose();
    _bubbleController.dispose();
    _pageController.dispose();
    _musicService.removeListener(_onStateChanged);
    _prefs.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    if (!mounted) return;
    if (_pageController.hasClients && _pageController.position.hasContentDimensions) {
      final currentPage = _pageController.page?.round() ?? _musicService.currentIndex;
      if (currentPage != _musicService.currentIndex && !_isUserDraggingPage) {
        _pageController.animateToPage(
          _musicService.currentIndex,
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeOutCubic,
        );
      }
    }
    setState(() {});
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) return '0:00';
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String _cleanLyrics(String? raw) {
    if (raw == null) return 'No lyrics available.';
    final cleaned = raw.replaceAll(RegExp(r'\[\d+:\d+(\.\d+)?\]'), '').trim();
    return cleaned.isEmpty ? 'No lyrics available.' : cleaned;
  }

  void _toggleLyrics(Video song) {
    HapticFeedback.lightImpact();
    setState(() {
      _showLyrics = !_showLyrics;
    });
    if (_showLyrics) {
      _musicService.fetchLyrics(song);
    }
  }

  void _showQueueSheet(BuildContext context) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final playlist = _musicService.playlist;
            final currentIndex = _musicService.currentIndex;

            return BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.78,
                decoration: BoxDecoration(
                  color: const Color(0xFF16161E).withValues(alpha: 0.96),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white30,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
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
                              const SizedBox(height: 2),
                              Text(
                                'Drag ☰ on the left to change priority',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white12,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${playlist.length} Tracks',
                              style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
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
                          : ReorderableListView.builder(
                              buildDefaultDragHandles: false,
                              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
                              itemCount: playlist.length,
                              // ignore: deprecated_member_use
                              onReorder: (oldIndex, newIndex) {
                                HapticFeedback.selectionClick();
                                _musicService.reorderQueue(oldIndex, newIndex);
                                setSheetState(() {});
                              },
                              itemBuilder: (context, index) {
                                final song = playlist[index];
                                final isCurrent = index == currentIndex;
                                final hdThumbnail = MusicService.getHdThumbnail(song.id.value);

                                return Container(
                                  key: ValueKey('${song.id.value}_$index'),
                                  margin: const EdgeInsets.symmetric(vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isCurrent
                                        ? Theme.of(context).primaryColor.withValues(alpha: 0.16)
                                        : const Color(0xFF1B1B26),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: isCurrent
                                          ? Theme.of(context).primaryColor.withValues(alpha: 0.45)
                                          : Colors.white.withValues(alpha: 0.07),
                                      width: 1,
                                    ),
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(14),
                                      onTap: () {
                                        Navigator.pop(context);
                                        _musicService.playPlaylist(playlist, index);
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                                        child: Row(
                                          children: [
                                            // Far left 3-line handle for priority reordering
                                            ReorderableDragStartListener(
                                              index: index,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                                child: const Icon(
                                                  Icons.menu_rounded,
                                                  color: Colors.white60,
                                                  size: 20,
                                                ),
                                              ),
                                            ),
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(8),
                                              child: Image.network(
                                                hdThumbnail,
                                                width: 44,
                                                height: 44,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, _, _) => Image.network(
                                                  song.thumbnails.lowResUrl,
                                                  width: 44,
                                                  height: 44,
                                                  fit: BoxFit.cover,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    song.title,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      color: isCurrent ? Theme.of(context).primaryColor : Colors.white,
                                                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                                                      fontSize: 13.5,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    song.author,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      color: isCurrent
                                                          ? Theme.of(context).primaryColor.withValues(alpha: 0.8)
                                                          : Colors.white54,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (isCurrent)
                                              Padding(
                                                padding: const EdgeInsets.only(right: 6),
                                                child: Icon(Icons.equalizer_rounded, color: Theme.of(context).primaryColor, size: 22),
                                              ),
                                            IconButton(
                                              icon: const Icon(Icons.more_vert_rounded, color: Colors.white38, size: 18),
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                              onPressed: () {
                                                showSongOptionsBottomSheet(context, song);
                                              },
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.close_rounded, color: Colors.white38, size: 18),
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                              onPressed: () {
                                                HapticFeedback.lightImpact();
                                                _musicService.removeFromQueue(index);
                                                setSheetState(() {});
                                              },
                                            ),
                                            const SizedBox(width: 4),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showSleepTimerSheet(BuildContext context) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF16161E).withValues(alpha: 0.96),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white30,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Sleep Timer',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_musicService.isSleepTimerActive)
                      TextButton(
                        onPressed: () {
                          _musicService.cancelSleepTimer();
                          Navigator.pop(context);
                        },
                        child: const Text('Turn Off', style: TextStyle(color: Colors.redAccent)),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildSleepOption(context, '15 minutes', const Duration(minutes: 15)),
                _buildSleepOption(context, '30 minutes', const Duration(minutes: 30)),
                _buildSleepOption(context, '45 minutes', const Duration(minutes: 45)),
                _buildSleepOption(context, '1 hour', const Duration(hours: 1)),
                ListTile(
                  leading: const Icon(Icons.music_off_outlined, color: Colors.white70),
                  title: const Text('End of current track', style: TextStyle(color: Colors.white)),
                  trailing: _musicService.stopAtEndOfTrack
                      ? const Icon(Icons.check, color: Color(0xFF1DB954))
                      : null,
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

  Widget _buildSleepOption(BuildContext context, String label, Duration duration) {
    final isSelected = _musicService.sleepRemaining != null &&
        (_musicService.sleepRemaining!.inMinutes - duration.inMinutes).abs() < 1;

    return ListTile(
      leading: const Icon(Icons.timer_outlined, color: Colors.white70),
      title: Text(label, style: const TextStyle(color: Colors.white)),
      trailing: isSelected ? const Icon(Icons.check, color: Color(0xFF1DB954)) : null,
      onTap: () {
        _musicService.startSleepTimer(duration);
        Navigator.pop(context);
      },
    );
  }

  void _showCurrentSongActionsSheet(BuildContext context, Video song) {
    HapticFeedback.lightImpact();
    final hdThumbnail = MusicService.getHdThumbnail(song.id.value);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final isLiked = _musicService.likedSongs.any((s) => s['id'] == song.id.value);
            final isDownloaded = _musicService.downloadedSongs.any((s) => s['id'] == song.id.value);

            return BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: Container(
                padding: const EdgeInsets.only(top: 14, bottom: 28),
                decoration: BoxDecoration(
                  color: const Color(0xFF14141E).withValues(alpha: 0.95),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Drag pill
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Song Header Info
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              hdThumbnail,
                              width: 52,
                              height: 52,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Container(
                                width: 52,
                                height: 52,
                                color: const Color(0xFF1E1E28),
                                child: const Icon(Icons.music_note, color: Colors.white54),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  song.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  song.author,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.65),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),
                    const Divider(color: Colors.white10, height: 1),
                    const SizedBox(height: 8),

                    // 1. Sleep Timer
                    _buildSongActionTile(
                      icon: Icons.bedtime_rounded,
                      iconColor: _musicService.isSleepTimerActive ? Theme.of(context).primaryColor : Colors.white,
                      title: 'Sleep Timer',
                      subtitle: _musicService.isSleepTimerActive
                          ? 'Active (${_musicService.sleepTimerLabel})'
                          : 'Set auto-stop timer',
                      trailing: _musicService.isSleepTimerActive
                          ? Icon(Icons.check_circle_rounded, color: Theme.of(context).primaryColor, size: 20)
                          : const Icon(Icons.chevron_right_rounded, color: Colors.white30, size: 20),
                      onTap: () {
                        Navigator.pop(ctx);
                        _showSleepTimerSheet(context);
                      },
                    ),

                    // 2. Add to Playlist
                    _buildSongActionTile(
                      icon: Icons.playlist_add_rounded,
                      title: 'Add to Playlist',
                      subtitle: 'Save to your custom playlists',
                      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white30, size: 20),
                      onTap: () {
                        Navigator.pop(ctx);
                        showAddToPlaylistSheet(context, song);
                      },
                    ),

                    // 3. Like Song
                    _buildSongActionTile(
                      icon: isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      iconColor: isLiked ? const Color(0xFFFA2D48) : Colors.white,
                      title: isLiked ? 'Liked Song' : 'Like Song',
                      subtitle: isLiked ? 'Saved in your favorites ❤️' : 'Save to Liked Songs',
                      trailing: isLiked
                          ? const Icon(Icons.check_rounded, color: Color(0xFFFA2D48), size: 20)
                          : null,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _musicService.toggleLike(song);
                        setSheetState(() {});
                        setState(() {});
                      },
                    ),

                    // 4. Download
                    _buildSongActionTile(
                      icon: isDownloaded ? Icons.download_done_rounded : Icons.download_for_offline_rounded,
                      iconColor: isDownloaded ? const Color(0xFF1DB954) : Colors.white,
                      title: isDownloaded ? 'Downloaded' : 'Download',
                      subtitle: isDownloaded ? 'Available offline' : 'Save audio file locally',
                      trailing: _musicService.isDownloading
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : (isDownloaded ? const Icon(Icons.check_rounded, color: Color(0xFF1DB954), size: 20) : null),
                      onTap: () async {
                        if (isDownloaded) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Song is already downloaded offline')),
                          );
                          return;
                        }
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Starting download...')),
                        );
                        final success = await _musicService.downloadSong(song);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(success ? 'Saved to Offline Library!' : 'Download failed.')),
                          );
                        }
                      },
                    ),

                    // 5. Share
                    _buildSongActionTile(
                      icon: Icons.share_rounded,
                      title: 'Share',
                      subtitle: 'Copy link or song details',
                      trailing: const Icon(Icons.copy_rounded, color: Colors.white30, size: 18),
                      onTap: () {
                        Navigator.pop(ctx);
                        Clipboard.setData(ClipboardData(text: '${song.title} - ${song.author}\n${song.url}'));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Song link copied to clipboard!')),
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSongActionTile({
    required IconData icon,
    Color iconColor = Colors.white,
    required String title,
    required String subtitle,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(
        title,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14.5),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 12),
      ),
      trailing: trailing,
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
    );
  }

  Widget _buildBarPillButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isActive = false,
    Color? activeColor,
    int? badgeCount,
  }) {
    final effectiveColor = activeColor ?? Theme.of(context).primaryColor;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(22),
        splashColor: effectiveColor.withValues(alpha: 0.2),
        highlightColor: Colors.white.withValues(alpha: 0.08),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: isActive
                ? effectiveColor.withValues(alpha: 0.24)
                : Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isActive
                  ? effectiveColor.withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: 0.12),
              width: 1.0,
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: effectiveColor.withValues(alpha: 0.35),
                      blurRadius: 14,
                      spreadRadius: 1,
                    )
                  ]
                : [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    icon,
                    size: 20,
                    color: isActive ? effectiveColor : Colors.white.withValues(alpha: 0.9),
                  ),
                  if (badgeCount != null && badgeCount > 0)
                    Positioned(
                      top: -6,
                      right: -10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: effectiveColor,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: effectiveColor.withValues(alpha: 0.5),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: Text(
                          '$badgeCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.85),
                  fontSize: 13,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
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
    final isLiked = song != null && _musicService.likedSongs.any((s) => s['id'] == song.id.value);
    final artworkStyle = _prefs.artworkStyle;

    if (song == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0B0B0F),
        body: Center(child: Text('No song active', style: TextStyle(color: Colors.white))),
      );
    }

    final dominantColor = _musicService.dominantColor;
    final vibrantColor = _musicService.vibrantColor;
    final darkVibrantColor = _musicService.darkVibrantColor;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0F),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onVerticalDragEnd: (details) {
          if (details.primaryVelocity == null) return;
          if (details.primaryVelocity! < -300) {
            HapticFeedback.lightImpact();
            _showQueueSheet(context);
          } else if (details.primaryVelocity! > 300) {
            HapticFeedback.lightImpact();
            Navigator.pop(context);
          }
        },
        child: Stack(
          children: [
            // 1. Dynamic Living Ambient Gradient Mesh Aura
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _ambientController,
                builder: (context, child) {
                  final progress = _ambientController.value;
                  final angle = progress * 2 * math.pi;

                  return Stack(
                    children: [
                      // Deep base color
                      Container(color: const Color(0xFF09090D)),

                      // Blob 1 (Top Left, rotating)
                      Positioned(
                        top: -100 + (math.sin(angle) * 40),
                        left: -100 + (math.cos(angle) * 40),
                        width: 440,
                        height: 440,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: dominantColor.withValues(alpha: 0.68),
                          ),
                        ),
                      ),

                      // Blob 2 (Mid Right, reverse rotating)
                      Positioned(
                        top: 180 + (math.cos(angle) * 50),
                        right: -120 + (math.sin(angle) * 50),
                        width: 400,
                        height: 400,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: vibrantColor.withValues(alpha: 0.60),
                          ),
                        ),
                      ),

                      // Central Dynamic Ambient Flare (anchored to artwork)
                      Positioned(
                        top: 140 + (math.sin(angle * 0.8) * 20),
                        left: -30,
                        right: -30,
                        height: 420,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                vibrantColor.withValues(alpha: 0.35),
                                dominantColor.withValues(alpha: 0.18),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Blob 3 (Bottom Center, breathing)
                      Positioned(
                        bottom: -80 + (math.sin(angle * 1.5) * 30),
                        left: 40 + (math.cos(angle * 1.5) * 30),
                        width: 360,
                        height: 360,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: darkVibrantColor.withValues(alpha: 0.55),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            // Frost blur overlay
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 65, sigmaY: 65),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.42),
                ),
              ),
            ),

            // 2. Main Player Content
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                child: Column(
                  children: [
                    // Top Grabber & Header Actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white70, size: 34),
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            Navigator.pop(context);
                          },
                        ),
                        GestureDetector(
                          onTap: () => _showQueueSheet(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            color: Colors.transparent,
                            child: Container(
                              width: 40,
                              height: 5,
                              decoration: BoxDecoration(
                                color: Colors.white24,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.tune_rounded, color: Colors.white, size: 24),
                          tooltip: 'Audio Equalizer',
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            EqualizerBottomSheet.show(context);
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Center Content: Dynamic 1:1 Swipe Album Carousel OR Synced Lyrics
                    if (!_showLyrics)
                      Expanded(
                        flex: 10,
                        child: Center(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final carouselSize = math.min(constraints.maxWidth * 0.88, constraints.maxHeight * 0.95);
                              final playlist = _musicService.playlist.isNotEmpty
                                  ? _musicService.playlist
                                  : [song];

                              return NotificationListener<ScrollNotification>(
                                onNotification: (notification) {
                                  if (notification is ScrollStartNotification) {
                                    _isUserDraggingPage = true;
                                  } else if (notification is ScrollEndNotification) {
                                    _isUserDraggingPage = false;
                                  }
                                  return false;
                                },
                                child: PageView.builder(
                                  controller: _pageController,
                                  itemCount: playlist.length,
                                  onPageChanged: (index) {
                                    if (_isUserDraggingPage && index != _musicService.currentIndex) {
                                      HapticFeedback.selectionClick();
                                      _musicService.skipToQueueIndex(index);
                                    }
                                  },
                                  physics: const BouncingScrollPhysics(),
                                  itemBuilder: (context, index) {
                                    final track = playlist[index];
                                    final isCurrent = index == _musicService.currentIndex;
                                    final trackHdThumbnail = MusicService.getHdThumbnail(track.id.value);

                                    return AnimatedBuilder(
                                      animation: _pageController,
                                      builder: (context, child) {
                                        double page = _musicService.currentIndex.toDouble();
                                        if (_pageController.hasClients && _pageController.position.hasContentDimensions) {
                                          page = _pageController.page ?? _musicService.currentIndex.toDouble();
                                        }
                                        final double diff = (page - index).abs();
                                        final double scale = (1.0 - (diff * 0.12)).clamp(0.85, 1.0);
                                        final double opacity = (1.0 - (diff * 0.45)).clamp(0.40, 1.0);

                                        return Transform.scale(
                                          scale: scale,
                                          child: Opacity(
                                            opacity: opacity,
                                            child: child,
                                          ),
                                        );
                                      },
                                      child: Center(
                                        child: artworkStyle == ArtworkStyle.vinyl
                                            ? VinylRecordPlayer(
                                                key: ValueKey('vinyl_${track.id.value}'),
                                                imageUrl: trackHdThumbnail,
                                                isPlaying: isCurrent && isPlaying,
                                                dominantColor: isCurrent ? dominantColor : const Color(0xFF1E1E2C),
                                                vibrantColor: isCurrent ? vibrantColor : const Color(0xFFFA2D48),
                                                size: carouselSize * 0.94,
                                              )
                                            : Container(
                                                width: carouselSize,
                                                height: carouselSize,
                                                decoration: BoxDecoration(
                                                  borderRadius: BorderRadius.circular(26),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: (isCurrent ? dominantColor : Colors.black).withValues(alpha: 0.60),
                                                      blurRadius: 36,
                                                      spreadRadius: 6,
                                                      offset: const Offset(0, 16),
                                                    ),
                                                    BoxShadow(
                                                      color: (isCurrent ? vibrantColor : Colors.black).withValues(alpha: 0.35),
                                                      blurRadius: 48,
                                                      spreadRadius: 8,
                                                      offset: const Offset(0, 8),
                                                    ),
                                                  ],
                                                ),
                                                child: isCurrent
                                                    ? Hero(
                                                        tag: 'player_artwork_${track.id.value}',
                                                        child: ClipRRect(
                                                          borderRadius: BorderRadius.circular(26),
                                                          child: Image.network(
                                                            trackHdThumbnail,
                                                            fit: BoxFit.cover,
                                                            errorBuilder: (_, _, _) => Image.network(
                                                              track.thumbnails.highResUrl,
                                                              fit: BoxFit.cover,
                                                              errorBuilder: (_, _, _) => Container(
                                                                color: const Color(0xFF222230),
                                                                child: const Icon(Icons.music_note, color: Colors.white54, size: 64),
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      )
                                                    : ClipRRect(
                                                        borderRadius: BorderRadius.circular(26),
                                                        child: Image.network(
                                                          trackHdThumbnail,
                                                          fit: BoxFit.cover,
                                                          errorBuilder: (_, _, _) => Image.network(
                                                            track.thumbnails.highResUrl,
                                                            fit: BoxFit.cover,
                                                            errorBuilder: (_, _, _) => Container(
                                                              color: const Color(0xFF222230),
                                                              child: const Icon(Icons.music_note, color: Colors.white54, size: 64),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                              ),
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                      )
                    else
                      Expanded(
                        flex: 10,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: _musicService.isFetchingLyrics
                              ? Center(
                                  child: CircularProgressIndicator(color: Theme.of(context).primaryColor),
                                )
                              : AnimatedLyrics(
                                  rawLyrics: _musicService.cachedLyrics ?? '',
                                  positionStream: _musicService.audioPlayer.positionStream,
                                ),
                        ),
                      ),

                    const SizedBox(height: 12),

                    // Track Info & Like Button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Hero(
                                tag: 'player_title_${song.id.value}',
                                child: Material(
                                  color: Colors.transparent,
                                  child: Text(
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
                                ),
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
                            isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            color: isLiked ? const Color(0xFFFA2D48) : Colors.white70,
                            size: 30,
                          ),
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            _musicService.toggleLike(song);
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Apple Music Style Shorter Scrubber (with generous horizontal padding)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: StreamBuilder<Duration>(
                        stream: _musicService.positionStream,
                        builder: (context, snapshot) {
                          final position = snapshot.data ?? Duration.zero;
                          final duration = _musicService.duration ??
                              (song.duration ?? Duration.zero);

                          if (_prefs.scrubberStyle == ScrubberStyle.classic) {
                            return _buildClassicScrubber(context, position, duration, vibrantColor);
                          }

                          return WaveformScrubber(
                            position: position,
                            duration: duration,
                            songId: song.id.value,
                            accentColor: vibrantColor,
                            onSeek: (newPos) {
                              _musicService.seek(newPos);
                            },
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Unified Playback Controls: Shuffle, -10s, Prev, Play/Pause, Next, +10s, Repeat
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.shuffle_rounded,
                              color: _musicService.isShuffle ? const Color(0xFF1DB954) : Colors.white54,
                              size: 22,
                            ),
                            onPressed: () {
                              HapticFeedback.selectionClick();
                              _musicService.toggleShuffle();
                            },
                          ),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () {
                                HapticFeedback.lightImpact();
                                _musicService.seekRelative(const Duration(seconds: -10));
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                                ),
                                child: const Icon(Icons.replay_10_rounded, color: Colors.white, size: 20),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.skip_previous_rounded, color: Colors.white, size: 40),
                            onPressed: () {
                              HapticFeedback.mediumImpact();
                              _musicService.previousSong();
                            },
                          ),
                          // Elevated Play/Pause Circle with Ambient Glow
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: vibrantColor.withValues(alpha: 0.5),
                                  blurRadius: 22,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: isLoading
                                ? const Padding(
                                    padding: EdgeInsets.all(22.0),
                                    child: CircularProgressIndicator(color: Colors.black, strokeWidth: 3),
                                  )
                                : IconButton(
                                    icon: Icon(
                                      isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                      color: Colors.black,
                                      size: 42,
                                    ),
                                    onPressed: () {
                                      HapticFeedback.mediumImpact();
                                      _musicService.togglePlayPause();
                                    },
                                  ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 40),
                            onPressed: () {
                              HapticFeedback.mediumImpact();
                              _musicService.nextSong();
                            },
                          ),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () {
                                HapticFeedback.lightImpact();
                                _musicService.seekRelative(const Duration(seconds: 10));
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                                ),
                                child: const Icon(Icons.forward_10_rounded, color: Colors.white, size: 20),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              _musicService.loopMode == LoopMode.one
                                  ? Icons.repeat_one_rounded
                                  : Icons.repeat_rounded,
                              color: _musicService.loopMode != LoopMode.off
                                  ? const Color(0xFF1DB954)
                                  : Colors.white54,
                              size: 22,
                            ),
                            onPressed: () {
                              HapticFeedback.selectionClick();
                              _musicService.toggleRepeat();
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Bottom Screen Options: 3 Main Glassmorphic Bubble Buttons
                    ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                        child: AnimatedBuilder(
                          animation: _bubbleController,
                          builder: (context, child) {
                            return CustomPaint(
                              painter: BubbleMovementPainter(
                                animationValue: _bubbleController.value,
                                dominantColor: dominantColor,
                                vibrantColor: vibrantColor,
                              ),
                              child: Container(
                                margin: const EdgeInsets.only(top: 4, bottom: 2),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(30),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.16),
                                    width: 1.1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.25),
                                      blurRadius: 18,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: child,
                              ),
                            );
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              // 1. Lyrics
                              _buildBarPillButton(
                                context: context,
                                icon: _showLyrics ? Icons.lyrics_rounded : Icons.lyrics_outlined,
                                label: 'Lyrics',
                                isActive: _showLyrics,
                                activeColor: vibrantColor,
                                onTap: () => _toggleLyrics(song),
                              ),

                              // 2. Queue (Up Next)
                              _buildBarPillButton(
                                context: context,
                                icon: Icons.queue_music_rounded,
                                label: 'Queue',
                                badgeCount: _musicService.playlist.length,
                                isActive: false,
                                activeColor: vibrantColor,
                                onTap: () => _showQueueSheet(context),
                              ),

                              // 3. Three Lines (More Options Layer)
                              _buildBarPillButton(
                                context: context,
                                icon: Icons.segment_rounded,
                                label: 'More',
                                isActive: false,
                                activeColor: vibrantColor,
                                onTap: () => _showCurrentSongActionsSheet(context, song),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildClassicScrubber(
    BuildContext context,
    Duration position,
    Duration duration,
    Color accentColor,
  ) {
    final maxMs = duration.inMilliseconds > 0 ? duration.inMilliseconds.toDouble() : 1.0;
    final curMs = position.inMilliseconds.clamp(0, maxMs.toInt()).toDouble();
    final remaining = duration > position ? duration - position : Duration.zero;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3.5,
              activeTrackColor: accentColor,
              inactiveTrackColor: Colors.white24,
              thumbColor: Colors.white,
              overlayColor: accentColor.withValues(alpha: 0.2),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6, elevation: 3),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            ),
            child: Slider(
              value: curMs,
              min: 0,
              max: maxMs,
              onChanged: (val) {
                HapticFeedback.selectionClick();
                _musicService.seek(Duration(milliseconds: val.toInt()));
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDuration(position),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '-${_formatDuration(remaining)}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter for dynamic organic liquid bubble movement in the bottom glass bar
class BubbleMovementPainter extends CustomPainter {
  final double animationValue;
  final Color dominantColor;
  final Color vibrantColor;

  BubbleMovementPainter({
    required this.animationValue,
    required this.dominantColor,
    required this.vibrantColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final progress = animationValue * 2 * math.pi;

    // Bubble 1: drifting left-to-center with vibrant hue
    final b1X = size.width * 0.22 + math.sin(progress) * (size.width * 0.12);
    final b1Y = size.height * 0.5 + math.cos(progress * 1.3) * (size.height * 0.25);
    final p1 = Paint()
      ..shader = RadialGradient(
        colors: [
          vibrantColor.withValues(alpha: 0.35),
          vibrantColor.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: Offset(b1X, b1Y), radius: 42));
    canvas.drawCircle(Offset(b1X, b1Y), 42, p1);

    // Bubble 2: drifting center-right with dominant hue
    final b2X = size.width * 0.70 + math.cos(progress * 0.9) * (size.width * 0.15);
    final b2Y = size.height * 0.45 + math.sin(progress * 1.6) * (size.height * 0.28);
    final p2 = Paint()
      ..shader = RadialGradient(
        colors: [
          dominantColor.withValues(alpha: 0.42),
          dominantColor.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: Offset(b2X, b2Y), radius: 48));
    canvas.drawCircle(Offset(b2X, b2Y), 48, p2);

    // Bubble 3: subtle white luminous orb floating across center
    final b3X = size.width * 0.48 + math.sin(progress * 1.5) * (size.width * 0.18);
    final b3Y = size.height * 0.55 + math.cos(progress) * (size.height * 0.22);
    final p3 = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.16),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: Offset(b3X, b3Y), radius: 30));
    canvas.drawCircle(Offset(b3X, b3Y), 30, p3);
  }

  @override
  bool shouldRepaint(covariant BubbleMovementPainter oldDelegate) => true;
}

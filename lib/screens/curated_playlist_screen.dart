import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../services/music_service.dart';
import '../widgets/mini_player.dart';
import '../widgets/animated_equalizer.dart';
import '../widgets/song_options_bottom_sheet.dart';
import '../widgets/dilse_scrollbar.dart';

class CuratedPlaylistScreen extends StatefulWidget {
  final String title;
  final String subtitle;
  final String? query;
  final List<Video>? initialSongs;
  final List<Color>? gradientColors;
  final IconData? icon;
  final String? imageUrl;

  const CuratedPlaylistScreen({
    super.key,
    required this.title,
    required this.subtitle,
    this.query,
    this.initialSongs,
    this.gradientColors,
    this.icon,
    this.imageUrl,
  });

  @override
  State<CuratedPlaylistScreen> createState() => _CuratedPlaylistScreenState();
}

class _CuratedPlaylistScreenState extends State<CuratedPlaylistScreen> {
  final MusicService _musicService = MusicService();
  final ScrollController _scrollController = ScrollController();

  List<Video> _tracks = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _musicService.addListener(_onServiceChanged);
    _loadTracks();
  }

  @override
  void dispose() {
    _musicService.removeListener(_onServiceChanged);
    _scrollController.dispose();
    super.dispose();
  }

  void _onServiceChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadTracks() async {
    if (widget.initialSongs != null && widget.initialSongs!.isNotEmpty) {
      if (mounted) {
        setState(() {
          _tracks = List<Video>.from(widget.initialSongs!);
          _isLoading = false;
        });
      }
      return;
    }

    final query = widget.query ?? widget.title;
    try {
      final results = await _musicService.searchSongs(query);
      if (mounted) {
        setState(() {
          _tracks = results;
          _isLoading = false;
          if (_tracks.isEmpty) {
            _errorMessage = 'No tracks found for this playlist.';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load tracks. Please check connection.';
        });
      }
    }
  }

  List<Color> get _effectiveColors {
    if (widget.gradientColors != null && widget.gradientColors!.isNotEmpty) {
      return widget.gradientColors!;
    }
    return [const Color(0xFF6366F1), const Color(0xFF8B5CF6)];
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final topGradientColor = _effectiveColors.first;

    return Scaffold(
      backgroundColor: const Color(0xFF09090C),
      body: Stack(
        children: [
          // Ambient Gradient Glow Header
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 340,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    topGradientColor.withValues(alpha: 0.35),
                    topGradientColor.withValues(alpha: 0.10),
                    const Color(0xFF09090C).withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),

          // Main Scrollable Content
          SafeArea(
            bottom: false,
            child: DilSeScrollbar(
              controller: _scrollController,
              child: CustomScrollView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // App Bar with Back Button
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                          Text(
                            widget.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 48), // Balance spacing
                        ],
                      ),
                    ),
                  ),

                  // Hero Artwork & Metadata
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      child: Column(
                        children: [
                          // Hero Album / Vinyl Card
                          Container(
                            width: 170,
                            height: 170,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(22),
                              gradient: LinearGradient(
                                colors: _effectiveColors,
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: topGradientColor.withValues(
                                    alpha: 0.35,
                                  ),
                                  blurRadius: 28,
                                  offset: const Offset(0, 12),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(22),
                              child:
                                  widget.imageUrl != null &&
                                      widget.imageUrl!.isNotEmpty
                                  ? Image.network(
                                      widget.imageUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) =>
                                          _buildFallbackHeroArt(),
                                    )
                                  : _buildFallbackHeroArt(),
                            ),
                          ),
                          const SizedBox(height: 18),

                          // Title
                          Text(
                            widget.title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 6),

                          // Subtitle & track count
                          Text(
                            _isLoading
                                ? widget.subtitle
                                : '${widget.subtitle} • ${_tracks.length} Tracks',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.65),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 18),

                          // Action Buttons: Play All & Shuffle
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Play All
                              ElevatedButton.icon(
                                onPressed: _tracks.isEmpty
                                    ? null
                                    : () {
                                        HapticFeedback.mediumImpact();
                                        _musicService.playPlaylist(_tracks, 0);
                                      },
                                icon: const Icon(
                                  Icons.play_arrow_rounded,
                                  color: Colors.black,
                                  size: 24,
                                ),
                                label: const Text(
                                  'Play',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryColor,
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 28,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  elevation: 4,
                                ),
                              ),
                              const SizedBox(width: 14),

                              // Shuffle Button
                              OutlinedButton.icon(
                                onPressed: _tracks.isEmpty
                                    ? null
                                    : () {
                                        HapticFeedback.lightImpact();
                                        final shuffled = List<Video>.from(
                                          _tracks,
                                        )..shuffle();
                                        _musicService.playPlaylist(shuffled, 0);
                                      },
                                icon: const Icon(
                                  Icons.shuffle_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                label: const Text(
                                  'Shuffle',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.20),
                                    width: 1.2,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 22,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 12)),

                  // Tracklist or Loading state
                  if (_isLoading)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF1DB954),
                        ),
                      ),
                    )
                  else if (_errorMessage != null)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.only(
                        left: 12,
                        right: 12,
                        bottom: 120,
                      ),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final video = _tracks[index];
                          final isCurrent =
                              _musicService.currentSong?.id.value ==
                              video.id.value;
                          final hdThumb = MusicService.getHdThumbnail(
                            video.id.value,
                          );

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 2,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            leading: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 22,
                                  child: Text(
                                    '${index + 1}',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: isCurrent
                                          ? primaryColor
                                          : Colors.white38,
                                      fontSize: 13,
                                      fontWeight: isCurrent
                                          ? FontWeight.w800
                                          : FontWeight.w500,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    hdThumb,
                                    width: 46,
                                    height: 46,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => Image.network(
                                      video.thumbnails.lowResUrl,
                                      width: 46,
                                      height: 46,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            title: Text(
                              video.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isCurrent ? primaryColor : Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              video.author,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isCurrent
                                    ? primaryColor.withValues(alpha: 0.8)
                                    : Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isCurrent)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: AnimatedEqualizer(
                                      isPlaying: _musicService.isPlaying,
                                      barCount: 3,
                                      color: primaryColor,
                                      size: 15,
                                    ),
                                  ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.more_vert_rounded,
                                    color: Colors.white38,
                                    size: 18,
                                  ),
                                  onPressed: () => showSongOptionsBottomSheet(
                                    context,
                                    video,
                                  ),
                                ),
                              ],
                            ),
                            onTap: () {
                              HapticFeedback.lightImpact();
                              _musicService.playPlaylist(_tracks, index);
                            },
                          );
                        }, childCount: _tracks.length),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Mini Player
          const Positioned(left: 0, right: 0, bottom: 0, child: MiniPlayer()),
        ],
      ),
    );
  }

  Widget _buildFallbackHeroArt() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            widget.icon ?? Icons.album_rounded,
            color: Colors.white,
            size: 52,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              widget.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

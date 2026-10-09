import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_theme_tokens.dart';
import '../services/music_service.dart';
import '../services/preferences_service.dart';
import '../widgets/animated_equalizer.dart';
import '../widgets/dilse_scrollbar.dart';

/// Full-screen Interactive Listening Statistics & Telemetry Screen.
/// Features rolling metrics, dynamic speedometer gauge, and top streamed tracks/artists.
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen>
    with SingleTickerProviderStateMixin {
  final MusicService _musicService = MusicService();
  final PreferencesService _prefs = PreferencesService();
  final ScrollController _scrollController = ScrollController();
  late AnimationController _animController;
  late Animation<double> _gaugeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _gaugeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_musicService, _prefs, _animController]),
      builder: (context, _) {
        final totalPlays = _prefs.totalPlays;
        final totalMinutes = (totalPlays * 3.4).round();
        final hours = totalMinutes ~/ 60;
        final mins = totalMinutes % 60;
        final likedCount = _musicService.likedSongs.length;
        final downloadedCount = _musicService.downloadedSongs.length;
        final topTracks = _prefs.mostPlayedSongs;

        // Compute top artists from top tracks and history
        final Map<String, int> artistCounts = {};
        for (final track in topTracks) {
          final artist = (track['author'] ?? track['artist'] ?? '') as String;
          final count = (track['playCount'] as num?)?.toInt() ?? 1;
          if (artist.isNotEmpty && artist != 'Unknown Artist') {
            artistCounts[artist] = (artistCounts[artist] ?? 0) + count;
          }
        }
        for (final track in _prefs.listeningHistory) {
          final artist = track['author'] ?? '';
          if (artist.isNotEmpty && artist != 'Unknown Artist') {
            artistCounts[artist] = (artistCounts[artist] ?? 0) + 1;
          }
        }
        final sortedArtists = artistCounts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final top5Artists = sortedArtists.take(5).toList();

        // Calculate listening variety / intensity score (0 to 100)
        final varietyScore = (totalPlays == 0)
            ? 0.0
            : math.min(
                100.0,
                (artistCounts.length * 4.5) +
                    (likedCount * 0.8) +
                    (totalPlays * 0.2),
              );

        return Scaffold(
          backgroundColor: AppThemeTokens.oledBackground,
          body: SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                Expanded(
                  child: DilSeScrollbar(
                    controller: _scrollController,
                    child: ListView(
                      controller: _scrollController,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                      children: [
                        _buildSpeedometerCard(varietyScore),
                        const SizedBox(height: 16),
                        _buildRollingMetricsGrid(
                          totalPlays: totalPlays,
                          hours: hours,
                          mins: mins,
                          likedCount: likedCount,
                          downloadedCount: downloadedCount,
                        ),
                        const SizedBox(height: 24),
                        if (top5Artists.isNotEmpty) ...[
                          _buildSectionTitle('Top Artists'),
                          const SizedBox(height: 12),
                          _buildTopArtistsList(top5Artists),
                          const SizedBox(height: 24),
                        ],
                        if (topTracks.isNotEmpty) ...[
                          _buildSectionTitle('Top Streamed Tracks'),
                          const SizedBox(height: 12),
                          _buildTopTracksList(topTracks.take(5).toList()),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: 20,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
            },
          ),
          const SizedBox(width: 14),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Listening Stats',
                style: TextStyle(
                  color: AppThemeTokens.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
              Text(
                'On-device personal audio telemetry',
                style: TextStyle(
                  color: AppThemeTokens.textSecondary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSpeedometerCard(double rawScore) {
    final animatedScore = rawScore * _gaugeAnimation.value;
    final ratingLabel = animatedScore > 75
        ? 'Sonic Connoisseur'
        : animatedScore > 45
        ? 'Eclectic Explorer'
        : animatedScore > 15
        ? 'Curious Listener'
        : 'Emerging Ear';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      decoration: BoxDecoration(
        color: AppThemeTokens.surfaceCard,
        borderRadius: BorderRadius.circular(AppThemeTokens.radiusCard),
        border: Border.all(color: AppThemeTokens.surfaceBorder, width: 0.75),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Music Exploration Gauge',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: AppThemeTokens.brandRuby.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppThemeTokens.brandRuby.withValues(alpha: 0.3),
                    width: 0.75,
                  ),
                ),
                child: Text(
                  ratingLabel,
                  style: const TextStyle(
                    color: AppThemeTokens.brandRuby,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 120,
            width: double.infinity,
            child: CustomPaint(
              painter: _SpeedometerGaugePainter(
                progress: (animatedScore / 100.0).clamp(0.0, 1.0),
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${animatedScore.round()}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1,
                        ),
                      ),
                      const Text(
                        'DIVERSITY INDEX',
                        style: TextStyle(
                          color: AppThemeTokens.textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRollingMetricsGrid({
    required int totalPlays,
    required int hours,
    required int mins,
    required int likedCount,
    required int downloadedCount,
  }) {
    final animatedPlays = (totalPlays * _gaugeAnimation.value).round();

    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.5,
      children: [
        _buildMetricCard(
          icon: Icons.play_arrow_rounded,
          iconColor: const Color(0xFF1DB954),
          title: 'Total Plays',
          value: '$animatedPlays',
        ),
        _buildMetricCard(
          icon: Icons.access_time_rounded,
          iconColor: const Color(0xFF00C6FF),
          title: 'Stream Time',
          value: hours > 0 ? '${hours}h ${mins}m' : '${mins}m',
        ),
        _buildMetricCard(
          icon: Icons.favorite_rounded,
          iconColor: AppThemeTokens.brandRuby,
          title: 'Liked Songs',
          value: '$likedCount',
        ),
        _buildMetricCard(
          icon: Icons.offline_pin_rounded,
          iconColor: const Color(0xFFFFA000),
          title: 'Downloaded',
          value: '$downloadedCount',
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppThemeTokens.surfaceCard,
        borderRadius: BorderRadius.circular(AppThemeTokens.radiusCard),
        border: Border.all(color: AppThemeTokens.surfaceBorder, width: 0.75),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 18),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  color: AppThemeTokens.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 17,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
      ),
    );
  }

  Widget _buildTopArtistsList(List<MapEntry<String, int>> artists) {
    return Column(
      children: List.generate(artists.length, (i) {
        final entry = artists[i];
        final rank = i + 1;
        final rankColor = rank == 1
            ? const Color(0xFFFFD700)
            : rank == 2
            ? const Color(0xFFC0C0C0)
            : rank == 3
            ? const Color(0xFFCD7F32)
            : Colors.white54;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppThemeTokens.surfaceCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppThemeTokens.surfaceBorder,
              width: 0.75,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: rankColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '#$rank',
                  style: TextStyle(
                    color: rankColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  entry.key,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              Text(
                '${entry.value} ${entry.value == 1 ? 'play' : 'plays'}',
                style: const TextStyle(
                  color: AppThemeTokens.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildTopTracksList(List<Map<String, dynamic>> tracks) {
    return Column(
      children: List.generate(tracks.length, (i) {
        final track = tracks[i];
        final rank = i + 1;
        final isCurrent = _musicService.currentSong?.id.value == track['id'];

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: isCurrent
                ? AppThemeTokens.brandRuby.withValues(alpha: 0.12)
                : AppThemeTokens.surfaceCard,
            borderRadius: BorderRadius.circular(AppThemeTokens.radiusCard),
            border: Border.all(
              color: isCurrent
                  ? AppThemeTokens.brandRuby.withValues(alpha: 0.4)
                  : AppThemeTokens.surfaceBorder,
              width: 0.75,
            ),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 2,
            ),
            onTap: () {
              HapticFeedback.lightImpact();
              _musicService.playMostPlayedSong(track);
            },
            leading: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 22,
                  child: Text(
                    '#$rank',
                    style: TextStyle(
                      color: rank <= 3
                          ? AppThemeTokens.brandRuby
                          : Colors.white38,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          track['thumbnail'] ?? '',
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            color: AppThemeTokens.surfaceElevated,
                            child: const Icon(
                              Icons.music_note_rounded,
                              color: Colors.white54,
                              size: 20,
                            ),
                          ),
                        ),
                        if (isCurrent)
                          Container(
                            color: Colors.black54,
                            child: Center(
                              child: AnimatedEqualizer(
                                isPlaying: _musicService.isPlaying,
                                size: 18,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            title: Text(
              track['title'] ?? 'Unknown Track',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isCurrent ? AppThemeTokens.brandRuby : Colors.white,
                fontSize: 13.5,
              ),
            ),
            subtitle: Text(
              track['author'] ?? track['artist'] ?? 'Unknown Artist',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppThemeTokens.textSecondary,
                fontSize: 12,
              ),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${track['playCount'] ?? 1}x',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _SpeedometerGaugePainter extends CustomPainter {
  final double progress;

  _SpeedometerGaugePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final radius = size.height * 0.95;

    final backgroundPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    // 180-degree semicircle arc (PI to 2*PI)
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi,
      math.pi,
      false,
      backgroundPaint,
    );

    if (progress > 0) {
      final activePaint = Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF00C6FF), Color(0xFF1DB954), Color(0xFFFA2D48)],
        ).createShader(Rect.fromCircle(center: center, radius: radius))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        math.pi,
        math.pi * progress,
        false,
        activePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SpeedometerGaugePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

import 'package:flutter/material.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../services/music_service.dart';
import '../services/preferences_service.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MusicService _musicService = MusicService();
  final PreferencesService _prefs = PreferencesService();
  List<Video> _topChartsIndia = [];
  List<Video> _trendingNow = [];
  List<Video> _newReleases = [];
  List<Video> _personalizedMixes = [];
  bool _isLoadingCharts = true;

  @override
  void initState() {
    super.initState();
    _loadHomeFeeds();
  }

  Future<void> _loadHomeFeeds() async {
    try {
      final charts = await _musicService.searchSongs('Top Charts India Music');
      final trending = await _musicService.searchSongs('Trending Songs 2026');
      final newReleases = await _musicService.searchSongs('Latest Music Hits');

      // Build a rich multi-artist/multi-search "Made For You" blend
      List<Video> blendedMix = [];
      List<String> seeds = [];

      if (_prefs.mostPlayedArtist.isNotEmpty) {
        seeds.add('${_prefs.mostPlayedArtist} songs');
      }
      for (var query in _prefs.searchHistory) {
        if (!seeds.contains('$query songs') && seeds.length < 3) {
          seeds.add('$query songs');
        }
      }

      if (seeds.isEmpty) {
        seeds.add('Top Hit Songs 2026');
      }

      // Fetch results for all seeds and interleave them
      List<List<Video>> seedResults = [];
      for (var seed in seeds) {
        final res = await _musicService.searchSongs(seed);
        if (res.isNotEmpty) seedResults.add(res);
      }

      int maxLen = 0;
      for (var list in seedResults) {
        if (list.length > maxLen) maxLen = list.length;
      }

      for (int i = 0; i < maxLen && blendedMix.length < 15; i++) {
        for (var list in seedResults) {
          if (i < list.length) {
            if (!blendedMix.any((v) => v.id == list[i].id)) {
              blendedMix.add(list[i]);
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _topChartsIndia = charts;
          _trendingNow = trending;
          _newReleases = newReleases;
          _personalizedMixes = blendedMix;
          _isLoadingCharts = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingCharts = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: CustomScrollView(
        slivers: [
          // Apple Music Header
          SliverAppBar(
            expandedHeight: 90.0,
            floating: false,
            pinned: true,
            backgroundColor: const Color(0xFF121212),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 16, bottom: 12),
              title: const Text(
                'Listen Now',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ProfileScreen()),
                    );
                  },
                  child: CircleAvatar(
                    backgroundColor: Colors.grey[800],
                    radius: 18,
                    child: const Icon(Icons.person, color: Colors.white, size: 20),
                  ),
                ),
              ),
            ],
          ),

          // Main Feed Body
          SliverToBoxAdapter(
            child: _isLoadingCharts
                ? SizedBox(
                    height: 300,
                    child: Center(
                      child: CircularProgressIndicator(color: Theme.of(context).primaryColor),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.only(bottom: 110),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader('TOP CHARTS: INDIA', 'Updated Daily'),
                        _buildHorizontalChartCards(_topChartsIndia),
                        const SizedBox(height: 24),

                        _buildSectionHeader('MADE FOR YOU', 'Curated Mix for your taste'),
                        _buildVerticalSongList(_personalizedMixes),
                        const SizedBox(height: 24),

                        _buildSectionHeader('NEW RELEASES', 'Fresh Music'),
                        _buildHorizontalChartCards(_newReleases),
                        const SizedBox(height: 24),

                        _buildSectionHeader('TRENDING NOW', 'Global Pick'),
                        _buildHorizontalChartCards(_trendingNow),
                        const SizedBox(height: 24),

                        if (_musicService.likedSongs.isNotEmpty) ...[
                          _buildSectionHeader('YOUR FAVORITES', 'Liked Tracks'),
                          _buildLikedSongsList(),
                        ],
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            subtitle.toUpperCase(),
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHorizontalChartCards(List<Video> videos) {
    if (videos.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 210,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: videos.length,
        itemBuilder: (context, index) {
          final song = videos[index];
          final hdThumbnail = MusicService.getHdThumbnail(song.id.value);

          return GestureDetector(
            onTap: () {
              _musicService.playPlaylist(videos, index);
            },
            child: Container(
              width: 150,
              margin: const EdgeInsets.all(6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 150,
                      height: 150,
                      child: Image.network(
                        hdThumbnail,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Image.network(song.thumbnails.highResUrl, fit: BoxFit.cover),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    song.author,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildVerticalSongList(List<Video> videos) {
    if (videos.isEmpty) return const SizedBox.shrink();

    final displayList = videos.length > 6 ? videos.sublist(0, 6) : videos;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: displayList.asMap().entries.map((entry) {
          final index = entry.key;
          final song = entry.value;
          final hdThumbnail = MusicService.getHdThumbnail(song.id.value);

          return ListTile(
            contentPadding: const EdgeInsets.symmetric(vertical: 4),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                hdThumbnail,
                width: 52,
                height: 52,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Image.network(
                  song.thumbnails.lowResUrl,
                  width: 52,
                  height: 52,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            title: Text(
              song.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
            ),
            subtitle: Text(
              song.author,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.grey[400], fontSize: 12),
            ),
            trailing: Icon(Icons.play_arrow_rounded, color: Theme.of(context).primaryColor, size: 28),
            onTap: () {
              _musicService.playPlaylist(displayList, index);
            },
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLikedSongsList() {
    final liked = _musicService.likedSongs;
    final displayList = liked.length > 5 ? liked.sublist(0, 5) : liked;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: displayList.map((song) {
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(vertical: 4),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                song['thumbnail']!,
                width: 52,
                height: 52,
                fit: BoxFit.cover,
              ),
            ),
            title: Text(
              song['title']!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
            ),
            subtitle: Text(
              song['author']!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.grey[400], fontSize: 12),
            ),
            trailing: const Icon(Icons.favorite, color: Color(0xFFFA2D48), size: 22),
            onTap: () {
              final video = Video(
                VideoId(song['id']!),
                song['title']!,
                song['author']!,
                ChannelId('UC0WP5P-fwGlLyO4yOE76T8g'),
                DateTime.now(),
                '',
                null,
                '',
                null,
                ThumbnailSet(song['id']!),
                null,
                Engagement(0, null, null),
                false,
              );
              _musicService.playSong(video);
            },
          );
        }).toList(),
      ),
    );
  }
}

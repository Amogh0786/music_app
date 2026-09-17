import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../services/music_service.dart';
import '../services/preferences_service.dart';
import '../widgets/shimmer_loading.dart';
import '../widgets/spotlight_billboard.dart';
import '../widgets/song_options_bottom_sheet.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with AutomaticKeepAliveClientMixin {
  final MusicService _musicService = MusicService();
  final PreferencesService _prefs = PreferencesService();

  @override
  bool get wantKeepAlive => true;

  List<Video> _topChartsIndia = [];
  List<Video> _trendingNow = [];
  List<Video> _newReleases = [];
  List<Video> _personalizedMixes = [];
  bool _isLoadingCharts = true;
  String? _loadingPlaylistId;

  int _selectedMoodIndex = 0;
  List<Video> _moodSongs = [];
  bool _isLoadingMood = false;
  final Map<int, List<Video>> _cachedMoodSongs = {};

  final List<Map<String, String>> _moods = const [
    {
      'label': '✨ All Hits',
      'query': 'Top Global Music Hits 2026',
      'desc': 'All trending and personalized hits curated for you',
    },
    {
      'label': '⚡ Energetic',
      'query': 'popular energetic songs audio',
      'desc': 'High-tempo power anthems to fuel your energy',
    },
    {
      'label': '☕ Chill & Relax',
      'query': 'relaxing acoustic indie chill songs audio',
      'desc': 'Mellow acoustic melodies to unwind and relax',
    },
    {
      'label': '🎧 Focus / Code',
      'query': 'lofi hip hop instrumental study coding track',
      'desc': 'Smooth non-distracting instrumental beats for flow state',
    },
    {
      'label': '💪 Workout',
      'query': 'gym workout motivation rap edm track',
      'desc': 'Adrenaline-pumping tracks to power your training session',
    },
    {
      'label': '🌙 Sleep',
      'query': 'calm ambient sleep night music track',
      'desc': 'Peaceful, dreamy soundscapes for deep and restful sleep',
    },
    {
      'label': '🎉 Party Hits',
      'query': 'party dance hits club songs audio',
      'desc': 'Dancefloor crowd-pleasers and club anthems',
    },
  ];

  @override
  void initState() {
    super.initState();
    _prefs.addListener(_onPrefsChanged);
    // Instant zero-wait display if background preload completed during splash
    if (_musicService.hasPreloadedHome && _musicService.preloadedTopChartsIndia.isNotEmpty) {
      _topChartsIndia = List.from(_musicService.preloadedTopChartsIndia);
      _trendingNow = List.from(_musicService.preloadedTrending);
      _isLoadingCharts = false;
    }
    _loadHomeFeeds();
  }

  @override
  void dispose() {
    _prefs.removeListener(_onPrefsChanged);
    super.dispose();
  }

  void _onPrefsChanged() {
    if (mounted) setState(() {});
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return 'Good morning';
    if (hour >= 12 && hour < 17) return 'Good afternoon';
    if (hour >= 17 && hour < 22) return 'Good evening';
    return 'Late night';
  }

  Future<void> _loadHomeFeeds() async {
    try {
      final List<String> seeds = [];
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

      final futureCharts = _musicService.searchSongs('Top Charts India Music');
      final futureTrending = _musicService.searchSongs('Trending Songs 2026');
      final futureNewReleases = _musicService.searchSongs('Latest Music Hits');
      final futureSeeds = seeds.map((s) => _musicService.searchSongs(s)).toList();

      final results = await Future.wait<dynamic>([
        futureCharts,
        futureTrending,
        futureNewReleases,
        ...futureSeeds,
      ]);

      final charts = results[0] as List<Video>;
      final trending = results[1] as List<Video>;
      final newReleases = results[2] as List<Video>;

      final List<List<Video>> seedResults = [];
      for (int i = 3; i < results.length; i++) {
        final seedList = results[i] as List<Video>;
        if (seedList.isNotEmpty) seedResults.add(seedList);
      }

      final List<Video> blendedMix = [];
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

  Future<void> _onMoodSelected(int index) async {
    if (_selectedMoodIndex == index) return;
    HapticFeedback.lightImpact();
    setState(() {
      _selectedMoodIndex = index;
    });

    if (index == 0) return;

    // Instant zero-wait cache response if previously loaded
    if (_cachedMoodSongs.containsKey(index) && _cachedMoodSongs[index]!.isNotEmpty) {
      setState(() {
        _moodSongs = _cachedMoodSongs[index]!;
        _isLoadingMood = false;
      });
      return;
    }

    setState(() {
      _isLoadingMood = true;
    });

    try {
      final rawSongs = await _musicService.searchSongs(_moods[index]['query']!);
      // Filter out long mixes (>10 min) and short clips (<45s) to guarantee real songs
      final songs = rawSongs.where((v) {
        if (v.duration == null) return true;
        return v.duration!.inSeconds >= 45 && v.duration!.inMinutes <= 10;
      }).toList();

      if (mounted && _selectedMoodIndex == index) {
        _cachedMoodSongs[index] = songs;
        setState(() {
          _moodSongs = songs;
          _isLoadingMood = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingMood = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final primaryColor = Theme.of(context).primaryColor;
    final billboardItems = _trendingNow.isNotEmpty
        ? _trendingNow
        : (_topChartsIndia.isNotEmpty ? _topChartsIndia : _newReleases);

    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0F),
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Personalized Top Greeting & Avatar
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(left: 20, right: 20, top: 18, bottom: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_getGreeting().toUpperCase()},',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _prefs.userName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.6,
                          ),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const ProfileScreen()),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(2.5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: primaryColor.withValues(alpha: 0.6),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withValues(alpha: 0.25),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: const CircleAvatar(
                          backgroundColor: Color(0xFF1E1E28),
                          radius: 20,
                          child: Icon(Icons.person_rounded, color: Colors.white, size: 22),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Horizontal Mood & Activity Filter Chips
            SliverToBoxAdapter(
              child: SizedBox(
                height: 46,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _moods.length,
                  itemBuilder: (context, index) {
                    final isSelected = _selectedMoodIndex == index;

                    return GestureDetector(
                      onTap: () => _onMoodSelected(index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 240),
                        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? primaryColor
                              : const Color(0xFF1A1A24),
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(
                            color: isSelected
                                ? primaryColor
                                : Colors.white.withValues(alpha: 0.08),
                            width: 1,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: primaryColor.withValues(alpha: 0.4),
                                    blurRadius: 12,
                                    offset: const Offset(0, 3),
                                  ),
                                ]
                              : null,
                        ),
                        child: Center(
                          child: Text(
                            _moods[index]['label']!,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.75),
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 12)),

            // Loading state with Shimmer Skeletons
            if (_isLoadingCharts)
              const SliverToBoxAdapter(
                child: Column(
                  children: [
                    ShimmerBillboard(),
                    SizedBox(height: 20),
                    ShimmerCardRow(),
                    SizedBox(height: 20),
                    ShimmerSongRow(),
                  ],
                ),
              )
            else
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 160),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Dedicated Vibe Radio Hub vs Default Full Home Feed
                      if (_selectedMoodIndex != 0)
                        _buildVibeRadioView(_selectedMoodIndex, primaryColor)
                      else ...[
                        // Top Spotlight Billboard Carousel
                        SpotlightBillboard(
                          items: billboardItems,
                          onPlay: (song, index) {
                            _musicService.playPlaylist(billboardItems, index);
                          },
                        ),
                        const SizedBox(height: 24),

                        // FEATURED PLAYLISTS & TRENDS (Spotify-Style Curated Mixes)
                        _buildSectionHeader('FEATURED PLAYLISTS', 'Trending & Curated Mixes'),
                        _buildCuratedPlaylistsSection(),
                        const SizedBox(height: 24),

                        // TOP CHARTS: INDIA
                        _buildSectionHeader('TOP CHARTS: INDIA', 'Updated Daily'),
                        _buildHorizontalChartCards(_topChartsIndia),
                        const SizedBox(height: 24),

                        // MADE FOR YOU
                        _buildSectionHeader('MADE FOR YOU', 'Curated Mix for your taste'),
                        _buildVerticalSongList(_personalizedMixes),
                        const SizedBox(height: 24),

                        // NEW RELEASES
                        _buildSectionHeader('NEW RELEASES', 'Fresh Music'),
                        _buildHorizontalChartCards(_newReleases),
                        const SizedBox(height: 24),

                        // TRENDING NOW
                        _buildSectionHeader('TRENDING NOW', 'Global Pick'),
                        _buildHorizontalChartCards(_trendingNow),
                        const SizedBox(height: 24),

                        // YOUR FAVORITES
                        if (_musicService.likedSongs.isNotEmpty) ...[
                          _buildSectionHeader('YOUR FAVORITES', 'Liked Tracks'),
                          _buildLikedSongsList(),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVibeRadioView(int moodIndex, Color primaryColor) {
    final mood = _moods[moodIndex];
    final label = mood['label'] ?? '';
    final desc = mood['desc'] ?? 'Curated for this vibe';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Vibe Hero Card
        Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                primaryColor.withValues(alpha: 0.35),
                const Color(0xFF181824),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: primaryColor.withValues(alpha: 0.35),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white12,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'VIBE RADIO',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (!_isLoadingMood && _moodSongs.isNotEmpty)
                    Text(
                      '${_moodSongs.length} Tracks',
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                desc,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 13.5,
                ),
              ),
              const SizedBox(height: 18),
              if (!_isLoadingMood && _moodSongs.isNotEmpty)
                Row(
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.play_arrow_rounded, size: 22),
                      label: const Text('Play Vibe Radio', style: TextStyle(fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        _musicService.playPlaylist(_moodSongs, 0);
                      },
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.shuffle_rounded, size: 18),
                      label: const Text('Shuffle', style: TextStyle(fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        final shuffled = List<Video>.from(_moodSongs)..shuffle();
                        _musicService.playPlaylist(shuffled, 0);
                      },
                    ),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        if (_isLoadingMood) ...[
          const ShimmerCardRow(),
          const SizedBox(height: 20),
          const ShimmerSongRow(),
        ] else if (_moodSongs.isEmpty) ...[
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  const Icon(Icons.music_off_rounded, size: 48, color: Colors.white38),
                  const SizedBox(height: 12),
                  Text(
                    'No tracks found for $label',
                    style: const TextStyle(color: Colors.white70, fontSize: 15),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => _onMoodSelected(0),
                    child: const Text('Return to All Hits'),
                  ),
                ],
              ),
            ),
          ),
        ] else ...[
          _buildSectionHeader('HIGHLIGHTS', 'Top Picks for $label'),
          _buildHorizontalChartCards(_moodSongs),
          const SizedBox(height: 22),
          _buildSectionHeader('VIBE TRACKLIST', '${_moodSongs.length} Songs'),
          _buildVerticalSongList(_moodSongs, isVibe: true),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 6.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            subtitle.toUpperCase(),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHorizontalChartCards(List<Video> videos) {
    if (videos.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 215,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: videos.length,
        itemBuilder: (context, index) {
          final song = videos[index];
          final hdThumbnail = MusicService.getHdThumbnail(song.id.value);

          return GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              _musicService.playPlaylist(videos, index);
            },
            child: Container(
              width: 152,
              margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 152,
                    height: 152,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.network(
                            hdThumbnail,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Image.network(
                              song.thumbnails.highResUrl,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            bottom: 8,
                            right: 8,
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  width: 1,
                                ),
                              ),
                              child: const Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
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
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    song.author,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
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

  Widget _buildVerticalSongList(List<Video> videos, {bool isVibe = false}) {
    if (videos.isEmpty) return const SizedBox.shrink();

    final displayList = (!isVibe && videos.length > 6) ? videos.sublist(0, 6) : videos;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: displayList.asMap().entries.map((entry) {
          final index = entry.key;
          final song = entry.value;
          final hdThumbnail = MusicService.getHdThumbnail(song.id.value);

          return Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF14141D),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.05),
                width: 1,
              ),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  hdThumbnail,
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Image.network(
                    song.thumbnails.lowResUrl,
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              title: Text(
                song.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  letterSpacing: -0.2,
                ),
              ),
              subtitle: Text(
                song.author,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 12,
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.more_vert_rounded, color: Colors.white38, size: 20),
                    onPressed: () {
                      showSongOptionsBottomSheet(context, song);
                    },
                  ),
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.play_arrow_rounded,
                      color: Theme.of(context).primaryColor,
                      size: 22,
                    ),
                  ),
                ],
              ),
              onTap: () {
                HapticFeedback.lightImpact();
                _musicService.playPlaylist(displayList, index);
              },
            ),
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
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF14141D),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.05),
                width: 1,
              ),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  song['thumbnail']!,
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                ),
              ),
              title: Text(
                song['title']!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  letterSpacing: -0.2,
                ),
              ),
              subtitle: Text(
                song['author']!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 12,
                ),
              ),
              trailing: const Icon(Icons.favorite_rounded, color: Color(0xFFFA2D48), size: 22),
              onTap: () {
                HapticFeedback.lightImpact();
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
            ),
          );
        }).toList(),
      ),
    );
  }

  List<CuratedPlaylist> _getCuratedPlaylists() {
    final artist = _prefs.mostPlayedArtist.isNotEmpty ? _prefs.mostPlayedArtist : 'Top Artists';
    return [
      const CuratedPlaylist(
        id: 'global_top_50',
        title: 'Top 50 - Global',
        subtitle: 'The hottest chartbusters worldwide',
        query: 'Top 50 Global Songs 2026',
        gradientColors: [Color(0xFF6B11FF), Color(0xFF2B0A80)],
        icon: Icons.public_rounded,
        tag: 'GLOBAL TRENDS',
      ),
      const CuratedPlaylist(
        id: 'trending_telugu',
        title: 'Trending Telugu',
        subtitle: 'Tollywood viral hits & chartbusters',
        query: 'Telugu Hit Songs 2026',
        gradientColors: [Color(0xFFFF3366), Color(0xFF990033)],
        icon: Icons.trending_up_rounded,
        tag: 'REGIONAL HITS',
      ),
      const CuratedPlaylist(
        id: 'bollywood_romance',
        title: 'Bollywood Romance',
        subtitle: 'Heartfelt melodies with Arijit & Pritam',
        query: 'Bollywood Romantic Songs Arijit Singh',
        gradientColors: [Color(0xFFFF5E3A), Color(0xFFFF2A68)],
        icon: Icons.favorite_rounded,
        tag: 'ROMANCE',
      ),
      const CuratedPlaylist(
        id: '90s_nostalgia',
        title: '90s Nostalgia Rewind',
        subtitle: 'Golden evergreen classics & melodies',
        query: '90s Evergreen Classic Hindi Telugu Songs',
        gradientColors: [Color(0xFF00B4DB), Color(0xFF0083B0)],
        icon: Icons.history_rounded,
        tag: 'RETRO CLASSICS',
      ),
      const CuratedPlaylist(
        id: 'telugu_2000s',
        title: 'Telugu 2000s Golden Era',
        subtitle: 'DSP, Harris Jayaraj & Mani Sharma hits',
        query: 'Telugu 2000s Super Hit Songs',
        gradientColors: [Color(0xFFF7971E), Color(0xFFFF7000)],
        icon: Icons.album_rounded,
        tag: 'GOLDEN ERA',
      ),
      const CuratedPlaylist(
        id: 'acoustic_chill',
        title: 'Acoustic & Coffee Chill',
        subtitle: 'Soothing acoustic indie melodies',
        query: 'Acoustic Pop Indie Chill Songs',
        gradientColors: [Color(0xFF11998E), Color(0xFF38EF7D)],
        icon: Icons.coffee_rounded,
        tag: 'CHILL MIX',
      ),
      CuratedPlaylist(
        id: 'daily_mix_1',
        title: 'Daily Mix 1',
        subtitle: 'Personalized mix featuring $artist',
        query: '$artist hit songs',
        gradientColors: const [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
        icon: Icons.auto_awesome_rounded,
        tag: 'MADE FOR YOU',
      ),
    ];
  }

  Widget _buildCuratedPlaylistsSection() {
    final playlists = _getCuratedPlaylists();
    return SizedBox(
      height: 195,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: playlists.length,
        itemBuilder: (context, index) {
          final p = playlists[index];
          final isLoading = _loadingPlaylistId == p.id;

          return GestureDetector(
            onTap: () => _playCuratedPlaylist(p),
            child: Container(
              width: 190,
              margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: p.gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: p.gradientColors.first.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          p.tag,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      Icon(p.icon, color: Colors.white.withValues(alpha: 0.85), size: 22),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        p.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black38,
                            blurRadius: 8,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Center(
                        child: isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                                ),
                              )
                            : const Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.black,
                                size: 24,
                              ),
                      ),
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

  Future<void> _playCuratedPlaylist(CuratedPlaylist playlist) async {
    if (_loadingPlaylistId != null) return;
    HapticFeedback.lightImpact();
    setState(() {
      _loadingPlaylistId = playlist.id;
    });

    try {
      final tracks = await _musicService.searchSongs(playlist.query);
      if (!mounted) return;
      if (tracks.isNotEmpty) {
        await _musicService.playPlaylist(tracks, 0);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Playing ${playlist.title} (${tracks.length} tracks)'),
            duration: const Duration(seconds: 2),
            backgroundColor: const Color(0xFF1E1E28),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error playing curated playlist: $e');
    } finally {
      if (mounted) {
        setState(() {
          _loadingPlaylistId = null;
        });
      }
    }
  }
}

class CuratedPlaylist {
  final String id;
  final String title;
  final String subtitle;
  final String query;
  final List<Color> gradientColors;
  final IconData icon;
  final String tag;

  const CuratedPlaylist({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.query,
    required this.gradientColors,
    required this.icon,
    required this.tag,
  });
}

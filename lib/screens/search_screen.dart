import 'dart:async';
import 'package:flutter/material.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../services/music_service.dart';
import '../services/preferences_service.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final MusicService _musicService = MusicService();
  final PreferencesService _prefs = PreferencesService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Video> _searchResults = [];
  List<String> _suggestions = [];
  Timer? _debounceTimer;
  bool _isSearching = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 1;
  String _currentQuery = '';

  final List<Map<String, dynamic>> _categories = [
    {
      'title': 'Bollywood Hits',
      'query': 'Bollywood Top Hits 2026',
      'colors': [const Color(0xFFFF416C), const Color(0xFFFF4B2B)],
    },
    {
      'title': 'Telugu Beats',
      'query': 'Telugu Top Songs',
      'colors': [const Color(0xFF8E2DE2), const Color(0xFF4A00E0)],
    },
    {
      'title': 'Pop & Global',
      'query': 'Global Pop Hits',
      'colors': [const Color(0xFF00c6ff), const Color(0xFF0072ff)],
    },
    {
      'title': 'Punjabi Hits',
      'query': 'Punjabi Top Hits',
      'colors': [const Color(0xFFf857a6), const Color(0xFFff5858)],
    },
    {
      'title': 'Lo-Fi & Chill',
      'query': 'Lofi Chill Beats',
      'colors': [const Color(0xFF11998e), const Color(0xFF38ef7d)],
    },
    {
      'title': 'Workout Energy',
      'query': 'Workout Music Beats',
      'colors': [const Color(0xFFFF8008), const Color(0xFFFFC837)],
    },
    {
      'title': 'Romance & Love',
      'query': 'Romantic Hindi Songs',
      'colors': [const Color(0xFFee9ca7), const Color(0xFFffdde1)],
    },
    {
      'title': 'Hip-Hop & Rap',
      'query': 'Hip Hop Hits',
      'colors': [const Color(0xFF3A1C71), const Color(0xFFD76D77)],
    },
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        _loadMoreResults();
      }
    });
  }

  void _onSearchChanged() {
    setState(() {});
    _debounceTimer?.cancel();
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _suggestions = [];
      });
      return;
    }

    if (query != _currentQuery) {
      _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
        if (!mounted) return;
        final results = await _musicService.fetchSuggestions(query, limit: 8);
        if (mounted && _searchController.text.trim() == query) {
          setState(() {
            _suggestions = results;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _performSearch(String query) async {
    if (query.trim().isEmpty) return;
    _debounceTimer?.cancel();

    await _prefs.addToSearchHistory(query);

    setState(() {
      _isSearching = true;
      _currentQuery = query;
      _currentPage = 1;
      _hasMore = true;
      _suggestions.clear();
      _searchResults.clear();
    });

    final results = await _musicService.searchSongs(query, page: 1);

    if (mounted) {
      setState(() {
        _searchResults = results;
        _isSearching = false;
        if (results.isEmpty || results.length < 20) {
          _hasMore = false;
        }
      });
    }
  }

  void _loadMoreResults() async {
    if (_isLoadingMore || !_hasMore || _isSearching || _currentQuery.isEmpty) return;

    setState(() {
      _isLoadingMore = true;
    });

    final nextPage = _currentPage + 1;
    final newResults = await _musicService.searchSongs(_currentQuery, page: nextPage);

    if (mounted) {
      setState(() {
        _currentPage = nextPage;
        _isLoadingMore = false;
        if (newResults.isEmpty) {
          _hasMore = false;
        } else {
          _searchResults.addAll(newResults);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final history = _prefs.searchHistory;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        title: const Text(
          'Search',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: -0.5),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Apple-style Search Field
            Container(
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFF282828),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _searchController,
                onSubmitted: _performSearch,
                textInputAction: TextInputAction.search,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Artists, Songs, Lyrics, and More',
                  hintStyle: TextStyle(color: Colors.grey[500], fontSize: 15),
                  prefixIcon: const Icon(Icons.search, color: Colors.white54, size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.white54, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchResults.clear();
                              _suggestions.clear();
                              _currentQuery = '';
                            });
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Content Area: Either Searching, Live Suggestions, Search Results, or Browse Categories
            Expanded(
              child: _isSearching
                  ? Center(child: CircularProgressIndicator(color: Theme.of(context).primaryColor))
                  : (_searchController.text.trim().isNotEmpty &&
                          _suggestions.isNotEmpty &&
                          _searchController.text.trim() != _currentQuery)
                      ? ListView.builder(
                          padding: const EdgeInsets.only(bottom: 110),
                          itemCount: _suggestions.length,
                          itemBuilder: (context, index) {
                            final suggestion = _suggestions[index];
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              leading: const Icon(Icons.search, color: Colors.white54, size: 20),
                              title: Text(
                                suggestion,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              trailing: const Icon(Icons.north_west, color: Colors.white38, size: 18),
                              onTap: () {
                                _searchController.text = suggestion;
                                _performSearch(suggestion);
                              },
                            );
                          },
                        )
                      : _searchResults.isNotEmpty
                          ? ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.only(bottom: 110),
                          itemCount: _searchResults.length + (_isLoadingMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _searchResults.length) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                child: Center(
                                  child: CircularProgressIndicator(color: Theme.of(context).primaryColor, strokeWidth: 2.5),
                                ),
                              );
                            }

                            final video = _searchResults[index];
                            final hdThumbnail = MusicService.getHdThumbnail(video.id.value);

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
                                    video.thumbnails.lowResUrl,
                                    width: 52,
                                    height: 52,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              title: Text(
                                video.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                              ),
                              subtitle: Text(
                                video.author,
                                maxLines: 1,
                                style: TextStyle(color: Colors.grey[400], fontSize: 12),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.more_horiz, color: Colors.white54),
                                onPressed: () {},
                              ),
                              onTap: () {
                                _musicService.playPlaylist(_searchResults, index);
                              },
                            );
                          },
                        )

                      : ListView(
                          padding: const EdgeInsets.only(bottom: 110),
                          children: [
                            if (history.isNotEmpty) ...[
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Recent Searches',
                                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      _prefs.clearSearchHistory();
                                      setState(() {});
                                    },
                                    child: Text('Clear', style: TextStyle(color: Theme.of(context).primaryColor)),
                                  )
                                ],
                              ),
                              ...history.take(4).map(
                                    (item) => ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: const Icon(Icons.history, color: Colors.grey, size: 20),
                                      title: Text(item, style: const TextStyle(color: Colors.white, fontSize: 14)),
                                      onTap: () {
                                        _searchController.text = item;
                                        _performSearch(item);
                                      },
                                    ),
                                  ),
                              const SizedBox(height: 16),
                            ],
                            const Text(
                              'Browse Categories',
                              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.3),
                            ),
                            const SizedBox(height: 12),
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 1.7,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                              ),
                              itemCount: _categories.length,
                              itemBuilder: (context, index) {
                                final cat = _categories[index];
                                final List<Color> colors = cat['colors'];

                                return GestureDetector(
                                  onTap: () {
                                    _searchController.text = cat['title'];
                                    _performSearch(cat['query']);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: colors,
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: [
                                        BoxShadow(
                                          color: colors.first.withOpacity(0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Align(
                                      alignment: Alignment.bottomLeft,
                                      child: Text(
                                        cat['title'],
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

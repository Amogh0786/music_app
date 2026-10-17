import 'package:flutter/material.dart';
import '../../layouts/desktop_layout_state.dart';
import '../../services/music_service.dart';
import '../../services/preferences_service.dart';
import '../../services/dynamic_artist_service.dart';
import '../playlist_action_menu.dart';
import '../dilse_tooltip.dart';
import 'desktop_context_menu.dart';

/// Spotify-grade dual-mode Left Sidebar (#Desktop_LeftSidebar_Id).
///
/// Features:
/// - Compact Mode (Width <= 96px): Tooltip-backed icon navigation & 48x48 squircle tiles.
/// - Expanded Mode (Width > 96px): Primary Navigation Card + "Your Library" deck with
///   filter chips (`Playlists`, `Albums`, `Imported from Spotify`, `History`),
///   in-library instant search, sort indicator, and virtualized list rows.
class DesktopLeftSidebar extends StatefulWidget {
  final double width;

  const DesktopLeftSidebar({super.key, required this.width});

  @override
  State<DesktopLeftSidebar> createState() => _DesktopLeftSidebarState();
}

class _DesktopLeftSidebarState extends State<DesktopLeftSidebar> {
  final MusicService _musicService = MusicService();
  final PreferencesService _prefs = PreferencesService();
  final ValueNotifier<Set<String>> _selectedFilters =
      ValueNotifier<Set<String>>({});
  final ValueNotifier<bool> _isSearchActive = ValueNotifier<bool>(false);
  final TextEditingController _searchController = TextEditingController();
  String? _hoveredRowId;

  @override
  void dispose() {
    _selectedFilters.dispose();
    _isSearchActive.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _showCreatePlaylistDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E28),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Create New Playlist',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Playlist name',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.2),
              ),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white70),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                final newId = _musicService.createPlaylist(name);
                Navigator.pop(ctx);
                if (newId.isNotEmpty && mounted) {
                  DesktopLayoutState.openPlaylist(newId);
                }
              }
            },
            child: const Text(
              'Create',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = widget.width <= 96.0;

    if (isCompact) {
      return _buildCompactSidebar(context);
    }

    return _buildExpandedSidebar(context);
  }

  // ===========================================================================
  // 1. COMPACT MODE (Width <= 96px)
  // ===========================================================================
  Widget _buildCompactSidebar(BuildContext context) {
    final prefs = PreferencesService();

    return AnimatedBuilder(
      animation: Listenable.merge([
        _musicService,
        prefs,
        DesktopLayoutState.activeNavTab,
        DesktopLayoutState.activePlaylistId,
      ]),
      builder: (context, _) {
        final accentColor = prefs.legibleThemeColor;
        final activeTab = DesktopLayoutState.activeNavTab.value;
        final activePlaylistId = DesktopLayoutState.activePlaylistId.value;

        return Container(
          margin: const EdgeInsets.fromLTRB(8.0, 8.0, 0.0, 8.0),
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 12.0),
          decoration: BoxDecoration(
            color: const Color(0xFF16161E),
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
              width: 1.0,
            ),
          ),
          child: Column(
            children: [
              // 1. Top Persistent Expand / Toggle Control (Spotify-parity Reference 1)
              _buildCompactNavIcon(
                icon: Icons.menu_open_rounded,
                isFlipped: true,
                label: 'Expand sidebar',
                color: Colors.white70,
                onTap: () => DesktopLayoutState.toggleLeftSidebar(),
              ),

              const SizedBox(height: 6.0),

              // 2. Primary Navigation Icons
              _buildCompactNavIcon(
                icon: Icons.home_filled,
                label: 'Home',
                isActive: activeTab == DesktopNavTab.home,
                onTap: () => DesktopLayoutState.setNavTab(DesktopNavTab.home),
              ),
              _buildCompactNavIcon(
                icon: Icons.search_rounded,
                label: 'Search',
                isActive: activeTab == DesktopNavTab.search,
                onTap: () => DesktopLayoutState.setNavTab(DesktopNavTab.search),
              ),

              const SizedBox(height: 6.0),
              Divider(color: Colors.white.withValues(alpha: 0.08), height: 1.0),
              const SizedBox(height: 6.0),

              // 3. Create Playlist Action
              _buildCompactNavIcon(
                icon: Icons.add_rounded,
                label: 'Create Playlist',
                color: Colors.white70,
                onTap: _showCreatePlaylistDialog,
              ),

              // 4. Liked Songs Squircle Icon
              GestureDetector(
                onSecondaryTapDown: (details) {
                  DesktopContextMenu.showPlaylistMenu(
                    context: context,
                    globalPosition: details.globalPosition,
                    playlistId: 'liked_songs',
                    playlistName: 'Liked Songs',
                  );
                },
                child: _buildCompactNavIcon(
                  icon: Icons.favorite_rounded,
                  label: 'Liked Songs (${_musicService.likedSongs.length})',
                  color: accentColor,
                  isActive:
                      activeTab == DesktopNavTab.customPlaylist &&
                      activePlaylistId == 'liked_songs',
                  onTap: () {
                    DesktopLayoutState.openPlaylist('liked_songs');
                  },
                ),
              ),

              const SizedBox(height: 8.0),

              // 5. Custom Playlists Squircles List (pinned playlists sorted first)
              Expanded(
                child: AnimatedBuilder(
                  animation: Listenable.merge([_musicService, prefs]),
                  builder: (context, _) {
                    final allPlaylists = _musicService.customPlaylists;
                    final sorted = List<Map<String, dynamic>>.from(
                      allPlaylists,
                    );
                    final pinnedIds = prefs.pinnedPlaylistIds.toSet();
                    sorted.sort((a, b) {
                      final aId = a['id']?.toString() ?? '';
                      final bId = b['id']?.toString() ?? '';
                      final aPinned = pinnedIds.contains(aId);
                      final bPinned = pinnedIds.contains(bId);
                      if (aPinned && !bPinned) return -1;
                      if (!aPinned && bPinned) return 1;
                      return 0;
                    });

                    return ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: sorted.length > 8 ? 8 : sorted.length,
                      itemBuilder: (context, index) {
                        final pl = sorted[index];
                        final name = pl['name']?.toString() ?? 'Playlist';
                        final id = pl['id']?.toString() ?? '';
                        final isPinned = pinnedIds.contains(id);
                        final isSelected =
                            activeTab == DesktopNavTab.customPlaylist &&
                            activePlaylistId == id;

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: DilSeTooltip(
                            message: isPinned ? '$name 📌' : name,
                            child: GestureDetector(
                              onTap: () {
                                if (id.isNotEmpty) {
                                  DesktopLayoutState.openPlaylist(id);
                                }
                              },
                              onSecondaryTapDown: (details) {
                                if (id.isNotEmpty) {
                                  DesktopContextMenu.showPlaylistMenu(
                                    context: context,
                                    globalPosition: details.globalPosition,
                                    playlistId: id,
                                    playlistName: name,
                                    onCreatePlaylist: _showCreatePlaylistDialog,
                                  );
                                }
                              },
                              child: Container(
                                width: 44.0,
                                height: 44.0,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? accentColor.withValues(alpha: 0.22)
                                      : const Color(0xFF282836),
                                  borderRadius: BorderRadius.circular(8.0),
                                  border: Border.all(
                                    color: isSelected
                                        ? accentColor
                                        : (isPinned
                                              ? const Color(
                                                  0xFF1DB954,
                                                ).withValues(alpha: 0.45)
                                              : Colors.white.withValues(
                                                  alpha: 0.06,
                                                )),
                                    width: isSelected ? 1.5 : 1.0,
                                  ),
                                ),
                                child: Stack(
                                  children: [
                                    Center(
                                      child: Text(
                                        name.isNotEmpty
                                            ? name[0].toUpperCase()
                                            : 'P',
                                        style: TextStyle(
                                          color: isSelected
                                              ? accentColor
                                              : Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16.0,
                                        ),
                                      ),
                                    ),
                                    if (isPinned)
                                      const Positioned(
                                        top: 3,
                                        right: 3,
                                        child: Icon(
                                          Icons.push_pin_rounded,
                                          size: 10,
                                          color: Color(0xFF1DB954),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
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
        );
      },
    );
  }

  Widget _buildCompactNavIcon({
    required IconData icon,
    required String label,
    Color? color,
    bool isActive = false,
    bool isFlipped = false,
    required VoidCallback onTap,
  }) {
    final prefs = PreferencesService();
    final accentColor = prefs.legibleThemeColor;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: DilSeTooltip(
        message: label,
        child: InkWell(
          borderRadius: BorderRadius.circular(10.0),
          onTap: onTap,
          child: Container(
            width: 44.0,
            height: 44.0,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isActive
                  ? accentColor.withValues(alpha: 0.18)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10.0),
              border: isActive
                  ? Border.all(
                      color: accentColor.withValues(alpha: 0.4),
                      width: 1.0,
                    )
                  : null,
            ),
            child: isFlipped
                ? Transform.flip(
                    flipX: true,
                    child: Icon(
                      icon,
                      color: isActive
                          ? accentColor
                          : (color ?? Colors.white.withValues(alpha: 0.8)),
                      size: 22.0,
                    ),
                  )
                : Icon(
                    icon,
                    color: isActive
                        ? accentColor
                        : (color ?? Colors.white.withValues(alpha: 0.8)),
                    size: 22.0,
                  ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // 2. EXPANDED MODE (Width > 96px, 280px–398px)
  // ===========================================================================
  Widget _buildExpandedSidebar(BuildContext context) {
    return Column(
      children: [
        // CARD 1: PRIMARY NAVIGATION (Home / Search)
        Container(
          margin: const EdgeInsets.fromLTRB(8.0, 8.0, 0.0, 0.0),
          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
          decoration: BoxDecoration(
            color: const Color(0xFF16161E),
            borderRadius: BorderRadius.circular(10.0),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
              width: 1.0,
            ),
          ),
          child: ValueListenableBuilder<DesktopNavTab>(
            valueListenable: DesktopLayoutState.activeNavTab,
            builder: (context, activeTab, _) {
              return Column(
                children: [
                  _buildNavRow(
                    icon: Icons.home_filled,
                    title: 'Home',
                    isActive: activeTab == DesktopNavTab.home,
                    onTap: () =>
                        DesktopLayoutState.setNavTab(DesktopNavTab.home),
                  ),
                  const SizedBox(height: 6.0),
                  _buildNavRow(
                    icon: Icons.search_rounded,
                    title: 'Search',
                    isActive: activeTab == DesktopNavTab.search,
                    onTap: () =>
                        DesktopLayoutState.setNavTab(DesktopNavTab.search),
                  ),
                ],
              );
            },
          ),
        ),

        const SizedBox(height: 8.0),

        // CARD 2: YOUR LIBRARY DECK (Expanded)
        Expanded(
          child: Container(
            margin: const EdgeInsets.fromLTRB(8.0, 0.0, 0.0, 8.0),
            decoration: BoxDecoration(
              color: const Color(0xFF16161E),
              borderRadius: BorderRadius.circular(10.0),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
                width: 1.0,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Library Header: Title, Collapse button, and Add action
                Padding(
                  padding: const EdgeInsets.fromLTRB(10.0, 10.0, 8.0, 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Collapse sidebar',
                            visualDensity: VisualDensity.compact,
                            constraints: const BoxConstraints(
                              minWidth: 28,
                              minHeight: 28,
                            ),
                            padding: EdgeInsets.zero,
                            icon: const Icon(
                              Icons.menu_open_rounded,
                              color: Colors.white70,
                              size: 20.0,
                            ),
                            onPressed: () =>
                                DesktopLayoutState.toggleLeftSidebar(),
                          ),
                          const SizedBox(width: 6.0),
                          const Text(
                            'Your Library',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14.0,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        tooltip: 'Create playlist',
                        visualDensity: VisualDensity.compact,
                        constraints: const BoxConstraints(
                          minWidth: 28,
                          minHeight: 28,
                        ),
                        padding: EdgeInsets.zero,
                        icon: const Icon(
                          Icons.add_rounded,
                          color: Colors.white70,
                          size: 22.0,
                        ),
                        onPressed: _showCreatePlaylistDialog,
                      ),
                    ],
                  ),
                ),

                // Horizontal Filter Chips Strip with Multi-Select and (X) Reset Button
                SizedBox(
                  height: 34.0,
                  child: ValueListenableBuilder<Set<String>>(
                    valueListenable: _selectedFilters,
                    builder: (context, activeFilters, _) {
                      return ListView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 14.0),
                        children: [
                          if (activeFilters.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(right: 6.0),
                              child: DilSeTooltip(
                                message: 'Clear filters',
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16.0),
                                  onTap: () {
                                    _selectedFilters.value = {};
                                  },
                                  child: Container(
                                    width: 32.0,
                                    height: 32.0,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.12,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close_rounded,
                                      color: Colors.white,
                                      size: 16.0,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          _buildFilterChip('Playlists', activeFilters),
                          _buildFilterChip('Artists', activeFilters),
                          _buildFilterChip('Albums', activeFilters),
                          _buildFilterChip(
                            'Imported from Spotify',
                            activeFilters,
                          ),
                          _buildFilterChip('History', activeFilters),
                        ],
                      );
                    },
                  ),
                ),

                const SizedBox(height: 8.0),

                // In-Library Search & Sort Toolbar
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14.0,
                    vertical: 4.0,
                  ),
                  child: Row(
                    children: [
                      // Expandable search field
                      Expanded(
                        child: ValueListenableBuilder<bool>(
                          valueListenable: _isSearchActive,
                          builder: (context, isSearchActive, _) {
                            if (!isSearchActive) {
                              return Row(
                                children: [
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero,
                                    tooltip: 'Search in Your Library',
                                    icon: const Icon(
                                      Icons.search_rounded,
                                      color: Colors.white60,
                                      size: 18.0,
                                    ),
                                    onPressed: () {
                                      _isSearchActive.value = true;
                                    },
                                  ),
                                ],
                              );
                            }

                            return Container(
                              height: 32.0,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8.0,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF282836),
                                borderRadius: BorderRadius.circular(6.0),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.search_rounded,
                                    color: Colors.white54,
                                    size: 16.0,
                                  ),
                                  const SizedBox(width: 6.0),
                                  Expanded(
                                    child: TextField(
                                      controller: _searchController,
                                      autofocus: true,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12.0,
                                      ),
                                      decoration: const InputDecoration(
                                        isDense: true,
                                        border: InputBorder.none,
                                        hintText: 'Search Library...',
                                        hintStyle: TextStyle(
                                          color: Colors.white38,
                                          fontSize: 12.0,
                                        ),
                                      ),
                                      onChanged: (_) => setState(() {}),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      _searchController.clear();
                                      _isSearchActive.value = false;
                                      setState(() {});
                                    },
                                    child: const Icon(
                                      Icons.close_rounded,
                                      color: Colors.white54,
                                      size: 16.0,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),

                      // Trailing Sort Indicator ("Recents")
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Recents',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 12.0,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 4.0),
                          Icon(
                            Icons.sort_rounded,
                            color: Colors.white.withValues(alpha: 0.6),
                            size: 16.0,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 6.0),

                // Virtualized Entity List (Liked Songs, Custom Playlists, Spotify Imports, History)
                Expanded(
                  child: AnimatedBuilder(
                    animation: Listenable.merge([
                      _musicService,
                      _prefs,
                      _selectedFilters,
                      DesktopLayoutState.activeNavTab,
                      DesktopLayoutState.activePlaylistId,
                      DesktopLayoutState.activeArtistName,
                    ]),
                    builder: (context, _) {
                      final filters = _selectedFilters.value;
                      final query = _searchController.text.trim().toLowerCase();

                      if (filters.contains('Artists')) {
                        final followed = _prefs.followedArtists.where((name) {
                          if (query.isEmpty) return true;
                          return name.toLowerCase().contains(query);
                        }).toList();

                        if (followed.isEmpty) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                                vertical: 24.0,
                              ),
                              child: Text(
                                query.isEmpty
                                    ? 'No followed artists yet'
                                    : 'No artists match "$query"',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.4),
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                          );
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 6.0),
                          itemCount: followed.length,
                          itemBuilder: (context, index) {
                            final artistName = followed[index];
                            return _buildArtistRow(context, artistName);
                          },
                        );
                      }

                      final playlists = _getFilteredPlaylists();
                      final showLiked = _shouldShowLikedSongs();

                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 6.0),
                        itemCount: (showLiked ? 1 : 0) + playlists.length,
                        itemBuilder: (context, index) {
                          // Row 0: Liked Songs Row
                          if (showLiked && index == 0) {
                            return _buildLikedSongsRow(context);
                          }

                          final plIndex = showLiked ? index - 1 : index;
                          final pl = playlists[plIndex];
                          return _buildPlaylistRow(context, pl);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNavRow({
    required IconData icon,
    required String title,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(8.0),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: isActive
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isActive
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.7),
              size: 22.0,
            ),
            const SizedBox(width: 14.0),
            Text(
              title,
              style: TextStyle(
                color: isActive
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.7),
                fontSize: 14.0,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, Set<String> activeFilters) {
    final isSelected = activeFilters.contains(label);

    return Padding(
      padding: const EdgeInsets.only(right: 6.0),
      child: GestureDetector(
        onTap: () {
          final next = Set<String>.from(_selectedFilters.value);
          if (isSelected) {
            next.remove(label);
          } else {
            next.add(label);
          }
          _selectedFilters.value = next;
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF282836)
                : Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(16.0),
            border: Border.all(
              color: isSelected
                  ? Colors.white.withValues(alpha: 0.3)
                  : Colors.transparent,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.75),
              fontSize: 12.0,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  bool _shouldShowLikedSongs() {
    final filters = _selectedFilters.value;
    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty && !'liked songs'.contains(query)) {
      return false;
    }
    if (filters.isEmpty) return true;
    if (filters.contains('Playlists')) return true;
    if (filters.contains('Albums') ||
        filters.contains('History') ||
        filters.contains('Artists')) {
      return false;
    }
    return true;
  }

  List<Map<String, dynamic>> _getFilteredPlaylists() {
    final allPlaylists = _musicService.customPlaylists;
    final filters = _selectedFilters.value;
    final query = _searchController.text.trim().toLowerCase();

    final filtered = allPlaylists.where((pl) {
      final name = pl['name']?.toString().toLowerCase() ?? '';
      final isSpotify =
          pl['isSpotify'] == true ||
          (pl['source']?.toString().contains('spotify') ?? false);
      final isAlbum = pl['type'] == 'album';

      if (query.isNotEmpty && !name.contains(query)) {
        return false;
      }

      if (filters.isEmpty) return true;

      bool matches = false;
      if (filters.contains('Playlists') && !isAlbum) {
        matches = true;
      }
      if (filters.contains('Imported from Spotify') && isSpotify) {
        matches = true;
      }
      if (filters.contains('Albums') && isAlbum) {
        matches = true;
      }
      if (filters.contains('History')) {
        if (pl['type'] == 'history') matches = true;
      }
      return matches;
    }).toList();

    // Sort: pinned playlists first immediately following Liked Songs
    final pinnedIds = _prefs.pinnedPlaylistIds.toSet();
    filtered.sort((a, b) {
      final aId = a['id']?.toString() ?? '';
      final bId = b['id']?.toString() ?? '';
      final aPinned = pinnedIds.contains(aId);
      final bPinned = pinnedIds.contains(bId);
      if (aPinned && !bPinned) return -1;
      if (!aPinned && bPinned) return 1;
      return 0;
    });

    return filtered;
  }

  Widget _buildLikedSongsRow(BuildContext context) {
    final count = _musicService.likedSongs.length;
    final isHovered = _hoveredRowId == 'liked_songs';
    final isSelected =
        DesktopLayoutState.activeNavTab.value == DesktopNavTab.customPlaylist &&
        DesktopLayoutState.activePlaylistId.value == 'liked_songs';

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredRowId = 'liked_songs'),
      onExit: (_) => setState(() => _hoveredRowId = null),
      child: GestureDetector(
        onSecondaryTapDown: (details) {
          DesktopContextMenu.showPlaylistMenu(
            context: context,
            globalPosition: details.globalPosition,
            playlistId: 'liked_songs',
            playlistName: 'Liked Songs',
          );
        },
        child: InkWell(
          borderRadius: BorderRadius.circular(8.0),
          onTap: () {
            DesktopLayoutState.openPlaylist('liked_songs');
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.white.withValues(alpha: 0.10)
                  : isHovered
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: Row(
              children: [
                // 48x48 Gradient Liked Songs Squircle
                Container(
                  width: 48.0,
                  height: 48.0,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF450AF5), Color(0xFFC4EFD9)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(6.0),
                  ),
                  child: const Icon(
                    Icons.favorite_rounded,
                    color: Colors.white,
                    size: 24.0,
                  ),
                ),
                const SizedBox(width: 12.0),

                // Title and Subtitle with Pin
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Liked Songs',
                        style: TextStyle(
                          color: isSelected
                              ? const Color(0xFF1DB954)
                              : Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2.0),
                      Row(
                        children: [
                          const Icon(
                            Icons.push_pin_rounded,
                            color: Color(0xFF1DB954),
                            size: 13.0,
                          ),
                          const SizedBox(width: 4.0),
                          Expanded(
                            child: Text(
                              'Playlist • $count ${count == 1 ? "song" : "songs"}',
                              style: TextStyle(
                                color: isSelected
                                    ? const Color(
                                        0xFF1DB954,
                                      ).withValues(alpha: 0.8)
                                    : Colors.white.withValues(alpha: 0.6),
                                fontSize: 12.0,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaylistRow(BuildContext context, Map<String, dynamic> pl) {
    final id = pl['id']?.toString() ?? '';
    final name = pl['name']?.toString() ?? 'Untitled Playlist';
    final isSpotify = pl['isSpotify'] == true;
    final trackCount =
        (pl['tracks'] as List?)?.length ?? (pl['songs'] as List?)?.length ?? 0;
    final isHovered = _hoveredRowId == id;
    final isSelected =
        DesktopLayoutState.activeNavTab.value == DesktopNavTab.customPlaylist &&
        DesktopLayoutState.activePlaylistId.value == id;
    final isPinned = _prefs.isPlaylistPinned(id);

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredRowId = id),
      onExit: (_) => setState(() => _hoveredRowId = null),
      child: GestureDetector(
        onSecondaryTapDown: (details) {
          if (id.isNotEmpty) {
            DesktopContextMenu.showPlaylistMenu(
              context: context,
              globalPosition: details.globalPosition,
              playlistId: id,
              playlistName: name,
              isSpotifyImport: isSpotify,
              onCreatePlaylist: _showCreatePlaylistDialog,
            );
          }
        },
        child: InkWell(
          borderRadius: BorderRadius.circular(8.0),
          onTap: () {
            if (id.isNotEmpty) {
              DesktopLayoutState.openPlaylist(id);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.white.withValues(alpha: 0.10)
                  : isHovered
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: Row(
              children: [
                // 48x48 Squircle Album / Playlist Tile
                Container(
                  width: 48.0,
                  height: 48.0,
                  decoration: BoxDecoration(
                    color: const Color(0xFF282836),
                    borderRadius: BorderRadius.circular(6.0),
                  ),
                  child: Center(
                    child: isSpotify
                        ? const Icon(
                            Icons.stream_rounded,
                            color: Color(0xFF1DB954),
                            size: 22.0,
                          )
                        : Text(
                            name.isNotEmpty ? name[0].toUpperCase() : 'P',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.bold,
                              fontSize: 17.0,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12.0),

                // Title and Details Subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          color: isSelected
                              ? const Color(0xFF1DB954)
                              : Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2.0),
                      Row(
                        children: [
                          if (isPinned) ...[
                            const Icon(
                              Icons.push_pin_rounded,
                              color: Color(0xFF1DB954),
                              size: 13.0,
                            ),
                            const SizedBox(width: 4.0),
                          ],
                          Expanded(
                            child: Text(
                              isSpotify
                                  ? 'Playlist • Spotify Import'
                                  : 'Playlist • $trackCount ${trackCount == 1 ? "song" : "songs"}',
                              style: TextStyle(
                                color: isSelected
                                    ? const Color(
                                        0xFF1DB954,
                                      ).withValues(alpha: 0.8)
                                    : Colors.white.withValues(alpha: 0.6),
                                fontSize: 12.0,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Hover Actions: 3-Dot More Menu
                if (isHovered && id.isNotEmpty)
                  PlaylistActionMenu(
                    playlistId: id,
                    playlistName: name,
                    isSpotifyImport: isSpotify,
                    iconSize: 18.0,
                    iconColor: Colors.white70,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildArtistRow(BuildContext context, String artistName) {
    final artistItem = DynamicArtistService().findArtist(artistName);
    final displayName = artistItem?.name ?? artistName;
    final isHovered = _hoveredRowId == 'artist_$artistName';
    final isSelected =
        DesktopLayoutState.activeNavTab.value == DesktopNavTab.artistProfile &&
        DesktopLayoutState.activeArtistName.value == displayName;

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredRowId = 'artist_$artistName'),
      onExit: (_) => setState(() => _hoveredRowId = null),
      child: InkWell(
        borderRadius: BorderRadius.circular(8.0),
        onTap: () {
          DesktopLayoutState.openArtist(displayName);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.white.withValues(alpha: 0.10)
                : isHovered
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: Row(
            children: [
              // 48x48 Circular Artist Avatar
              Container(
                width: 48.0,
                height: 48.0,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF282836),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                    width: 1.0,
                  ),
                ),
                child: ClipOval(
                  child: artistItem != null && artistItem.imageUrl.isNotEmpty
                      ? Image.network(
                          artistItem.imageUrl,
                          fit: BoxFit.cover,
                          cacheWidth: 120,
                          cacheHeight: 120,
                          errorBuilder: (_, _, _) => Center(
                            child: Text(
                              displayName.isNotEmpty
                                  ? displayName[0].toUpperCase()
                                  : 'A',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.bold,
                                fontSize: 17.0,
                              ),
                            ),
                          ),
                        )
                      : Center(
                          child: Text(
                            displayName.isNotEmpty
                                ? displayName[0].toUpperCase()
                                : 'A',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.bold,
                              fontSize: 17.0,
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12.0),

              // Title and Subtitle with Verified Badge
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            displayName,
                            style: TextStyle(
                              color: isSelected
                                  ? const Color(0xFF1DB954)
                                  : Colors.white,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4.0),
                        const Icon(
                          Icons.verified_rounded,
                          size: 14.0,
                          color: Color(0xFF1DB954),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2.0),
                    Text(
                      artistItem?.genre.isNotEmpty == true
                          ? artistItem!.genre
                          : 'Artist',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.60),
                        fontSize: 12.0,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

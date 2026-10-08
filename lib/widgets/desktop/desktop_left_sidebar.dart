import 'package:flutter/material.dart';
import '../../layouts/desktop_layout_state.dart';
import '../../services/music_service.dart';
import '../../screens/custom_playlist_screen.dart';
import '../playlist_action_menu.dart';
import '../dilse_tooltip.dart';

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
  final ValueNotifier<String?> _selectedFilter = ValueNotifier<String?>(null);
  final ValueNotifier<bool> _isSearchActive = ValueNotifier<bool>(false);
  final TextEditingController _searchController = TextEditingController();
  String? _hoveredRowId;

  @override
  void dispose() {
    _selectedFilter.dispose();
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
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CustomPlaylistScreen(playlistId: newId),
                    ),
                  );
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
    return Container(
      margin: const EdgeInsets.fromLTRB(8.0, 8.0, 0.0, 8.0),
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 14.0),
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
          // Logo Top Anchor
          Container(
            width: 40.0,
            height: 40.0,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFA2D48), Color(0xFFFF6B81)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10.0),
            ),
            child: const Icon(
              Icons.music_note_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(height: 16.0),

          // Primary Navigation Icons
          _buildCompactNavIcon(
            icon: Icons.home_filled,
            label: 'Home',
            onTap: () {},
          ),
          _buildCompactNavIcon(
            icon: Icons.search_rounded,
            label: 'Search',
            onTap: () {},
          ),
          _buildCompactNavIcon(
            icon: Icons.library_music_rounded,
            label: 'Your Library',
            onTap: () => DesktopLayoutState.toggleLeftSidebar(),
          ),

          const SizedBox(height: 10.0),
          Divider(color: Colors.white.withValues(alpha: 0.08), height: 1.0),
          const SizedBox(height: 10.0),

          // Create Playlist Action
          _buildCompactNavIcon(
            icon: Icons.add_rounded,
            label: 'Create Playlist',
            color: Colors.white70,
            onTap: _showCreatePlaylistDialog,
          ),

          // Liked Songs Squircle Icon
          _buildCompactNavIcon(
            icon: Icons.favorite_rounded,
            label: 'Liked Songs (${_musicService.likedSongs.length})',
            color: const Color(0xFFFA2D48),
            onTap: () {
              if (_musicService.likedSongs.isNotEmpty) {
                _musicService.playLikedSong(_musicService.likedSongs.first);
              }
            },
          ),

          const SizedBox(height: 8.0),

          // Custom Playlists Squircles List
          Expanded(
            child: AnimatedBuilder(
              animation: _musicService,
              builder: (context, _) {
                final playlists = _musicService.customPlaylists;
                return ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: playlists.length > 8 ? 8 : playlists.length,
                  itemBuilder: (context, index) {
                    final pl = playlists[index];
                    final name = pl['name']?.toString() ?? 'Playlist';
                    final id = pl['id']?.toString() ?? '';

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: DilSeTooltip(
                        message: name,
                        child: GestureDetector(
                          onTap: () {
                            if (id.isNotEmpty) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      CustomPlaylistScreen(playlistId: id),
                                ),
                              );
                            }
                          },
                          child: Container(
                            width: 44.0,
                            height: 44.0,
                            decoration: BoxDecoration(
                              color: const Color(0xFF282836),
                              borderRadius: BorderRadius.circular(8.0),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.06),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                name.isNotEmpty ? name[0].toUpperCase() : 'P',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16.0,
                                ),
                              ),
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
  }

  Widget _buildCompactNavIcon({
    required IconData icon,
    required String label,
    Color? color,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
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
              borderRadius: BorderRadius.circular(10.0),
            ),
            child: Icon(
              icon,
              color: color ?? Colors.white.withValues(alpha: 0.8),
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
          child: Column(
            children: [
              _buildNavRow(
                icon: Icons.home_filled,
                title: 'Home',
                isActive: true,
                onTap: () {},
              ),
              const SizedBox(height: 6.0),
              _buildNavRow(
                icon: Icons.search_rounded,
                title: 'Search',
                isActive: false,
                onTap: () {},
              ),
            ],
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
                            tooltip: 'Collapse Library',
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

                // Horizontal Filter Chips Strip
                SizedBox(
                  height: 34.0,
                  child: ValueListenableBuilder<String?>(
                    valueListenable: _selectedFilter,
                    builder: (context, activeFilter, _) {
                      return ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 14.0),
                        children: [
                          _buildFilterChip('Playlists', activeFilter),
                          _buildFilterChip('Albums', activeFilter),
                          _buildFilterChip(
                            'Imported from Spotify',
                            activeFilter,
                          ),
                          _buildFilterChip('History', activeFilter),
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
                      _selectedFilter,
                    ]),
                    builder: (context, _) {
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

  Widget _buildFilterChip(String label, String? activeFilter) {
    final isSelected = activeFilter == label;

    return Padding(
      padding: const EdgeInsets.only(right: 6.0),
      child: GestureDetector(
        onTap: () {
          _selectedFilter.value = isSelected ? null : label;
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
                  ? Colors.white.withValues(alpha: 0.2)
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
    final filter = _selectedFilter.value;
    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty && !'liked songs'.contains(query)) {
      return false;
    }
    if (filter == 'Albums' || filter == 'History') {
      return false;
    }
    return true;
  }

  List<Map<String, dynamic>> _getFilteredPlaylists() {
    final allPlaylists = _musicService.customPlaylists;
    final filter = _selectedFilter.value;
    final query = _searchController.text.trim().toLowerCase();

    return allPlaylists.where((pl) {
      final name = pl['name']?.toString().toLowerCase() ?? '';
      final isSpotify =
          pl['isSpotify'] == true ||
          (pl['source']?.toString().contains('spotify') ?? false);

      if (query.isNotEmpty && !name.contains(query)) {
        return false;
      }

      if (filter == 'Playlists') {
        return true;
      }
      if (filter == 'Imported from Spotify') {
        return isSpotify;
      }
      if (filter == 'Albums') {
        return pl['type'] == 'album';
      }
      return true;
    }).toList();
  }

  Widget _buildLikedSongsRow(BuildContext context) {
    final count = _musicService.likedSongs.length;
    final isHovered = _hoveredRowId == 'liked_songs';

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredRowId = 'liked_songs'),
      onExit: (_) => setState(() => _hoveredRowId = null),
      child: InkWell(
        borderRadius: BorderRadius.circular(8.0),
        onTap: () {
          if (_musicService.likedSongs.isNotEmpty) {
            _musicService.playLikedSong(_musicService.likedSongs.first);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
          decoration: BoxDecoration(
            color: isHovered
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
                    const Text(
                      'Liked Songs',
                      style: TextStyle(
                        color: Colors.white,
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
                            'Playlist • $count songs',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
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
    );
  }

  Widget _buildPlaylistRow(BuildContext context, Map<String, dynamic> pl) {
    final id = pl['id']?.toString() ?? '';
    final name = pl['name']?.toString() ?? 'Untitled Playlist';
    final isSpotify = pl['isSpotify'] == true;
    final trackCount =
        (pl['tracks'] as List?)?.length ?? (pl['songs'] as List?)?.length ?? 0;
    final isHovered = _hoveredRowId == id;

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredRowId = id),
      onExit: (_) => setState(() => _hoveredRowId = null),
      child: InkWell(
        borderRadius: BorderRadius.circular(8.0),
        onTap: () {
          if (id.isNotEmpty) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CustomPlaylistScreen(playlistId: id),
              ),
            );
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
          decoration: BoxDecoration(
            color: isHovered
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
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2.0),
                    Text(
                      isSpotify
                          ? 'Playlist • Spotify Import'
                          : 'Playlist • $trackCount songs',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12.0,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
    );
  }
}

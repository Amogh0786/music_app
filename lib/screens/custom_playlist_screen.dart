import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/music_service.dart';
import '../widgets/mini_player.dart';

class CustomPlaylistScreen extends StatefulWidget {
  final String playlistId;
  const CustomPlaylistScreen({super.key, required this.playlistId});

  @override
  State<CustomPlaylistScreen> createState() => _CustomPlaylistScreenState();
}

class _CustomPlaylistScreenState extends State<CustomPlaylistScreen> {
  final MusicService _musicService = MusicService();

  @override
  void initState() {
    super.initState();
    _musicService.addListener(_onServiceChanged);
  }

  @override
  void dispose() {
    _musicService.removeListener(_onServiceChanged);
    super.dispose();
  }

  void _onServiceChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final playlist = _musicService.customPlaylists.firstWhere(
      (p) => p['id'] == widget.playlistId,
      orElse: () => <String, dynamic>{},
    );

    if (playlist.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFF121212),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(
          child: Text(
            'Playlist not found',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ),
      );
    }

    final name = (playlist['name'] as String?) ?? 'Custom Playlist';
    final songs = List<Map<String, dynamic>>.from(playlist['songs'] ?? []);
    final firstThumbnail = songs.isNotEmpty ? songs.first['thumbnail'] as String? : null;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverAppBar(
                backgroundColor: const Color(0xFF181822),
                expandedHeight: 260,
                pinned: true,
                stretch: true,
                leading: IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Colors.black38,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  centerTitle: false,
                  titlePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  title: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      fontSize: 20,
                      letterSpacing: -0.3,
                    ),
                  ),
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (firstThumbnail != null && firstThumbnail.isNotEmpty)
                        Image.network(
                          firstThumbnail,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => _buildDefaultArtwork(),
                        )
                      else
                        _buildDefaultArtwork(),
                      // Gradient overlay
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.black.withValues(alpha: 0.3),
                              const Color(0xFF121212).withValues(alpha: 0.95),
                              const Color(0xFF121212),
                            ],
                            stops: const [0.0, 0.7, 1.0],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Action Buttons Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: Row(
                    children: [
                      Text(
                        '${songs.length} ${songs.length == 1 ? "track" : "tracks"} • Drag handle to reorder',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      if (songs.isNotEmpty) ...[
                        ElevatedButton.icon(
                          icon: const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 22),
                          label: const Text(
                            'Play',
                            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                            elevation: 4,
                          ),
                          onPressed: () {
                            HapticFeedback.mediumImpact();
                            _musicService.playCustomPlaylist(widget.playlistId, 0);
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Song List or Empty State
              if (songs.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.music_note_rounded, size: 64, color: Colors.white.withValues(alpha: 0.2)),
                        const SizedBox(height: 12),
                        const Text(
                          'No songs in this playlist yet',
                          style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Add songs from search or the player options',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverReorderableList(
                  itemCount: songs.length,
                  itemExtent: 72.0,
                  // ignore: deprecated_member_use
                  onReorder: (oldIndex, newIndex) {
                    HapticFeedback.lightImpact();
                    _musicService.reorderPlaylistSongs(widget.playlistId, oldIndex, newIndex);
                  },
                  itemBuilder: (context, index) {
                    final song = songs[index];
                    final songId = (song['id'] as String?) ?? '';
                    final isCurrent = _musicService.currentSong?.id.value == songId;
                    final thumb = song['thumbnail'] as String? ?? '';

                    return ReorderableDelayedDragStartListener(
                      key: ValueKey('song_${songId}_$index'),
                      index: index,
                      child: Dismissible(
                        key: ValueKey('dismiss_${songId}_$index'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          color: Colors.redAccent.withValues(alpha: 0.8),
                          child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 26),
                        ),
                        onDismissed: (_) {
                          HapticFeedback.mediumImpact();
                          _musicService.removeSongFromPlaylist(widget.playlistId, songId);
                        },
                        child: Container(
                          height: 72.0,
                          color: isCurrent
                              ? Theme.of(context).primaryColor.withValues(alpha: 0.12)
                              : Colors.transparent,
                          child: ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            leading: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 28,
                                  child: Text(
                                    '${index + 1}',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: isCurrent
                                          ? Theme.of(context).primaryColor
                                          : Colors.white.withValues(alpha: 0.4),
                                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    width: 48,
                                    height: 48,
                                    color: const Color(0xFF1E1E28),
                                    child: thumb.isNotEmpty
                                        ? Image.network(
                                            thumb,
                                            width: 48,
                                            height: 48,
                                            cacheWidth: 120,
                                            cacheHeight: 120,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) => const Icon(
                                              Icons.music_note_rounded,
                                              color: Colors.white30,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.music_note_rounded,
                                            color: Colors.white30,
                                          ),
                                  ),
                                ),
                              ],
                            ),
                            title: Text(
                              (song['title'] as String?) ?? 'Unknown Title',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isCurrent ? Theme.of(context).primaryColor : Colors.white,
                                fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                                fontSize: 14.5,
                              ),
                            ),
                            subtitle: Text(
                              (song['author'] as String?) ?? 'Unknown Artist',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 12.5,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.close_rounded, color: Colors.white30, size: 20),
                                  tooltip: 'Remove from playlist',
                                  onPressed: () {
                                    HapticFeedback.lightImpact();
                                    _musicService.removeSongFromPlaylist(widget.playlistId, songId);
                                  },
                                ),
                                ReorderableDragStartListener(
                                  index: index,
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                                    child: Icon(
                                      Icons.drag_handle_rounded,
                                      color: Colors.white38,
                                      size: 22,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            onTap: () {
                              HapticFeedback.lightImpact();
                              _musicService.playCustomPlaylist(widget.playlistId, index);
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),

              // Bottom spacing for miniplayer
              const SliverToBoxAdapter(
                child: SizedBox(height: 120),
              ),
            ],
          ),

          // Persistent MiniPlayer at bottom
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: MiniPlayer(),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultArtwork() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2A1B3D), Color(0xFF121212)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(Icons.featured_play_list_rounded, size: 72, color: Colors.white24),
      ),
    );
  }
}

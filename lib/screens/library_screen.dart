import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/music_service.dart';
import '../services/preferences_service.dart';
import 'spotify_import_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final MusicService _musicService = MusicService();
  final PreferencesService _prefs = PreferencesService();

  int _totalDownloadedBytes = 0;
  final Map<String, int> _songFileSizes = {};

  @override
  void initState() {
    super.initState();
    _musicService.addListener(_onStateChanged);
    _prefs.addListener(_onStateChanged);
    _calculateStorageUsage();
  }

  @override
  void dispose() {
    _musicService.removeListener(_onStateChanged);
    _prefs.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    if (mounted) {
      _calculateStorageUsage();
      setState(() {});
    }
  }

  Future<void> _calculateStorageUsage() async {
    int total = 0;
    final downloaded = _musicService.downloadedSongs;
    for (final s in downloaded) {
      final path = s['localPath'];
      final id = s['id'] ?? '';
      if (path != null && id.isNotEmpty) {
        try {
          final f = File(path);
          if (await f.exists()) {
            final len = await f.length();
            _songFileSizes[id] = len;
            total += len;
          }
        } catch (_) {}
      }
    }
    if (mounted) {
      setState(() {
        _totalDownloadedBytes = total;
      });
    }
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 MB';
    final mb = bytes / (1024 * 1024);
    if (mb < 1.0) {
      final kb = bytes / 1024;
      return '${kb.toStringAsFixed(0)} KB';
    }
    return '${mb.toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final downloaded = _musicService.downloadedSongs;
    final liked = _musicService.likedSongs;
    final history = _prefs.listeningHistory;
    final primaryColor = Theme.of(context).primaryColor;

    final allocatedMB = _prefs.cacheSizeMB > 0 ? _prefs.cacheSizeMB : 500.0;
    final usedMB = _totalDownloadedBytes / (1024 * 1024);
    final storageFraction = (usedMB / allocatedMB).clamp(0.0, 1.0);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFF0B0B0F),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0B0B0F),
          elevation: 0,
          title: const Text(
            'Your Library',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 30,
              color: Colors.white,
              letterSpacing: -0.8,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.queue_music_rounded, color: Color(0xFF1DB954)),
              tooltip: 'Import from Spotify',
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SpotifyImportScreen()),
                );
              },
            ),
            const SizedBox(width: 8),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(138),
            child: Column(
              children: [
                // Storage Usage Ring Meter Card
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161622),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // Storage Ring Indicator
                        SizedBox(
                          width: 46,
                          height: 46,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              CircularProgressIndicator(
                                value: storageFraction,
                                strokeWidth: 4.5,
                                backgroundColor: Colors.white12,
                                valueColor: AlwaysStoppedAnimation(
                                  storageFraction > 0.9 ? Colors.orangeAccent : primaryColor,
                                ),
                              ),
                              Icon(
                                Icons.offline_pin_rounded,
                                color: storageFraction > 0.9 ? Colors.orangeAccent : primaryColor,
                                size: 22,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        // Storage Details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    '${usedMB.toStringAsFixed(1)} MB',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                  Text(
                                    ' / ${allocatedMB.toStringAsFixed(0)} MB',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.5),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                downloaded.isEmpty
                                    ? 'Offline Storage Ready • Lossless'
                                    : '${downloaded.length} Offline Tracks Saved',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.65),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Manage Pill Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: primaryColor.withValues(alpha: 0.35),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            '${(storageFraction * 100).toInt()}% Used',
                            style: TextStyle(
                              color: primaryColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Modern Pill TabBar
                TabBar(
                  indicatorColor: primaryColor,
                  indicatorWeight: 3,
                  indicatorSize: TabBarIndicatorSize.label,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white38,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    letterSpacing: -0.2,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 13.5,
                  ),
                  tabs: [
                    Tab(text: 'Downloaded (${downloaded.length})'),
                    Tab(text: 'Liked (${liked.length})'),
                    Tab(text: 'History (${history.length})'),
                  ],
                ),
              ],
            ),
          ),
        ),
        body: TabBarView(
          children: [
            // TAB 1: DOWNLOADED SONGS
            downloaded.isEmpty
                ? _buildEmptyState(
                    icon: Icons.download_for_offline_outlined,
                    title: 'No downloaded songs yet',
                    subtitle: 'Tap the download icon while playing any song to listen offline without internet.',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 160, top: 12),
                    itemCount: downloaded.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return _buildActionHeader(
                          count: downloaded.length,
                          onPlayAll: () {
                            HapticFeedback.lightImpact();
                            _musicService.playDownloadedSong(downloaded.first);
                          },
                          onShuffle: () {
                            HapticFeedback.lightImpact();
                            _musicService.toggleShuffle();
                            _musicService.playDownloadedSong(downloaded.first);
                          },
                        );
                      }

                      final song = downloaded[index - 1];
                      final songId = song['id'] ?? '';
                      final sizeBytes = _songFileSizes[songId] ?? 0;
                      final sizeFormatted = _formatBytes(sizeBytes);

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                            width: 52,
                            height: 52,
                            child: Image.network(
                              song['thumbnail'] ?? '',
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Container(
                                color: const Color(0xFF1E1E28),
                                child: const Icon(Icons.music_note, color: Colors.white54),
                              ),
                            ),
                          ),
                        ),
                        title: Text(
                          song['title'] ?? 'Unknown',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            fontSize: 14.5,
                            letterSpacing: -0.2,
                          ),
                        ),
                        subtitle: Row(
                          children: [
                            Flexible(
                              child: Text(
                                song['author'] ?? 'Unknown Artist',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                            if (sizeBytes > 0) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: Colors.white12,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  sizeFormatted,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.offline_pin_rounded, color: Color(0xFF1DB954), size: 20),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: Colors.white38, size: 20),
                              onPressed: () async {
                                HapticFeedback.mediumImpact();
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    backgroundColor: const Color(0xFF1E1E28),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                    title: const Text('Delete Download?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                    content: Text('Remove "${song['title']}" from offline storage?', style: const TextStyle(color: Colors.white70)),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx, true),
                                        child: const Text('Delete', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  await _musicService.deleteDownloadedSong(song['id']!);
                                }
                              },
                            ),
                          ],
                        ),
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _musicService.playDownloadedSong(song);
                        },
                      );
                    },
                  ),

            // TAB 2: LIKED SONGS
            liked.isEmpty
                ? _buildEmptyState(
                    icon: Icons.favorite_border_rounded,
                    title: 'No liked songs yet',
                    subtitle: 'Tap the heart icon while playing any song to save it in your favorites collection.',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 160, top: 12),
                    itemCount: liked.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return _buildActionHeader(
                          count: liked.length,
                          onPlayAll: () {
                            HapticFeedback.lightImpact();
                            _musicService.playLikedSong(liked.first);
                          },
                          onShuffle: () {
                            HapticFeedback.lightImpact();
                            _musicService.toggleShuffle();
                            _musicService.playLikedSong(liked.first);
                          },
                        );
                      }

                      final song = liked[index - 1];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                            width: 52,
                            height: 52,
                            child: Image.network(
                              song['thumbnail'] ?? '',
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Container(
                                color: const Color(0xFF1E1E28),
                                child: const Icon(Icons.music_note, color: Colors.white54),
                              ),
                            ),
                          ),
                        ),
                        title: Text(
                          song['title'] ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            fontSize: 14.5,
                            letterSpacing: -0.2,
                          ),
                        ),
                        subtitle: Text(
                          song['author'] ?? '',
                          maxLines: 1,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 12.5,
                          ),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.favorite_rounded, color: Color(0xFFFA2D48), size: 22),
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            _musicService.removeLikedSong(song['id'] ?? '');
                          },
                        ),
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _musicService.playLikedSong(song);
                        },
                      );
                    },
                  ),

            // TAB 3: LISTENING HISTORY
            history.isEmpty
                ? _buildEmptyState(
                    icon: Icons.history_toggle_off_rounded,
                    title: 'No listening history yet',
                    subtitle: 'Songs you stream will automatically appear here for quick replay.',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 160, top: 12),
                    itemCount: history.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${history.length} Recently Played',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              TextButton.icon(
                                icon: const Icon(Icons.delete_sweep_rounded, size: 16, color: Colors.white54),
                                label: const Text('Clear', style: TextStyle(color: Colors.white54, fontSize: 13)),
                                onPressed: () {
                                  HapticFeedback.lightImpact();
                                  _prefs.clearListeningHistory();
                                },
                              ),
                            ],
                          ),
                        );
                      }

                      final song = history[index - 1];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                            width: 52,
                            height: 52,
                            child: Image.network(
                              song['thumbnail'] ?? '',
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Container(
                                color: const Color(0xFF1E1E28),
                                child: const Icon(Icons.music_note, color: Colors.white54),
                              ),
                            ),
                          ),
                        ),
                        title: Text(
                          song['title'] ?? 'Unknown Track',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            fontSize: 14.5,
                            letterSpacing: -0.2,
                          ),
                        ),
                        subtitle: Text(
                          song['author'] ?? 'Unknown Artist',
                          maxLines: 1,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 12.5,
                          ),
                        ),
                        trailing: const Icon(Icons.play_circle_fill_rounded, color: Colors.white38, size: 24),
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _musicService.playHistorySong(song);
                        },
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionHeader({
    required int count,
    required VoidCallback onPlayAll,
    required VoidCallback onShuffle,
  }) {
    final primaryColor = Theme.of(context).primaryColor;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20),
              label: Text('Play All ($count)', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: onPlayAll,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.shuffle_rounded, color: Colors.white70, size: 18),
              label: const Text('Shuffle', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: onShuffle,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: const Color(0xFF161622),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white12, width: 1),
              ),
              child: Icon(icon, size: 48, color: Colors.white54),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 13,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

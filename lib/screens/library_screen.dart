import 'package:flutter/material.dart';
import '../services/music_service.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final MusicService _musicService = MusicService();

  @override
  void initState() {
    super.initState();
    _musicService.addListener(_onStateChanged);
  }

  @override
  void dispose() {
    _musicService.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final downloaded = _musicService.downloadedSongs;
    final liked = _musicService.likedSongs;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFF121212),
        appBar: AppBar(
          backgroundColor: const Color(0xFF121212),
          title: const Text('Your Library', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
          bottom: TabBar(
            indicatorColor: Theme.of(context).primaryColor,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
            tabs: [
              Tab(text: 'Downloaded (${downloaded.length})'),
              Tab(text: 'Liked (${liked.length})'),
              const Tab(text: 'Playlists'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Tab 1: Downloaded Songs
            downloaded.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.download_for_offline_outlined, size: 64, color: Colors.grey[700]),
                        const SizedBox(height: 16),
                        Text(
                          'No downloaded songs yet',
                          style: TextStyle(color: Colors.grey[400], fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap the download icon while playing a song to save it offline!',
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 110, top: 8),
                    itemCount: downloaded.length,
                    itemBuilder: (context, index) {
                      final song = downloaded[index];
                      return ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              image: DecorationImage(
                                image: NetworkImage(song['thumbnail'] ?? ''),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                        title: Text(
                          song['title'] ?? 'Unknown',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        subtitle: Text(
                          song['author'] ?? 'Unknown Artist',
                          maxLines: 1,
                          style: const TextStyle(color: Colors.grey),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.offline_pin, color: Color(0xFF1DB954), size: 22),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.white38, size: 20),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    backgroundColor: const Color(0xFF1E1E1E),
                                    title: const Text('Delete Download?', style: TextStyle(color: Colors.white)),
                                    content: Text('Remove "${song['title']}" from offline storage?', style: const TextStyle(color: Colors.white70)),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                      TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.redAccent))),
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
                          _musicService.playDownloadedSong(song);
                        },
                      );
                    },
                  ),

            // Tab 2: Liked Songs
            liked.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.favorite_border, size: 64, color: Colors.grey[700]),
                        const SizedBox(height: 16),
                        Text(
                          'No liked songs yet',
                          style: TextStyle(color: Colors.grey[400], fontSize: 16),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 110, top: 8),
                    itemCount: liked.length,
                    itemBuilder: (context, index) {
                      final song = liked[index];
                      return ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              image: DecorationImage(
                                image: NetworkImage(song['thumbnail'] ?? ''),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                        title: Text(
                          song['title'] ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        subtitle: Text(
                          song['author'] ?? '',
                          maxLines: 1,
                          style: const TextStyle(color: Colors.grey),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.favorite, color: Color(0xFFFA2D48), size: 22),
                          onPressed: () {
                            _musicService.removeLikedSong(song['id'] ?? '');
                          },
                        ),
                        onTap: () {
                          _musicService.playLikedSong(song);
                        },
                      );
                    },
                  ),

            // Tab 3: Playlists Placeholder
            const Center(
              child: Text(
                'Your Custom Playlists will appear here',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

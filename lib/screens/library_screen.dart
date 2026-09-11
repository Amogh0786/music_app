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

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Your Library', style: TextStyle(fontWeight: FontWeight.bold)),
          bottom: TabBar(
            indicatorColor: const Color(0xFF1DB954),
            tabs: [
              Tab(text: 'Downloaded (${downloaded.length})'),
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
                    itemCount: downloaded.length,
                    itemBuilder: (context, index) {
                      final song = downloaded[index];
                      return ListTile(
                        leading: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            image: DecorationImage(
                              image: NetworkImage(song['thumbnail']!),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        title: Text(
                          song['title']!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          song['author']!,
                          maxLines: 1,
                          style: const TextStyle(color: Colors.grey),
                        ),
                        trailing: const Icon(Icons.offline_pin, color: Color(0xFF1DB954)),
                        onTap: () {
                          _musicService.playDownloadedSong(song);
                        },
                      );
                    },
                  ),

            // Tab 2: Playlists Placeholder
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

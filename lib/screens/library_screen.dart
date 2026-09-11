import 'package:flutter/material.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Your Library', style: TextStyle(fontWeight: FontWeight.bold)),
          bottom: const TabBar(
            indicatorColor: Color(0xFF1DB954),
            tabs: [
              Tab(text: 'Playlists'),
              Tab(text: 'Downloaded'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            Center(child: Text('Your Playlists will appear here')),
            Center(child: Text('Downloaded songs for offline play')),
          ],
        ),
      ),
    );
  }
}

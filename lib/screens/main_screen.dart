import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'search_screen.dart';
import 'library_screen.dart';
import '../widgets/mini_player.dart';
import '../services/music_service.dart';
import '../services/notification_permission_service.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    SearchScreen(),
    LibraryScreen(),
  ];

  @override
  void initState() {
    super.initState();
    MusicService().addListener(_onMusicServiceChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        NotificationPermissionService.promptIfNeeded(context);
      }
    });
  }

  @override
  void dispose() {
    MusicService().removeListener(_onMusicServiceChanged);
    super.dispose();
  }

  void _onMusicServiceChanged() {
    if (MusicService().currentSong != null && mounted) {
      NotificationPermissionService.promptIfNeeded(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Stack(
        children: [
          IndexedStack(
            index: _selectedIndex,
            children: _screens,
          ),
          // Floating Mini Player pinned above the Bottom Navigation Bar
          const Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: MiniPlayer(),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF121212),
        selectedItemColor: Theme.of(context).primaryColor, // Apple Music Red Accent
        unselectedItemColor: Colors.grey[600],
        currentIndex: _selectedIndex,
        type: BottomNavigationBarType.fixed,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.play_circle_outline),
            activeIcon: Icon(Icons.play_circle_fill),
            label: 'Listen Now',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search_outlined),
            activeIcon: Icon(Icons.search),
            label: 'Search',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.library_music_outlined),
            activeIcon: Icon(Icons.library_music),
            label: 'Library',
          ),
        ],
      ),
    );
  }
}

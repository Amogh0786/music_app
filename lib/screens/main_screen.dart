import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'home_screen.dart';
import 'search_screen.dart';
import 'library_screen.dart';
import '../widgets/mini_player.dart';
import '../widgets/floating_nav_dock.dart';
import '../services/music_service.dart';
import '../services/preferences_service.dart';
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
        _checkFirstTimeNamePrompt();
        NotificationPermissionService.promptIfNeeded(context);
      }
    });
  }

  void _checkFirstTimeNamePrompt() {
    final prefs = PreferencesService();
    if (!prefs.hasPromptedName) {
      final controller = TextEditingController(
        text: prefs.userName == 'Friend' ? '' : prefs.userName,
      );
      showModalBottomSheet(
        context: context,
        isDismissible: false,
        enableDrag: false,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (ctx) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: const Color(0xFF161622).withValues(alpha: 0.95),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFA2D48).withValues(alpha: 0.5),
                            blurRadius: 24,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Image.asset('assets/images/dilse_logo.png', fit: BoxFit.cover),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Welcome to DilSe',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'What should we call you for your personalized music experience?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: controller,
                      autofocus: true,
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        hintText: 'Enter your name',
                        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.08),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Color(0xFFFA2D48), width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      ),
                      onSubmitted: (val) {
                        final name = val.trim();
                        prefs.setUserName(name.isEmpty ? 'Friend' : name);
                        HapticFeedback.mediumImpact();
                        Navigator.pop(ctx);
                      },
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFA2D48),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        onPressed: () {
                          final name = controller.text.trim();
                          prefs.setUserName(name.isEmpty ? 'Friend' : name);
                          HapticFeedback.mediumImpact();
                          Navigator.pop(ctx);
                        },
                        child: const Text(
                          "Let's Start Listening",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          );
        },
      );
    }
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
      backgroundColor: const Color(0xFF0B0B0F),
      body: Stack(
        children: [
          IndexedStack(
            index: _selectedIndex,
            children: _screens,
          ),
          // Floating Mini Player & Floating Glass Dock stacked at the bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const MiniPlayer(),
                FloatingNavDock(
                  selectedIndex: _selectedIndex,
                  onTabSelected: (index) => setState(() => _selectedIndex = index),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

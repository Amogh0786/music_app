import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'search_screen.dart';
import 'library_screen.dart';
import '../widgets/mini_player.dart';
import '../widgets/floating_nav_dock.dart';
import '../widgets/interactive_update_dialog.dart';
import '../widgets/welcome_onboarding_dialog.dart';
import '../services/music_service.dart';
import '../services/preferences_service.dart';
import '../services/notification_permission_service.dart';
import '../services/update_service.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  late final PageController _pageController;

  final List<Widget> _screens = const [
    HomeScreen(),
    SearchScreen(),
    LibraryScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedIndex);
    MusicService().addListener(_onMusicServiceChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _checkFirstTimeNamePrompt();
        NotificationPermissionService.promptIfNeeded(context);
        _checkAutoAppUpdate();
      }
    });
  }

  Future<void> _checkAutoAppUpdate() async {
    // Only check for updates on mobile devices after intro animation
    if (kIsWeb) return;
    final prefs = PreferencesService();
    if (!prefs.hasPromptedName) return; // Wait until name prompt is completed
    await Future.delayed(const Duration(milliseconds: 1000));
    if (!mounted) return;

    try {
      final updateInfo = await UpdateService().checkForUpdate();
      if (!mounted) return;
      if (updateInfo != null && updateInfo.hasUpdate) {
        showDialog(
          context: context,
          barrierDismissible: true,
          barrierColor: Colors.black.withValues(alpha: 0.75),
          builder: (ctx) => InteractiveUpdateDialog(info: updateInfo),
        );
      }
    } catch (e) {
      debugPrint('[MainScreen] Auto update check deferred: $e');
    }
  }

  void _checkFirstTimeNamePrompt() {
    final prefs = PreferencesService();
    if (!prefs.hasPromptedName) {
      WelcomeOnboardingDialog.show(
        context,
        onCompleted: () {
          _checkAutoAppUpdate();
        },
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
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
          PageView(
            controller: _pageController,
            physics: const ClampingScrollPhysics(),
            onPageChanged: (index) {
              setState(() => _selectedIndex = index);
            },
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
                  onTabSelected: (index) {
                    setState(() => _selectedIndex = index);
                    _pageController.animateToPage(
                      index,
                      duration: const Duration(milliseconds: 320),
                      curve: Curves.easeOutCubic,
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

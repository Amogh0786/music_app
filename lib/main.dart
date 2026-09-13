import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'screens/main_screen.dart';
import 'services/preferences_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.example.music_app.channel.audio_playback_v2',
      androidNotificationChannelName: 'Music Playback & Controls',
      androidNotificationChannelDescription: 'Music playback controls and lock screen notification',
      androidNotificationIcon: 'drawable/ic_stat_music',
      androidNotificationOngoing: false,
      androidStopForegroundOnPause: false,
      notificationColor: const Color(0xFFFA2D48),
    );
  } catch (e) {
    debugPrint('JustAudioBackground init warning: $e');
  }
  await PreferencesService().init();
  runApp(const MusicApp());
}

class MusicApp extends StatelessWidget {
  const MusicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: PreferencesService(),
      builder: (context, child) {
        final prefs = PreferencesService();
        return MaterialApp(
          title: 'Music App',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor: const Color(0xFF121212),
            primaryColor: prefs.themeColor,
            bottomNavigationBarTheme: BottomNavigationBarThemeData(
              backgroundColor: Colors.black,
              selectedItemColor: prefs.themeColor,
              unselectedItemColor: Colors.white54,
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF121212),
              elevation: 0,
            ),
            useMaterial3: true,
          ),
          home: const MainScreen(),
        );
      },
    );
  }
}

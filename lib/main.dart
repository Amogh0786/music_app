import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'services/audio_handler.dart';
import 'screens/intro_splash_screen.dart';
import 'services/preferences_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    try {
      await initAudioService();
    } catch (e) {
      debugPrint('AudioService init warning: $e');
    }
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
          title: 'DilSe',
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
          home: const IntroSplashScreen(),
        );
      },
    );
  }
}

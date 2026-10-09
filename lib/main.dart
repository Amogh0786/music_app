import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'services/audio_handler.dart';
import 'screens/intro_splash_screen.dart';
import 'services/preferences_service.dart';
import 'services/bug_report_service.dart';

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
  await BugReportService.instance.init();
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
          navigatorKey: BugReportService.instance.rootNavKey,
          builder: (context, child) {
            final appChild = child ?? const SizedBox.shrink();
            final mediaQuery = MediaQuery.of(context);
            // Samsung One UI font scaling guard: clamp system font scaling to [0.85, 1.15]
            // Prevents UI scattering, overflow errors, and button collisions on Samsung Galaxy devices.
            final clampedMediaQuery = mediaQuery.copyWith(
              textScaler: mediaQuery.textScaler.clamp(
                minScaleFactor: 0.85,
                maxScaleFactor: 1.15,
              ),
            );
            final wrapped = MediaQuery(
              data: clampedMediaQuery,
              child: appChild,
            );
            if (kIsWeb) {
              return wrapped;
            }
            return RepaintBoundary(
              key: BugReportService.instance.repaintBoundaryKey,
              child: wrapped,
            );
          },
          home: const IntroSplashScreen(),
        );
      },
    );
  }
}

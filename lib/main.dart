import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'services/audio_handler.dart';
import 'services/widget_service.dart';
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
    try {
      await WidgetService().init();
    } catch (e) {
      debugPrint('WidgetService init warning: $e');
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
        final primaryColor = prefs.themeColor;

        return MaterialApp(
          navigatorKey: WidgetService.navigatorKey,
          title: 'DilSe',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor: const Color(0xFF07070A),
            primaryColor: primaryColor,
            colorScheme: ColorScheme.dark(
              primary: primaryColor,
              secondary: primaryColor,
              surface: const Color(0xFF0E0E14),
              onSurface: Colors.white,
            ),
            cardTheme: CardThemeData(
              color: const Color(0xFF12121A),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.08), width: 0.8),
              ),
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF07070A),
              elevation: 0,
              scrolledUnderElevation: 0,
              centerTitle: false,
              titleTextStyle: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
              ),
              iconTheme: IconThemeData(color: Colors.white),
            ),
            bottomSheetTheme: const BottomSheetThemeData(
              backgroundColor: Colors.transparent,
              elevation: 0,
              modalBackgroundColor: Colors.transparent,
            ),
            dialogTheme: DialogThemeData(
              backgroundColor: const Color(0xFF14141E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.10), width: 1),
              ),
              elevation: 24,
            ),
            pageTransitionsTheme: const PageTransitionsTheme(
              builders: {
                TargetPlatform.android: CupertinoPageTransitionsBuilder(),
                TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
                TargetPlatform.windows: ZoomPageTransitionsBuilder(),
                TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
                TargetPlatform.linux: ZoomPageTransitionsBuilder(),
              },
            ),
            useMaterial3: true,
          ),
          home: const IntroSplashScreen(),
        );
      },
    );
  }
}

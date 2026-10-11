import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/widgets/animated_lyrics.dart';

import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'AnimatedLyrics parses multi-format LRC timestamps and highlights correctly',
    (WidgetTester tester) async {
      const rawLrc = '''
[ti:Test Title]
[ar:Test Artist]
[00:02.50]First line of song
[00:05.00]Second line with delay
[00:08.500]Third line with 3-digit ms
[00:12]Fourth line with no ms
''';

      final positionController = StreamController<Duration>.broadcast();

      Duration? seekTarget;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(primaryColor: const Color(0xFFFA2D48)),
          home: Scaffold(
            body: AnimatedLyrics(
              rawLyrics: rawLrc,
              positionStream: positionController.stream,
              onSeek: (target) {
                seekTarget = target;
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify all 4 text lines are rendered (metadata tags [ar:...] should be ignored)
      expect(find.text('First line of song'), findsOneWidget);
      expect(find.text('Second line with delay'), findsOneWidget);
      expect(find.text('Third line with 3-digit ms'), findsOneWidget);
      expect(find.text('Fourth line with no ms'), findsOneWidget);

      // Initial position: 0s (no line should be active yet, intro)
      positionController.add(Duration.zero);
      await tester.pumpAndSettle();

      // Emit position 3s -> "First line of song" should be active
      positionController.add(const Duration(seconds: 3));
      await tester.pump(const Duration(milliseconds: 300));

      // Tap on second line to test seek
      await tester.tap(find.text('Second line with delay'));
      await tester.pump();
      expect(seekTarget, equals(const Duration(seconds: 5)));

      // Emit position 9s -> "Third line with 3-digit ms" should be active
      positionController.add(const Duration(seconds: 9));
      await tester.pump(const Duration(milliseconds: 300));

      await positionController.close();
    },
  );

  testWidgets(
    'AnimatedLyrics shows Original, English, and Dual modes for regional Indic lyrics',
    (WidgetTester tester) async {
      const regionalLrc = '''
[00:02.00]సమాజవరగమనా
[00:05.00]చూసి చూడంగానే
''';

      final positionController = StreamController<Duration>.broadcast();

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(primaryColor: const Color(0xFFFA2D48)),
          home: Scaffold(
            body: AnimatedLyrics(
              rawLyrics: regionalLrc,
              positionStream: positionController.stream,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Mode toggle bar buttons should be present for Indic lyrics
      expect(find.text('Original'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);
      expect(find.text('Dual'), findsOneWidget);

      // Default mode is Original: Telugu text is visible
      expect(find.text('సమాజవరగమనా'), findsOneWidget);

      // Switch to English Pronunciation mode
      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();

      // English transliterated pronunciation should now be displayed
      expect(find.textContaining('Sama'), findsOneWidget);

      // Switch to Dual mode
      await tester.tap(find.text('Dual'));
      await tester.pumpAndSettle();

      // In Dual mode, both original native text and transliterated pronunciation should be visible
      expect(find.text('సమాజవరగమనా'), findsOneWidget);
      expect(find.textContaining('Sama'), findsOneWidget);

      await positionController.close();
    },
  );

  testWidgets(
    'AnimatedLyrics places Romanized Telugu lyrics in English pronunciation slot and supports modes',
    (WidgetTester tester) async {
      const romanizedLrc = '''
[00:02.00]Rajamandri raagamajari
[00:05.00]Mayamma peru
''';

      final positionController = StreamController<Duration>.broadcast();

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(primaryColor: const Color(0xFFFA2D48)),
          home: Scaffold(
            body: AnimatedLyrics(
              rawLyrics: romanizedLrc,
              songLanguage: 'telugu',
              positionStream: positionController.stream,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Mode toggle bar buttons should be present for Romanized Telugu lyrics
      expect(find.text('Original'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);
      expect(find.text('Dual'), findsOneWidget);

      // English mode is active by default for Romanized Indic songs, showing the English pronunciation lyrics
      expect(find.text('Rajamandri raagamajari'), findsOneWidget);

      // Switch to Original mode: Native Telugu script should now be visible
      await tester.tap(find.text('Original'));
      await tester.pumpAndSettle();
      expect(find.text('Rajamandri raagamajari'), findsNothing);

      // Switch to Dual mode: Both Telugu script and English pronunciation should be visible
      await tester.tap(find.text('Dual'));
      await tester.pumpAndSettle();
      expect(find.text('Rajamandri raagamajari'), findsOneWidget);

      await positionController.close();
    },
  );

  testWidgets(
    'AnimatedLyrics preserves English lyrics without Telugu conversion or mode toggle',
    (WidgetTester tester) async {
      const englishLrc = '''
[00:02.00]I am in love with the shape of you
[00:05.00]We push and pull like a magnet do
''';

      final positionController = StreamController<Duration>.broadcast();

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(primaryColor: const Color(0xFFFA2D48)),
          home: Scaffold(
            body: AnimatedLyrics(
              rawLyrics: englishLrc,
              songLanguage: 'english',
              songTitle: 'Shape of You',
              songArtist: 'Ed Sheeran',
              positionStream: positionController.stream,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // English song should NOT show mode toggle buttons
      expect(find.text('Original'), findsNothing);
      expect(find.text('English'), findsNothing);
      expect(find.text('Dual'), findsNothing);

      // Lyrics should be rendered exactly as English text
      expect(find.text('I am in love with the shape of you'), findsOneWidget);
      expect(find.text('We push and pull like a magnet do'), findsOneWidget);

      await positionController.close();
    },
  );

  testWidgets(
    'AnimatedLyrics does NOT transliterate Romanized Hindi lyrics into Telugu script',
    (WidgetTester tester) async {
      const hindiRomanizedLrc = '''
[00:02.00]Hum tere bin ab reh nahi sakte
[00:05.00]Tere bina kya wajood mera
''';

      final positionController = StreamController<Duration>.broadcast();

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(primaryColor: const Color(0xFFFA2D48)),
          home: Scaffold(
            body: AnimatedLyrics(
              rawLyrics: hindiRomanizedLrc,
              songLanguage: 'hindi',
              songTitle: 'Tum Hi Ho',
              songArtist: 'Arijit Singh',
              positionStream: positionController.stream,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Lyrics must stay in Romanized text and NOT be converted to Telugu script
      expect(find.text('Hum tere bin ab reh nahi sakte'), findsOneWidget);
      expect(find.text('Tere bina kya wajood mera'), findsOneWidget);

      await positionController.close();
    },
  );

  testWidgets(
    'AnimatedLyrics correctly handles Devanagari Hindi lyrics with transliteration',
    (WidgetTester tester) async {
      const hindiDevanagariLrc = '''
[00:02.00]हम तेरे बिन अब रह नहीं सकते
[00:05.00]तेरे बिना क्या वजूद मेरा
''';

      final positionController = StreamController<Duration>.broadcast();

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(primaryColor: const Color(0xFFFA2D48)),
          home: Scaffold(
            body: AnimatedLyrics(
              rawLyrics: hindiDevanagariLrc,
              songLanguage: 'hindi',
              songTitle: 'Tum Hi Ho',
              songArtist: 'Arijit Singh',
              positionStream: positionController.stream,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Native Indic toggle buttons must appear
      expect(find.text('Original'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);
      expect(find.text('Dual'), findsOneWidget);

      // Original mode shows Devanagari
      expect(find.text('हम तेरे बिन अब रह नहीं सकते'), findsOneWidget);

      // Switch to English mode
      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();

      // Transliterated Latin text should appear
      expect(find.textContaining('Ham Tere'), findsOneWidget);

      await positionController.close();
    },
  );
}

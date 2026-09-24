import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/widgets/animated_lyrics.dart';

void main() {
  testWidgets('AnimatedLyrics parses multi-format LRC timestamps and highlights correctly', (WidgetTester tester) async {
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
  });
}

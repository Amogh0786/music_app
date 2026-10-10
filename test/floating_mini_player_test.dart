import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:music_app/services/preferences_service.dart';
import 'package:music_app/services/music_service.dart';
import 'package:music_app/widgets/mini_player.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Video mockSong;
  late MusicService musicService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = PreferencesService();
    prefs.resetForTesting();
    await prefs.init();

    musicService = MusicService();

    mockSong = Video(
      VideoId('BddP6PYo2gs'),
      'Kesariya',
      'Pritam, Arijit Singh',
      ChannelId('UC0WP5P-fwGlLyO4yOE76T8g'),
      DateTime.now(),
      '',
      null,
      '',
      const Duration(minutes: 4, seconds: 28),
      ThumbnailSet('BddP6PYo2gs'),
      null,
      Engagement(1000000, null, null),
      true,
    );

    musicService.setPlaylistForTesting([mockSong], initialIndex: 0);
  });

  group('Floating Island MiniPlayer Tests', () {
    testWidgets('Renders track title, artist, and playback control buttons', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: MiniPlayer())),
      );
      await tester.pump();

      // Track metadata
      expect(find.text('Kesariya'), findsOneWidget);
      expect(find.text('Pritam, Arijit Singh'), findsOneWidget);

      // Playback buttons
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      expect(find.byIcon(Icons.skip_next_rounded), findsOneWidget);
      expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);

      // Verify progress bar container is built
      expect(find.byType(FractionallySizedBox), findsOneWidget);
    });

    testWidgets('Collapses when MiniPlayer.hide() is invoked', (tester) async {
      MiniPlayer.show();
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: MiniPlayer())),
      );
      await tester.pump();
      expect(find.byType(MiniPlayer), findsOneWidget);

      MiniPlayer.hide();
      await tester.pumpAndSettle();
      expect(MiniPlayer.isVisible.value, isFalse);
      expect(tester.getSize(find.byType(MiniPlayer)), equals(Size.zero));

      MiniPlayer.show();
      await tester.pumpAndSettle();
      expect(MiniPlayer.isVisible.value, isTrue);
    });
  });
}

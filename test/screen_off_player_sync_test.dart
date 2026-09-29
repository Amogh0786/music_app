import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/screens/player_screen.dart';
import 'package:music_app/services/music_service.dart';
import 'package:music_app/services/preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

Video makeVideo(String id, String title, String author) {
  return Video(
    VideoId(id),
    title,
    author,
    ChannelId('UC0WP5P-fwGlLyO4yOE76T8g'),
    DateTime.now(),
    '',
    null,
    '',
    const Duration(minutes: 3, seconds: 30),
    ThumbnailSet(id),
    null,
    Engagement(0, null, null),
    false,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PreferencesService().init();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('com.ryanheise.just_audio.methods'), (call) async {
      return {};
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/path_provider'), (call) async {
      return '.';
    });
  });

  group('Screen Off / Background Playback Sync Tests', () {
    testWidgets('PlayerScreen immediately syncs to current song on resume without replaying earlier songs',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final musicService = MusicService();
      final songs = [
        makeVideo('id_00000001', 'Song 1 - Pushpa Pushpa', 'Devi Sri Prasad'),
        makeVideo('id_00000002', 'Song 2 - Samajavaragamana', 'Sid Sriram'),
        makeVideo('id_00000003', 'Song 3 - Fear Song', 'Anirudh Ravichander'),
        makeVideo('id_00000004', 'Song 4 - Kesariya', 'Arijit Singh'),
      ];

      // 1. User starts listening from Song 1
      musicService.setPlaylistForTesting(songs, initialIndex: 0);
      expect(musicService.currentIndex, equals(0));
      expect(musicService.currentSong?.title, equals('Song 1 - Pushpa Pushpa'));

      // 2. User opens the PlayerScreen while on Song 1
      await tester.pumpWidget(
        const MaterialApp(
          home: PlayerScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Song 1 - Pushpa Pushpa'), findsWidgets);

      // 3. User turns off their screen (app lifecycle becomes paused)
      TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();

      // 4. In the background, audio advances: Song 1 finishes, Song 2 plays, then Song 3 plays
      // (advance to Song 3, index 2)
      musicService.setPlaylistForTesting(songs, initialIndex: 2);
      musicService.notifyListeners();
      await tester.pump();

      expect(musicService.currentIndex, equals(2));
      expect(musicService.currentSong?.title, equals('Song 3 - Fear Song'));

      // 5. User turns the screen back on (app lifecycle becomes resumed)
      TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 6. Verify PlayerScreen immediately shows Song 3, and did NOT switch back to Song 2!
      expect(musicService.currentIndex, equals(2));
      expect(musicService.currentSong?.title, equals('Song 3 - Fear Song'));
      expect(find.text('Song 3 - Fear Song'), findsWidgets);
      expect(find.text('Song 2 - Samajavaragamana'), findsNothing);
    });
  });
}

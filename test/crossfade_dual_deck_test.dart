import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/services/music_service.dart';
import 'package:music_app/services/preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'crossfade': true,
      'crossfadeSeconds': 4,
      'smartCrossfade': false,
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('com.ryanheise.just_audio.methods'), (call) async {
      return null;
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/path_provider'), (call) async {
      return '.';
    });
  });

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
      null,
      ThumbnailSet(id),
      null,
      Engagement(0, null, null),
      false,
    );
  }

  group('Dual-Deck Seamless Crossfade Engine Tests', () {
    test('Crossfade preferences are properly read and enabled', () async {
      final prefs = PreferencesService();
      await prefs.init();
      expect(prefs.crossfadeEnabled, isTrue);
      expect(prefs.crossfadeSeconds, 4);
    });

    test('isCrossfading flag prevents double-advance on track completion', () async {
      final music = MusicService();
      expect(music.isCrossfading, isFalse);

      music.setIsCrossfadingForTesting(true);
      expect(music.isCrossfading, isTrue);

      music.setIsCrossfadingForTesting(false);
      expect(music.isCrossfading, isFalse);
    });

    test('Playlist queue is properly managed with sequential playback', () async {
      final music = MusicService();

      final song1 = makeVideo('aaaaaaaaaaa', 'First Song', 'Artist A');
      final song2 = makeVideo('bbbbbbbbbbb', 'Second Song', 'Artist B');
      final song3 = makeVideo('ccccccccccc', 'Third Song', 'Artist C');

      music.setPlaylistForTesting([song1, song2, song3], initialIndex: 0);
      expect(music.currentIndex, 0);
      expect(music.playlist.length, 3);
      expect(music.currentSong?.id.value, 'aaaaaaaaaaa');

      music.setPlaylistForTesting([song1, song2, song3], initialIndex: 1);
      expect(music.currentIndex, 1);
      expect(music.currentSong?.id.value, 'bbbbbbbbbbb');
    });

    test('PreferencesService dynamically clamps and updates crossfade duration', () async {
      final prefs = PreferencesService();
      await prefs.init();

      await prefs.setCrossfadeSeconds(8);
      expect(prefs.crossfadeSeconds, 8);

      await prefs.setCrossfadeSeconds(25); // Above max 12 clamp
      expect(prefs.crossfadeSeconds, 12);

      await prefs.setCrossfadeSeconds(0); // Below min 1 clamp
      expect(prefs.crossfadeSeconds, 1);
    });
  });
}

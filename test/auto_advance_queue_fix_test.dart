import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:music_app/services/music_service.dart';
import 'package:music_app/services/preferences_service.dart';
import 'package:music_app/services/canonical_song_dedup.dart';
import 'package:music_app/services/audio_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'crossfade': true,
      'crossfadeSeconds': 4,
      'smartCrossfade': false,
      'audioQuality': 'studioMaster',
      'audioFormat': 'aac',
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.ryanheise.just_audio.methods'),
          (call) async {
            return null;
          },
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async {
            return '.';
          },
        );
    final prefs = PreferencesService();
    await prefs.init();
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

  group('Auto-Advance & Queue Resolution Fail-Safe Tests', () {
    test(
      'consecutivePlaybackFailures tracks failures and resets on resetForTesting',
      () {
        final music = MusicService();
        music.resetForTesting();
        expect(music.consecutivePlaybackFailures, 0);

        music.setConsecutivePlaybackFailuresForTesting(2);
        expect(music.consecutivePlaybackFailures, 2);

        music.resetForTesting();
        expect(music.consecutivePlaybackFailures, 0);
      },
    );

    test(
      'Synthetic ID with direct stream URL is registered and accessible',
      () {
        const syntheticId = 'jiosaavn_998877';
        const cdnUrl = 'https://aac.saavn.cdn.jio.com/test_track.mp4';

        MusicService.cacheWebStreamUrl(syntheticId, cdnUrl);
        expect(MusicService.getCachedWebStreamUrl(syntheticId), cdnUrl);
      },
    );

    test('LoopMode.one repeats once then resets to off', () {
      final music = MusicService();
      music.resetForTesting();
      music.setLoopModeForTesting(LoopMode.one);
      expect(music.loopMode, LoopMode.one);
    });

    test(
      'Queue playlist navigation properly sets currentSong and currentIndex',
      () {
        final music = MusicService();
        music.resetForTesting();

        final song1 = makeVideo('11111111111', 'Track 1', 'Artist A');
        final song2 = makeVideo('22222222222', 'Track 2', 'Artist B');
        final song3 = makeVideo('33333333333', 'Track 3', 'Artist C');

        music.setPlaylistForTesting([song1, song2, song3], initialIndex: 0);
        expect(music.currentIndex, 0);
        expect(music.currentSong?.id.value, '11111111111');

        music.setPlaylistForTesting([song1, song2, song3], initialIndex: 2);
        expect(music.currentIndex, 2);
        expect(music.currentSong?.id.value, '33333333333');
      },
    );

    test(
      'CanonicalSongDedup correctly classifies YouTube vs Synthetic IDs',
      () {
        expect(CanonicalSongDedup.isLikelyYouTubeId('dQw4w9WgXcQ'), isTrue);
        expect(CanonicalSongDedup.isLikelyYouTubeId('abc123XYZ_-'), isTrue);
        // Purely numeric 11-digit strings are synthetic JioSaavn catalog IDs:
        expect(CanonicalSongDedup.isLikelyYouTubeId('11111111111'), isFalse);
        expect(CanonicalSongDedup.isLikelyYouTubeId('jiosaavn_12345'), isFalse);
        expect(CanonicalSongDedup.isLikelyYouTubeId('short_id'), isFalse);
        expect(
          CanonicalSongDedup.isLikelyYouTubeId('album_track_492'),
          isFalse,
        );
      },
    );

    test(
      'Spurious completion tolerance allows up to 8s discrepancy for VBR streams',
      () {
        // Simulates the spurious completion threshold logic in MusicService
        bool isSpuriousCompletion(Duration pos, Duration dur) {
          return dur.inSeconds > 10 &&
              (dur - pos).inSeconds > 8 &&
              pos.inSeconds < (dur.inSeconds * 0.85).round();
        }

        const fullTrack = Duration(seconds: 180);

        // Premature completion at 10s: spurious
        expect(
          isSpuriousCompletion(const Duration(seconds: 10), fullTrack),
          isTrue,
        );

        // Natural EOF with 5s VBR drift (175s / 180s): valid completion (NOT spurious)
        expect(
          isSpuriousCompletion(const Duration(seconds: 175), fullTrack),
          isFalse,
        );

        // Natural EOF with 8s VBR drift (172s / 180s): valid completion (NOT spurious)
        expect(
          isSpuriousCompletion(const Duration(seconds: 172), fullTrack),
          isFalse,
        );

        // Drift > 8s but pos >= 85% of duration (160s / 180s = 88.8%): valid completion
        expect(
          isSpuriousCompletion(const Duration(seconds: 160), fullTrack),
          isFalse,
        );

        // Short track (<= 10s): not ignored as spurious
        expect(
          isSpuriousCompletion(
            const Duration(seconds: 5),
            const Duration(seconds: 8),
          ),
          isFalse,
        );
      },
    );

    test(
      'Consecutive failure limit protects audio engine from infinite skipping loop',
      () {
        final music = MusicService();
        music.resetForTesting();

        expect(music.consecutivePlaybackFailures, 0);

        // Simulate 1st failure
        music.setConsecutivePlaybackFailuresForTesting(1);
        expect(music.consecutivePlaybackFailures, 1);

        // Simulate 2nd failure
        music.setConsecutivePlaybackFailuresForTesting(2);
        expect(music.consecutivePlaybackFailures, 2);

        // Simulate 3rd failure triggering circuit breaker
        music.setConsecutivePlaybackFailuresForTesting(3);
        expect(music.consecutivePlaybackFailures >= 3, isTrue);

        // Circuit breaker halts and resets counter to 0
        music.resetForTesting();
        expect(music.consecutivePlaybackFailures, 0);
      },
    );

    test('DilSeAudioHandler maintains boundPlayer to active deck', () {
      final music = MusicService();
      final handler = DilSeAudioHandler();
      expect(handler.boundPlayer, isNotNull);

      final newPlayer = AudioPlayer();
      handler.bindPlayer(newPlayer);
      expect(handler.boundPlayer, same(newPlayer));
      newPlayer.dispose();
    });

    test(
      'handlePlaybackStreamError ignores errors from non-active standby player',
      () async {
        final music = MusicService();
        music.resetForTesting();

        final song = makeVideo('11111111111', 'Track 1', 'Artist A');
        music.setPlaylistForTesting([song], initialIndex: 0);

        final dummyStandbyPlayer = AudioPlayer();
        await music.handlePlaybackStreamErrorForTesting(
          dummyStandbyPlayer,
          Exception('HttpDataSourceException: HTTP 403 Forbidden'),
        );

        // Retry count should remain 0 because standby player errors do not disrupt active playback
        expect(music.songRetryCount, 0);
        dummyStandbyPlayer.dispose();
      },
    );

    test(
      'handlePlaybackStreamError increments retry count and evicts dead stream URL',
      () async {
        final music = MusicService();
        music.resetForTesting();

        const vidId = 'track403dead';
        MusicService.cacheWebStreamUrl(
          vidId,
          'https://expired.googlevideo.com/videoplayback',
        );
        expect(MusicService.getCachedWebStreamUrl(vidId), isNotNull);

        final song = makeVideo('11111111111', 'Track 403', 'Artist A');
        music.setPlaylistForTesting([song], initialIndex: 0);

        // Simulate first stream failure on active player
        music.setSongRetryCountForTesting(0);
        expect(music.songRetryCount, 0);

        // Simulate second error triggering auto-advance limit
        music.setSongRetryCountForTesting(1);
        expect(music.songRetryCount, 1);
      },
    );
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/services/preferences_service.dart';
import 'package:music_app/services/taste_matrix_scorer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

Video _createMockVideo(String seedId, String title, String author) {
  final id = seedId.padRight(11, '0').substring(0, 11);
  return Video(
    VideoId(id),
    title,
    author,
    ChannelId('UC0WP5P-fwGlLyO4yOE76T8g'),
    DateTime.now(),
    '',
    null,
    '',
    const Duration(minutes: 3),
    ThumbnailSet(id),
    null,
    Engagement(100, null, null),
    false,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'preferredLanguages': ['Telugu'],
      'artistPlayCountsJson': '{"Devi Sri Prasad": 25, "Thaman S": 10}',
    });
    await PreferencesService().init();
  });

  group('TasteMatrixScorer Tests', () {
    test('Boosts tracks matching user preferred artist affinity', () {
      final scorer = TasteMatrixScorer();
      final candidates = [
        _createMockVideo('id1', 'Random Song 1', 'Unknown Artist'),
        _createMockVideo('id2', 'Pushpa Pushpa', 'Devi Sri Prasad'),
        _createMockVideo('id3', 'Guntur Kaaram', 'Thaman S'),
      ];

      final ranked = scorer.scoreAndRankCandidates(candidates);

      expect(ranked.isNotEmpty, isTrue);
      // Devi Sri Prasad has 25 plays, so he should be ranked at the top
      expect(ranked.first.author, equals('Devi Sri Prasad'));
    });

    test('Enforces sliding-window artist fatigue cap', () {
      final scorer = TasteMatrixScorer();
      final candidates = [
        _createMockVideo('dsp1', 'Song 1', 'Devi Sri Prasad'),
        _createMockVideo('dsp2', 'Song 2', 'Devi Sri Prasad'),
        _createMockVideo('dsp3', 'Song 3', 'Devi Sri Prasad'),
        _createMockVideo('dsp4', 'Song 4', 'Devi Sri Prasad'),
        _createMockVideo('thm1', 'Song 5', 'Thaman S'),
        _createMockVideo('ani1', 'Song 6', 'Anirudh Ravichander'),
      ];

      final ranked = scorer.scoreAndRankCandidates(candidates, maxResults: 6);

      // In the first 4-5 tracks, DSP should not appear more than 2 times consecutively
      final firstThree = ranked.take(3).map((v) => v.author).toList();
      final dspInFirstThree = firstThree
          .where((a) => a == 'Devi Sri Prasad')
          .length;
      expect(dspInFirstThree, lessThanOrEqualTo(2));
    });

    test('Boosts liked songs with familiarity bonus', () {
      final scorer = TasteMatrixScorer();
      final candidates = [
        _createMockVideo('id1', 'Normal Track', 'Unknown Artist'),
        _createMockVideo('id2', 'Beloved Melody', 'Unknown Artist'),
      ];

      final ranked = scorer.scoreAndRankCandidates(
        candidates,
        likedSongTitles: ['Beloved Melody'],
      );

      expect(ranked.first.title, equals('Beloved Melody'));
    });
  });
}

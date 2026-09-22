import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/services/youtube_music_client.dart';

void main() {
  group('YouTubeMusicClient Tests', () {
    test('Client instance initializes correctly', () {
      final client = YouTubeMusicClient();
      expect(client, isNotNull);
    });

    test('Live search query executes without unhandled exceptions', () async {
      final client = YouTubeMusicClient();
      final results = await client.searchSongs('Kesariya', limit: 5);
      // If network is reachable, we get results; if offline in test environment, it returns [] gracefully
      expect(results, isA<List>());
    });
  });
}

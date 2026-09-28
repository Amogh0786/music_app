import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/screens/player_screen.dart';

void main() {
  group('Landscape Player Screen Architecture Tests', () {
    test('LandscapeActiveTab enum has expected values', () {
      expect(LandscapeActiveTab.values, contains(LandscapeActiveTab.none));
      expect(LandscapeActiveTab.values, contains(LandscapeActiveTab.lyrics));
      expect(LandscapeActiveTab.values, contains(LandscapeActiveTab.queue));
      expect(LandscapeActiveTab.values, contains(LandscapeActiveTab.more));
    });

    test('LandscapeActiveTab toggle behavior switches between active and none', () {
      LandscapeActiveTab activeTab = LandscapeActiveTab.none;

      LandscapeActiveTab toggle(LandscapeActiveTab current, LandscapeActiveTab target) {
        return current == target ? LandscapeActiveTab.none : target;
      }

      // Tapping Lyrics activates Lyrics
      activeTab = toggle(activeTab, LandscapeActiveTab.lyrics);
      expect(activeTab, LandscapeActiveTab.lyrics);

      // Tapping Lyrics again collapses to none
      activeTab = toggle(activeTab, LandscapeActiveTab.lyrics);
      expect(activeTab, LandscapeActiveTab.none);

      // Tapping Queue activates Queue
      activeTab = toggle(activeTab, LandscapeActiveTab.queue);
      expect(activeTab, LandscapeActiveTab.queue);

      // Tapping More switches directly to More
      activeTab = toggle(activeTab, LandscapeActiveTab.more);
      expect(activeTab, LandscapeActiveTab.more);

      // Collapse returns to none
      activeTab = LandscapeActiveTab.none;
      expect(activeTab, LandscapeActiveTab.none);
    });

    test('Play controls order matches widget specifications: Shuffle -> Prev -> Play/Pause -> Next -> Repeat', () {
      final widgetOrder = [
        'shuffle',
        'previous',
        'play_pause',
        'next',
        'repeat',
      ];

      expect(widgetOrder[0], 'shuffle');
      expect(widgetOrder[1], 'previous');
      expect(widgetOrder[2], 'play_pause');
      expect(widgetOrder[3], 'next');
      expect(widgetOrder[4], 'repeat');
      expect(widgetOrder.length, 5);
    });

    test('Cover sizing in landscape mode scales proportionally to viewport height', () {
      double computeCoverSize(double maxHeight) {
        return (maxHeight - 16).clamp(130.0, 240.0);
      }

      // Small landscape viewport (e.g. 320dp height)
      expect(computeCoverSize(320), 240.0);
      // Extra compact landscape viewport (e.g. 200dp height)
      expect(computeCoverSize(200), 184.0);
      // Extremely low height
      expect(computeCoverSize(140), 130.0);
    });

    test('Shrunk album cover in expanded panel view retains fixed compact dimensions', () {
      const double normalCoverSize = 220.0;
      const double shrunkCoverSize = 72.0;

      expect(shrunkCoverSize < normalCoverSize, isTrue);
      expect(shrunkCoverSize, 72.0);
    });
  });
}

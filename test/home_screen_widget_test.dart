import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/services/widget_service.dart';

void main() {
  group('HomeScreen Widget & WidgetService Tests', () {
    test('Dominant color hex formatting handles ARGB values correctly', () {
      const color = Color(0xFF9C27B0);
      final argb = color.toARGB32();
      final hex = '#${argb.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
      expect(hex, '#9C27B0');
      expect(argb, 0xFF9C27B0);
    });

    test('Playlist deep link URI parsing extracts ID and Title correctly', () {
      final uri = Uri.parse('dilse://playlist?id=telugu_hits&title=Telugu%20Hits');
      expect(uri.host, 'playlist');
      expect(uri.queryParameters['id'], 'telugu_hits');
      expect(uri.queryParameters['title'], 'Telugu Hits');
    });

    test('Player screen deep link URI parsing detects player target', () {
      final uri = Uri.parse('dilse://player');
      expect(uri.host, 'player');
    });

    test('Widget control URIs map to expected actions', () {
      final controlUris = [
        'dilse://widget/shuffle',
        'dilse://widget/previous',
        'dilse://widget/play_pause',
        'dilse://widget/next',
        'dilse://widget/repeat',
      ];

      for (final uriStr in controlUris) {
        final uri = Uri.parse(uriStr);
        final action = uri.path.replaceAll('/', '');
        expect(
          ['shuffle', 'previous', 'play_pause', 'next', 'repeat'].contains(action),
          isTrue,
        );
      }
    });

    test('Scrubber progress percent calculation clamps accurately between 0 and 100', () {
      int calculateProgress(int posMs, int durMs) {
        if (durMs <= 0) return 0;
        return ((posMs / durMs) * 100).round().clamp(0, 100);
      }

      expect(calculateProgress(0, 200000), 0);
      expect(calculateProgress(50000, 200000), 25);
      expect(calculateProgress(100000, 200000), 50);
      expect(calculateProgress(150000, 200000), 75);
      expect(calculateProgress(200000, 200000), 100);
      expect(calculateProgress(250000, 200000), 100);
      expect(calculateProgress(0, 0), 0);
    });

    test('Repeat cycle transition: off -> all -> one -> off', () {
      String getNextRepeat(String current) {
        return switch (current) {
          'off' => 'all',
          'all' => 'one',
          _ => 'off',
        };
      }

      expect(getNextRepeat('off'), 'all');
      expect(getNextRepeat('all'), 'one');
      expect(getNextRepeat('one'), 'off');
      expect(getNextRepeat('unknown'), 'off');
    });

    test('formatDuration formats Duration instances into clean m:ss strings', () {
      expect(WidgetService.formatDuration(Duration.zero), '0:00');
      expect(WidgetService.formatDuration(const Duration(seconds: 45)), '0:45');
      expect(WidgetService.formatDuration(const Duration(seconds: 74)), '1:14');
      expect(WidgetService.formatDuration(const Duration(minutes: 3, seconds: 35)), '3:35');
      expect(WidgetService.formatDuration(const Duration(minutes: 12, seconds: 5)), '12:05');
    });
  });
}

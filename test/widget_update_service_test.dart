import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/services/widget_update_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WidgetUpdateService Unit Tests', () {
    late List<MethodCall> channelCalls;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      channelCalls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(WidgetUpdateService.channel, (call) async {
            channelCalls.add(call);
            return true;
          });
      WidgetUpdateService().resetForTesting();
    });

    test(
      'updateWidget saves playback state to SharedPreferences and invokes native channel',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;

        final service = WidgetUpdateService();
        await service.updateWidget(
          title: 'Naatu Naatu',
          artist: 'MM Keeravaani',
          isPlaying: true,
          artworkPath: '/data/user/0/com.example.music_app/cache/artwork.jpg',
          trackId: 'track_123',
        );

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('widget_title'), equals('Naatu Naatu'));
        expect(prefs.getString('widget_artist'), equals('MM Keeravaani'));
        expect(prefs.getBool('widget_is_playing'), isTrue);
        expect(
          prefs.getString('widget_artwork_path'),
          equals('/data/user/0/com.example.music_app/cache/artwork.jpg'),
        );
        expect(channelCalls.length, equals(1));
        expect(channelCalls.first.method, equals('updateWidget'));

        debugDefaultTargetPlatformOverride = null;
      },
    );

    test(
      'updateWidget deduplicates successive identical updates to prevent battery drain',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;

        final service = WidgetUpdateService();
        await service.updateWidget(
          title: 'Same Song',
          artist: 'Same Artist',
          isPlaying: true,
          trackId: 'same_id',
        );
        expect(channelCalls.length, equals(1));

        // Duplicate invocation with identical state
        await service.updateWidget(
          title: 'Same Song',
          artist: 'Same Artist',
          isPlaying: true,
          trackId: 'same_id',
        );
        // Must not invoke channel again
        expect(channelCalls.length, equals(1));

        // State changes (paused)
        await service.updateWidget(
          title: 'Same Song',
          artist: 'Same Artist',
          isPlaying: false,
          trackId: 'same_id',
        );
        expect(channelCalls.length, equals(2));

        debugDefaultTargetPlatformOverride = null;
      },
    );
  });
}

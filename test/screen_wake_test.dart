import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/services/screen_wake_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<bool> platformCalls;

  setUp(() {
    ScreenWakeService.resetForTesting();
    platformCalls = [];
    ScreenWakeService.platformHandlerOverride = (bool enable) async {
      platformCalls.add(enable);
    };
  });

  tearDown(() {
    ScreenWakeService.resetForTesting();
  });

  group('ScreenWakeService Tests', () {
    test('Initial state has no active holders and wakelock is inactive', () {
      expect(ScreenWakeService.isWakeLockActive, isFalse);
      expect(ScreenWakeService.activeHoldersCount, 0);
      expect(platformCalls, isEmpty);
    });

    test('enableWakeLock enables lock and registers holder tag', () async {
      await ScreenWakeService.enableWakeLock('lyrics_screen');
      expect(ScreenWakeService.isWakeLockActive, isTrue);
      expect(ScreenWakeService.activeHoldersCount, 1);
      expect(platformCalls, [true]);
    });

    test('Multiple holders are reference counted properly', () async {
      await ScreenWakeService.enableWakeLock('lyrics_screen');
      await ScreenWakeService.enableWakeLock('animated_lyrics');
      expect(ScreenWakeService.isWakeLockActive, isTrue);
      expect(ScreenWakeService.activeHoldersCount, 2);
      // Platform enable was only called once because lock was already on
      expect(platformCalls, [true]);

      // Releasing one holder should keep wakelock active because animated_lyrics is still active
      await ScreenWakeService.disableWakeLock('lyrics_screen');
      expect(ScreenWakeService.isWakeLockActive, isTrue);
      expect(ScreenWakeService.activeHoldersCount, 1);
      expect(platformCalls, [true]);

      // Releasing last holder releases the lock completely
      await ScreenWakeService.disableWakeLock('animated_lyrics');
      expect(ScreenWakeService.isWakeLockActive, isFalse);
      expect(ScreenWakeService.activeHoldersCount, 0);
      expect(platformCalls, [true, false]);
    });

    test('forceDisableAll clears all holders and deactivates lock', () async {
      await ScreenWakeService.enableWakeLock('tag1');
      await ScreenWakeService.enableWakeLock('tag2');
      await ScreenWakeService.enableWakeLock('tag3');
      expect(ScreenWakeService.activeHoldersCount, 3);
      expect(ScreenWakeService.isWakeLockActive, isTrue);
      expect(platformCalls, [true]);

      await ScreenWakeService.forceDisableAll();
      expect(ScreenWakeService.activeHoldersCount, 0);
      expect(ScreenWakeService.isWakeLockActive, isFalse);
      expect(platformCalls, [true, false]);
    });

    test('Disabling a non-held tag does not crash or corrupt state', () async {
      await ScreenWakeService.disableWakeLock('non_existent_tag');
      expect(ScreenWakeService.isWakeLockActive, isFalse);
      expect(ScreenWakeService.activeHoldersCount, 0);
      expect(platformCalls, isEmpty);
    });

    test('Lifecycle state changes handle background pause and resume gracefully', () async {
      final service = ScreenWakeService();

      await ScreenWakeService.enableWakeLock('lyrics');
      expect(ScreenWakeService.isWakeLockActive, isTrue);
      expect(platformCalls, [true]);

      // Simulate app sent to background -> wakelock is paused (platform toggle false)
      service.didChangeAppLifecycleState(AppLifecycleState.paused);
      expect(platformCalls, [true, false]);

      // Simulate app resumed -> wakelock is restored (platform toggle true)
      service.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(platformCalls, [true, false, true]);

      // Wakelock should still be recorded as active
      expect(ScreenWakeService.isWakeLockActive, isTrue);

      await ScreenWakeService.disableWakeLock('lyrics');
      expect(ScreenWakeService.isWakeLockActive, isFalse);
      expect(platformCalls, [true, false, true, false]);
    });
  });
}

import 'package:flutter/widgets.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Industrial-grade Screen Wake Management Service for DilSe.
///
/// Keeps the phone display awake while reading or singing along with lyrics,
/// exactly like a video player, and safely restores normal system sleep settings
/// as soon as lyrics are closed.
class ScreenWakeService with WidgetsBindingObserver {
  ScreenWakeService._() {
    WidgetsBinding.instance.addObserver(this);
  }

  static final ScreenWakeService _instance = ScreenWakeService._();
  factory ScreenWakeService() => _instance;

  static final Set<String> _activeHolders = {};
  static bool _isScreenKeptOn = false;

  /// Optional platform handler override for unit tests or custom platforms
  @visibleForTesting
  static Future<void> Function(bool enable)? platformHandlerOverride;

  /// Check whether the screen wake lock is currently active
  static bool get isWakeLockActive => _isScreenKeptOn;

  /// Number of active components currently requesting wake lock
  static int get activeHoldersCount => _activeHolders.length;

  static Future<void> _setScreenOn(bool on) async {
    try {
      if (platformHandlerOverride != null) {
        await platformHandlerOverride!(on);
      } else {
        if (on) {
          await WakelockPlus.enable();
        } else {
          await WakelockPlus.disable();
        }
      }
    } catch (e) {
      debugPrint('[ScreenWakeService] Platform toggle error ($on): $e');
    }
  }

  /// Request the screen to stay awake for a specific feature tag (e.g. 'lyrics_screen', 'animated_lyrics')
  static Future<void> enableWakeLock(String tag) async {
    _activeHolders.add(tag);
    if (!_isScreenKeptOn) {
      _isScreenKeptOn = true;
      await _setScreenOn(true);
      debugPrint('[ScreenWakeService] WakeLock enabled by: $tag (holders: ${_activeHolders.length})');
    }
  }

  /// Release the wake lock for a specific feature tag.
  /// If no other components require the screen on, returns to normal system display timeout.
  static Future<void> disableWakeLock(String tag) async {
    _activeHolders.remove(tag);
    if (_activeHolders.isEmpty && _isScreenKeptOn) {
      _isScreenKeptOn = false;
      await _setScreenOn(false);
      debugPrint('[ScreenWakeService] WakeLock disabled (released by $tag)');
    }
  }

  /// Force release all wake locks immediately (e.g. on player exit or user preference toggle)
  static Future<void> forceDisableAll() async {
    _activeHolders.clear();
    if (_isScreenKeptOn) {
      _isScreenKeptOn = false;
      await _setScreenOn(false);
      debugPrint('[ScreenWakeService] WakeLock force disabled');
    }
  }

  /// Automatically pause wakelock when app goes to background to preserve battery,
  /// and resume when app returns to foreground if lyrics are still active.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      if (_isScreenKeptOn) {
        _setScreenOn(false);
        debugPrint('[ScreenWakeService] App backgrounded -> WakeLock paused');
      }
    } else if (state == AppLifecycleState.resumed) {
      if (_activeHolders.isNotEmpty) {
        _setScreenOn(true);
        debugPrint('[ScreenWakeService] App resumed -> WakeLock restored for: $_activeHolders');
      }
    }
  }

  /// Reset internal state for isolated unit testing
  @visibleForTesting
  static void resetForTesting() {
    _activeHolders.clear();
    _isScreenKeptOn = false;
    platformHandlerOverride = null;
  }
}

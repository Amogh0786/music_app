import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight, battery-friendly service for synchronizing active playback metadata
/// to the native Android Home Screen Widget via MethodChannel and SharedPreferences.
///
/// Strict architectural constraints:
/// - 0 continuous timers / periodic polling.
/// - Event-driven invocations on track change and play/pause toggle only.
/// - Android-only execution guard with web and iOS fallbacks.
class WidgetUpdateService {
  static final WidgetUpdateService _instance = WidgetUpdateService._internal();
  factory WidgetUpdateService() => _instance;
  WidgetUpdateService._internal();

  static const MethodChannel _channel = MethodChannel(
    'com.example.music_app/widget',
  );

  String? _lastTrackId;
  bool? _lastIsPlaying;

  @visibleForTesting
  static MethodChannel get channel => _channel;

  Future<void> updateWidget({
    required String title,
    required String artist,
    required bool isPlaying,
    String? artworkPath,
    String? trackId,
  }) async {
    if (kIsWeb) return;
    if (defaultTargetPlatform != TargetPlatform.android) return;

    // Deduplicate redundant updates
    if (_lastTrackId == trackId && _lastIsPlaying == isPlaying) {
      return;
    }
    _lastTrackId = trackId;
    _lastIsPlaying = isPlaying;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('widget_title', title);
      await prefs.setString('widget_artist', artist);
      await prefs.setBool('widget_is_playing', isPlaying);
      if (artworkPath != null && artworkPath.isNotEmpty) {
        await prefs.setString('widget_artwork_path', artworkPath);
      }

      await _channel.invokeMethod('updateWidget');
    } catch (e) {
      debugPrint('[WidgetUpdateService] Error updating widget: $e');
    }
  }

  @visibleForTesting
  void resetForTesting() {
    _lastTrackId = null;
    _lastIsPlaying = null;
  }
}

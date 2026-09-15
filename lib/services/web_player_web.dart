import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:web/web.dart' as web;

/// Modern Web implementation for Flutter Web using dart:js_interop & package:web.
/// Controls the invisible YouTube IFrame player and Web MediaSession API.
class WebPlayerBridge {
  static bool get isSupported => true;
  static bool _isPlaying = false;
  static Duration _currentPosition = Duration.zero;
  static Duration _currentDuration = Duration.zero;

  static final StreamController<Duration> _positionController =
      StreamController<Duration>.broadcast();
  static final StreamController<Duration> _durationController =
      StreamController<Duration>.broadcast();
  static final StreamController<String> _stateController =
      StreamController<String>.broadcast();
  static final StreamController<void> _endedController =
      StreamController<void>.broadcast();
  static final StreamController<void> _nextController =
      StreamController<void>.broadcast();
  static final StreamController<void> _prevController =
      StreamController<void>.broadcast();

  static bool get isPlaying => _isPlaying;
  static Duration get currentPosition => _currentPosition;
  static Duration get currentDuration => _currentDuration;

  static Stream<Duration> get positionStream => _positionController.stream;
  static Stream<Duration> get durationStream => _durationController.stream;
  static Stream<String> get stateStream => _stateController.stream;
  static Stream<void> get onTrackEnded => _endedController.stream;
  static Stream<void> get onNext => _nextController.stream;
  static Stream<void> get onPrevious => _prevController.stream;

  static bool _initialized = false;

  static void init() {
    if (_initialized) return;
    _initialized = true;

    web.window.addEventListener(
      'dilse_time_update',
      (web.Event event) {
        try {
          final customEvent = event as web.CustomEvent;
          final detail = customEvent.detail;
          if (detail != null) {
            final jsObj = detail as JSObject;
            final posVal = jsObj.getProperty('position'.toJS);
            final durVal = jsObj.getProperty('duration'.toJS);
            final pos = (posVal as JSNumber?)?.toDartDouble ?? 0.0;
            final dur = (durVal as JSNumber?)?.toDartDouble ?? 0.0;
            _currentPosition = Duration(milliseconds: (pos * 1000).toInt());
            _currentDuration = Duration(milliseconds: (dur * 1000).toInt());
            _positionController.add(_currentPosition);
            _durationController.add(_currentDuration);
          }
        } catch (_) {}
      }.toJS,
    );

    web.window.addEventListener(
      'dilse_state_change',
      (web.Event event) {
        try {
          final customEvent = event as web.CustomEvent;
          final detail = customEvent.detail;
          if (detail != null) {
            final jsObj = detail as JSObject;
            final stateVal = jsObj.getProperty('state'.toJS);
            final state = (stateVal as JSString?)?.toDart ?? 'unknown';
            if (state == 'playing') {
              _isPlaying = true;
            } else if (state == 'paused' || state == 'ended' || state == 'idle') {
              _isPlaying = false;
            }
            _stateController.add(state);
          }
        } catch (_) {}
      }.toJS,
    );

    web.window.addEventListener(
      'dilse_ended',
      ((web.Event _) {
        _isPlaying = false;
        _endedController.add(null);
      }).toJS,
    );

    web.window.addEventListener(
      'dilse_remote_next',
      ((web.Event _) {
        _nextController.add(null);
      }).toJS,
    );

    web.window.addEventListener(
      'dilse_remote_prev',
      ((web.Event _) {
        _prevController.add(null);
      }).toJS,
    );

    web.window.addEventListener(
      'dilse_remote_play',
      ((web.Event _) {
        _isPlaying = true;
        _stateController.add('playing');
      }).toJS,
    );

    web.window.addEventListener(
      'dilse_remote_pause',
      ((web.Event _) {
        _isPlaying = false;
        _stateController.add('paused');
      }).toJS,
    );
  }

  static void play(
    String videoId, {
    String? title,
    String? artist,
    String? artworkUrl,
    double startSeconds = 0,
  }) {
    init();
    _isPlaying = true;
    _stateController.add('buffering');

    final globalWindow = web.window as JSObject;

    // Update MediaSession
    if (globalWindow.hasProperty('dilseSetMetadata'.toJS).toDart) {
      globalWindow.callMethod(
        'dilseSetMetadata'.toJS,
        (title ?? 'DilSe Song').toJS,
        (artist ?? 'DilSe Music').toJS,
        (artworkUrl ?? '').toJS,
      );
    }

    if (globalWindow.hasProperty('dilsePlay'.toJS).toDart) {
      globalWindow.callMethod(
        'dilsePlay'.toJS,
        videoId.toJS,
        startSeconds.toJS,
      );
    }
  }

  static void pause() {
    _isPlaying = false;
    _stateController.add('paused');
    final globalWindow = web.window as JSObject;
    if (globalWindow.hasProperty('dilsePause'.toJS).toDart) {
      globalWindow.callMethod('dilsePause'.toJS);
    }
  }

  static void resume() {
    _isPlaying = true;
    _stateController.add('playing');
    final globalWindow = web.window as JSObject;
    if (globalWindow.hasProperty('dilseResume'.toJS).toDart) {
      globalWindow.callMethod('dilseResume'.toJS);
    }
  }

  static void seek(Duration position) {
    _currentPosition = position;
    _positionController.add(position);
    final seconds = position.inMilliseconds / 1000.0;
    final globalWindow = web.window as JSObject;
    if (globalWindow.hasProperty('dilseSeek'.toJS).toDart) {
      globalWindow.callMethod('dilseSeek'.toJS, seconds.toJS);
    }
  }

  static void setVolume(double volumePercent) {
    final globalWindow = web.window as JSObject;
    if (globalWindow.hasProperty('dilseSetVolume'.toJS).toDart) {
      globalWindow.callMethod('dilseSetVolume'.toJS, (volumePercent * 100).toJS);
    }
  }
}

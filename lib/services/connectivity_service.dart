import 'dart:async';
import 'dart:io' show InternetAddress, SocketException, Platform;
import 'package:flutter/foundation.dart';
import 'web_connectivity_helper.dart';
import 'music_service.dart';
import 'cloud_sync_service.dart';

enum NetworkQuality { good, poor, offline }

/// Central observer for internet connectivity, network quality, and offline status.
///
/// Automatically tracks connection quality (good, poor, offline) across Web,
/// Android, iOS, and Desktop platforms. Emits telemetry events to notify users
/// when bandwidth/latency degrades so they can smoothly transition to offline mode.
class ConnectivityService extends ChangeNotifier {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  bool _isOffline = false;
  bool get isOffline => _isOffline;
  bool get isOnline => !_isOffline;

  bool _isLowConnectivity = false;
  bool get isLowConnectivity => _isLowConnectivity;

  NetworkQuality _quality = NetworkQuality.good;
  NetworkQuality get quality => _quality;

  /// Global value notifier for observing quality transitions without rebuilds.
  static final ValueNotifier<NetworkQuality> qualityNotifier =
      ValueNotifier<NetworkQuality>(NetworkQuality.good);

  Timer? _timer;
  bool _isChecking = false;

  void init() {
    if (_timer != null) return;

    if (kIsWeb) {
      if (!isWebOnline()) {
        _isOffline = true;
        _quality = NetworkQuality.offline;
        qualityNotifier.value = NetworkQuality.offline;
      }
      setupWebConnectivityListeners((bool online) {
        if (!online) {
          _updateState(offline: true, low: false, q: NetworkQuality.offline);
        } else {
          _updateState(offline: false, low: false, q: NetworkQuality.good);
          unawaited(checkConnectivity());
        }
      });
    }

    unawaited(checkConnectivity());

    final isTest = !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');
    if (!isTest) {
      _timer = Timer.periodic(const Duration(seconds: 12), (_) {
        unawaited(checkConnectivity());
      });
    }
  }

  DateTime? _lastSilentSyncTime;

  void _triggerSilentRecoverySync() {
    final now = DateTime.now();
    if (_lastSilentSyncTime != null &&
        now.difference(_lastSilentSyncTime!) < const Duration(seconds: 45)) {
      return;
    }
    _lastSilentSyncTime = now;
    debugPrint(
      '[ConnectivityService] Internet recovered. Silently syncing sectors without disturbing user.',
    );

    // Sector 1: Home Feeds & Recommendations
    try {
      MusicService().preloadHomeData();
    } catch (_) {}

    // Sector 2: Cloud Sync (if signed in)
    try {
      CloudSyncService().sync();
    } catch (_) {}
  }

  void _updateState({
    required bool offline,
    required bool low,
    required NetworkQuality q,
  }) {
    if (_isOffline != offline || _isLowConnectivity != low || _quality != q) {
      final wasOfflineOrPoor =
          _isOffline || _isLowConnectivity || _quality != NetworkQuality.good;
      final isNowGood = !offline && !low && q == NetworkQuality.good;

      _isOffline = offline;
      _isLowConnectivity = low;
      _quality = q;
      qualityNotifier.value = q;
      notifyListeners();

      if (wasOfflineOrPoor && isNowGood) {
        _triggerSilentRecoverySync();
      }
    }
  }

  bool _cancelStartupAnalysis = false;

  void cancelStartupAnalysis() {
    _cancelStartupAnalysis = true;
  }

  /// Continuously analyzes internet connectivity and speed during app startup
  /// for up to [timeout] (default 7 seconds).
  ///
  /// - Returns `0` (Live Network Mode / Home) immediately as soon as a healthy connection is confirmed.
  /// - Allows mobile PWA cellular/Wi-Fi radios up to 7 seconds to complete initialization.
  /// - Returns `2` (Offline Mode) ONLY if the network remains slow or offline after the full 7-second window.
  /// - Guaranteed finite, non-blocking, and strictly bounded by [timeout] (zero ghost or infinite loops).
  Future<int> analyzeStartupRoute({
    Duration timeout = const Duration(seconds: 7),
    Duration probeInterval = const Duration(milliseconds: 400),
  }) async {
    final isTest = !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');
    if (isTest) {
      return (_isOffline || _quality != NetworkQuality.good) ? 2 : 0;
    }

    _cancelStartupAnalysis = false;
    final deadline = DateTime.now().add(timeout);

    // Initial check
    await checkConnectivity();
    if (_quality == NetworkQuality.good && !_isOffline) {
      return 0; // Home / Live Network Mode
    }

    // Active sampling loop strictly bounded by timeout and cancellation flag
    while (!_cancelStartupAnalysis && DateTime.now().isBefore(deadline)) {
      final remaining = deadline.difference(DateTime.now());
      if (remaining <= Duration.zero) break;

      final waitTime = remaining < probeInterval ? remaining : probeInterval;
      await Future.delayed(waitTime);

      if (_cancelStartupAnalysis) break;

      await checkConnectivity();
      if (_quality == NetworkQuality.good && !_isOffline) {
        debugPrint(
          '[ConnectivityService] Startup analysis: healthy network verified within 7s. Routing to Live Mode.',
        );
        return 0; // Home / Live Network Mode
      }
    }

    debugPrint(
      '[ConnectivityService] Startup analysis: network remained slow/offline after 7s. Routing to Offline Mode.',
    );
    return (_isOffline || _quality != NetworkQuality.good) ? 2 : 0;
  }

  @visibleForTesting
  void setOfflineForTesting(bool offline) {
    _updateState(
      offline: offline,
      low: false,
      q: offline ? NetworkQuality.offline : NetworkQuality.good,
    );
  }

  @visibleForTesting
  void setQualityForTesting(NetworkQuality q) {
    _updateState(
      offline: q == NetworkQuality.offline,
      low: q == NetworkQuality.poor,
      q: q,
    );
  }

  Future<void> checkConnectivity() async {
    if (_isChecking) return;
    if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) return;

    _isChecking = true;
    try {
      if (kIsWeb) {
        if (!isWebOnline()) {
          _updateState(offline: true, low: false, q: NetworkQuality.offline);
          return;
        }

        final isSlow = isWebConnectionSlow();
        if (isSlow) {
          _updateState(offline: false, low: true, q: NetworkQuality.poor);
        } else {
          _updateState(offline: false, low: false, q: NetworkQuality.good);
        }
        return;
      }

      // Native Mobile / Desktop implementation
      final stopwatch = Stopwatch()..start();
      try {
        final result = await InternetAddress.lookup(
          '1.1.1.1',
        ).timeout(const Duration(milliseconds: 2400));
        stopwatch.stop();

        final online = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
        if (!online) {
          _updateState(offline: true, low: false, q: NetworkQuality.offline);
        } else {
          final elapsed = stopwatch.elapsedMilliseconds;
          if (elapsed > 1800) {
            _updateState(offline: false, low: true, q: NetworkQuality.poor);
          } else {
            _updateState(offline: false, low: false, q: NetworkQuality.good);
          }
        }
      } on SocketException catch (_) {
        _updateState(offline: true, low: false, q: NetworkQuality.offline);
      } on TimeoutException catch (_) {
        // High packet drop / extreme latency
        _updateState(offline: false, low: true, q: NetworkQuality.poor);
      } catch (_) {
        // Transient error
      }
    } finally {
      _isChecking = false;
    }
  }

  void disposeService() {
    _timer?.cancel();
    _timer = null;
  }
}

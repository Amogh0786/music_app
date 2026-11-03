import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:web/web.dart' as web;

/// Web implementation using native HTML5 Navigator and window events.
bool isWebOnline() {
  try {
    return web.window.navigator.onLine;
  } catch (_) {
    return true;
  }
}

/// Checks browser Network Information API for connection speed quality.
/// Returns true ONLY if the device is on a slow-2g or 2g network, or RTT > 2000ms.
bool isWebConnectionSlow() {
  try {
    if (!web.window.navigator.onLine) return true;
    final nav = web.window.navigator as JSObject;
    if (nav.hasProperty('connection'.toJS).toDart) {
      final conn = nav.getProperty('connection'.toJS) as JSObject?;
      if (conn != null && !conn.isUndefined) {
        if (conn.hasProperty('effectiveType'.toJS).toDart) {
          final effectiveType =
              (conn.getProperty('effectiveType'.toJS) as JSString?)?.toDart;
          if (effectiveType == 'slow-2g' || effectiveType == '2g') {
            return true;
          }
        }
        if (conn.hasProperty('rtt'.toJS).toDart) {
          final rtt = (conn.getProperty('rtt'.toJS) as JSNumber?)?.toDartInt;
          if (rtt != null && rtt > 2000) {
            return true;
          }
        }
      }
    }
    return false;
  } catch (_) {
    return false;
  }
}

void setupWebConnectivityListeners(void Function(bool isOnline) onChange) {
  try {
    web.window.addEventListener(
      'online',
      ((web.Event _) {
        onChange(true);
      }).toJS,
    );
    web.window.addEventListener(
      'offline',
      ((web.Event _) {
        onChange(false);
      }).toJS,
    );
  } catch (_) {}
}

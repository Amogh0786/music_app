import 'web_connectivity_helper_stub.dart'
    if (dart.library.js_interop) 'web_connectivity_helper_web.dart'
    as helper;

/// Returns the browser's native online status (Web only, returns true on Native).
bool isWebOnline() => helper.isWebOnline();

/// Returns whether the browser's NetworkInformation API reports a constrained connection (e.g. 2G).
bool isWebConnectionSlow() => helper.isWebConnectionSlow();

/// Hooks into browser online/offline events (Web only, no-op on Native).
void setupWebConnectivityListeners(void Function(bool isOnline) onChange) =>
    helper.setupWebConnectivityListeners(onChange);

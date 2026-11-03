/// Stub implementation for non-web platforms.
bool isWebOnline() => true;

bool isWebConnectionSlow() => false;

void setupWebConnectivityListeners(void Function(bool isOnline) onChange) {}

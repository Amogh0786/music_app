import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'preferences_service.dart';

class ApiConfig {
  /// Default local ports and addresses
  static const String _defaultHostAndroid = '10.0.2.2:8000';
  static const String _defaultHostDesktop = '127.0.0.1:8000';

  /// Returns the base URL for the backend API.
  /// If the user configured a custom URL (e.g. Google Cloud deployment), it uses that.
  /// Otherwise, it detects the platform and picks 10.0.2.2 for Android emulator
  /// and 127.0.0.1 for desktop/web.
  static String get baseUrl {
    final customUrl = PreferencesService().customServerUrl;
    if (customUrl.isNotEmpty) {
      // Remove trailing slash if present
      return customUrl.endsWith('/') ? customUrl.substring(0, customUrl.length - 1) : customUrl;
    }

    if (kIsWeb) {
      return 'http://localhost:8000';
    }

    if (Platform.isAndroid) {
      return 'http://$_defaultHostAndroid';
    }

    return 'http://$_defaultHostDesktop';
  }

  static Uri searchUri(String query, {int page = 1, int limit = 20}) {
    return Uri.parse('$baseUrl/search?q=${Uri.encodeComponent(query)}&page=$page&limit=$limit');
  }

  static Uri suggestionsUri(String query, {int limit = 8}) {
    return Uri.parse('$baseUrl/suggestions?q=${Uri.encodeComponent(query)}&limit=$limit');
  }

  static Uri streamProxyUri(String videoId) {
    return Uri.parse('$baseUrl/stream/$videoId.m4a');
  }

  static Uri streamUrlUri(String videoId) {
    return Uri.parse('$baseUrl/stream_url?v=$videoId');
  }

  static Uri nextCandidatesUri(String videoId, {int limit = 20}) {
    return Uri.parse('$baseUrl/next_candidates?v=$videoId&limit=$limit');
  }

  static Uri trackFinishedUri() {
    return Uri.parse('$baseUrl/track_finished');
  }

  static Uri cacheInvalidateUri(String videoId) {
    return Uri.parse('$baseUrl/cache/$videoId');
  }
}

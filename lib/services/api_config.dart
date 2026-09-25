import 'preferences_service.dart';

class ApiConfig {
  static const String _defaultCloudUrl = 'https://music-backend-4kel.onrender.com';

  /// Returns the base URL for the backend API.
  /// Uses custom URL if configured by the user, otherwise defaults to the live Render cloud backend.
  static String get baseUrl {
    final customUrl = PreferencesService().customServerUrl;
    if (customUrl.isNotEmpty) {
      // Remove trailing slash if present
      return customUrl.endsWith('/') ? customUrl.substring(0, customUrl.length - 1) : customUrl;
    }

    return _defaultCloudUrl;
  }

  static const String defaultCloudflareWorkerUrl =
      'https://dilse-edge-stream.charanteja-kondakalla030206.workers.dev';

  /// Returns the configured Cloudflare Worker base URL for direct audio streaming.
  /// Falls back to defaultCloudflareWorkerUrl if not explicitly configured.
  static String get cloudflareWorkerUrl {
    final customUrl = PreferencesService().cloudflareWorkerUrl;
    if (customUrl.isNotEmpty) {
      return customUrl.endsWith('/') ? customUrl.substring(0, customUrl.length - 1) : customUrl;
    }
    return defaultCloudflareWorkerUrl;
  }

  static Uri cloudflareStreamUri(String videoId) {
    return Uri.parse('$cloudflareWorkerUrl/stream?v=$videoId');
  }

  static Uri jioSearchUri(String query, {int limit = 20}) {
    return Uri.parse('$baseUrl/jio/search?q=${Uri.encodeComponent(query)}&limit=$limit');
  }

  static Uri jioBackendSearchUri(String query, {int limit = 20}) {
    return Uri.parse('$baseUrl/jio/search?q=${Uri.encodeComponent(query)}&limit=$limit');
  }

  static Uri jioRecommendationsUri(String query, {String language = 'telugu', int limit = 20}) {
    return Uri.parse('$baseUrl/jio/recommendations?q=${Uri.encodeComponent(query)}&language=${Uri.encodeComponent(language)}&limit=$limit');
  }

  static Uri jioSuggestionsUri(String query, {int limit = 8}) {
    return Uri.parse('$baseUrl/jio/suggestions?q=${Uri.encodeComponent(query)}&limit=$limit');
  }

  static Uri radioUri(String videoId, {int limit = 30, String? title, String? artist}) {
    final buffer = StringBuffer('$baseUrl/radio?v=$videoId&limit=$limit');
    if (title != null && title.isNotEmpty) buffer.write('&title=${Uri.encodeComponent(title)}');
    if (artist != null && artist.isNotEmpty) buffer.write('&artist=${Uri.encodeComponent(artist)}');
    return Uri.parse(buffer.toString());
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

  static Uri nextCandidatesUri(String videoId, {int limit = 20, String? title, String? artist}) {
    final buffer = StringBuffer('$baseUrl/next_candidates?v=$videoId&limit=$limit');
    if (title != null && title.isNotEmpty) {
      buffer.write('&title=${Uri.encodeComponent(title)}');
    }
    if (artist != null && artist.isNotEmpty) {
      buffer.write('&artist=${Uri.encodeComponent(artist)}');
    }
    return Uri.parse(buffer.toString());
  }

  static Uri trackFinishedUri() {
    return Uri.parse('$baseUrl/track_finished');
  }

  static Uri cacheInvalidateUri(String videoId) {
    return Uri.parse('$baseUrl/cache/$videoId');
  }

  static Uri preloadUri(String videoId) {
    return Uri.parse('$baseUrl/preload?v=$videoId');
  }

  static Uri clientLogUri() {
    return Uri.parse('$baseUrl/client_log');
  }

  static Uri cloudflareLyricsUri(String title, {String? artist, String? lang, int? duration}) {
    final buffer = StringBuffer('$cloudflareWorkerUrl/lyrics?title=${Uri.encodeComponent(title)}');
    if (artist != null && artist.isNotEmpty) {
      buffer.write('&artist=${Uri.encodeComponent(artist)}');
    }
    if (lang != null && lang.isNotEmpty) {
      buffer.write('&lang=${Uri.encodeComponent(lang)}');
    }
    if (duration != null && duration > 0) {
      buffer.write('&duration=$duration');
    }
    return Uri.parse(buffer.toString());
  }

  static Uri backendLyricsUri(String title, {String? artist, String? lang, int? duration}) {
    final buffer = StringBuffer('$baseUrl/lyrics?title=${Uri.encodeComponent(title)}');
    if (artist != null && artist.isNotEmpty) {
      buffer.write('&artist=${Uri.encodeComponent(artist)}');
    }
    if (lang != null && lang.isNotEmpty) {
      buffer.write('&lang=${Uri.encodeComponent(lang)}');
    }
    if (duration != null && duration > 0) {
      buffer.write('&duration=$duration');
    }
    return Uri.parse(buffer.toString());
  }
}

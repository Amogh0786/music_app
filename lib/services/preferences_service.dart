import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ArtworkStyle { card, vinyl }

class PreferencesService extends ChangeNotifier {
  static final PreferencesService _instance = PreferencesService._internal();
  factory PreferencesService() => _instance;

  PreferencesService._internal();

  late SharedPreferences _prefs;
  bool _isInitialized = false;

  // Settings
  bool _crossfadeEnabled = false;
  Color _themeColor = const Color(0xFFFA2D48); // Default Apple Red
  double _cacheSizeMB = 500.0;
  String _customServerUrl = '';
  ArtworkStyle _artworkStyle = ArtworkStyle.card;

  // Search History
  List<String> _searchHistory = [];

  // Listening Preferences & Play Counts
  final Map<String, int> _artistPlayCounts = {};
  String _mostPlayedArtist = '';

  bool get isInitialized => _isInitialized;
  bool get crossfadeEnabled => _crossfadeEnabled;
  Color get themeColor => _themeColor;
  double get cacheSizeMB => _cacheSizeMB;
  String get customServerUrl => _customServerUrl;
  ArtworkStyle get artworkStyle => _artworkStyle;
  List<String> get searchHistory => _searchHistory;
  String get mostPlayedArtist => _mostPlayedArtist;

  Future<void> init() async {
    if (_isInitialized) return;
    _prefs = await SharedPreferences.getInstance();

    _crossfadeEnabled = _prefs.getBool('crossfade') ?? false;
    int colorValue = _prefs.getInt('themeColor') ?? 0xFFFA2D48;
    _themeColor = Color(colorValue);
    _cacheSizeMB = _prefs.getDouble('cacheSizeMB') ?? 500.0;
    _customServerUrl = _prefs.getString('customServerUrl') ?? '';
    _searchHistory = _prefs.getStringList('searchHistory') ?? [];
    _mostPlayedArtist = _prefs.getString('mostPlayedArtist') ?? '';
    final styleStr = _prefs.getString('artworkStyle') ?? 'card';
    _artworkStyle = styleStr == 'vinyl' ? ArtworkStyle.vinyl : ArtworkStyle.card;

    _isInitialized = true;
    notifyListeners();
  }

  Future<void> recordSongPlay(String artist, String title) async {
    if (artist.trim().isEmpty) return;

    final count = (_artistPlayCounts[artist] ?? 0) + 1;
    _artistPlayCounts[artist] = count;

    // Recalculate top artist
    String topArtist = _mostPlayedArtist;
    int maxCount = 0;
    _artistPlayCounts.forEach((key, val) {
      if (val > maxCount) {
        maxCount = val;
        topArtist = key;
      }
    });

    if (topArtist != _mostPlayedArtist) {
      _mostPlayedArtist = topArtist;
      await _prefs.setString('mostPlayedArtist', _mostPlayedArtist);
    }
    notifyListeners();
  }

  Future<void> setCrossfade(bool value) async {
    _crossfadeEnabled = value;
    await _prefs.setBool('crossfade', value);
    notifyListeners();
  }

  Future<void> setThemeColor(Color color) async {
    _themeColor = color;
    await _prefs.setInt('themeColor', color.toARGB32());
    notifyListeners();
  }

  Future<void> setCacheSize(double sizeMB) async {
    _cacheSizeMB = sizeMB;
    await _prefs.setDouble('cacheSizeMB', sizeMB);
    notifyListeners();
  }

  Future<void> setCustomServerUrl(String url) async {
    _customServerUrl = url.trim();
    await _prefs.setString('customServerUrl', _customServerUrl);
    notifyListeners();
  }

  Future<void> addToSearchHistory(String query) async {
    if (query.trim().isEmpty) return;
    _searchHistory.remove(query);
    _searchHistory.insert(0, query);
    if (_searchHistory.length > 10) {
      _searchHistory = _searchHistory.sublist(0, 10);
    }
    await _prefs.setStringList('searchHistory', _searchHistory);
    notifyListeners();
  }

  Future<void> clearSearchHistory() async {
    _searchHistory.clear();
    await _prefs.setStringList('searchHistory', _searchHistory);
    notifyListeners();
  }

  Future<void> setArtworkStyle(ArtworkStyle style) async {
    _artworkStyle = style;
    await _prefs.setString('artworkStyle', style.name);
    notifyListeners();
  }

  Future<void> toggleArtworkStyle() async {
    final next = _artworkStyle == ArtworkStyle.card ? ArtworkStyle.vinyl : ArtworkStyle.card;
    await setArtworkStyle(next);
  }
}

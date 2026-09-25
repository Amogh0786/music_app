import 'package:flutter/material.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// Represents a 3-color harmonious palette for ambient player backgrounds and accents.
class AlbumPalette {
  final Color dominant;
  final Color vibrant;
  final Color darkVibrant;

  const AlbumPalette({
    required this.dominant,
    required this.vibrant,
    required this.darkVibrant,
  });
}

/// Instant deterministic & cached color deriver for album artwork backgrounds.
/// Ensures that the player background immediately adapts according to the album shown
/// with zero delay, no GPU blur overhead, and beautiful contrast in dark mode.
class AlbumColorDeriver {
  static final Map<String, AlbumPalette> _cache = {};

  /// Retrieves an adaptive palette for the given song.
  /// Uses cached extracted palette if available, or derives an instant deterministic palette.
  static AlbumPalette getPalette(
    Video? song, {
    Color? fallbackDominant,
    Color? fallbackVibrant,
    Color? fallbackDarkVibrant,
  }) {
    if (song == null) {
      return const AlbumPalette(
        dominant: Color(0xFF1E1E2C),
        vibrant: Color(0xFFFA2D48),
        darkVibrant: Color(0xFF12121A),
      );
    }

    final id = song.id.value;

    // If caller provided an active extracted palette from MusicService, cache and use it
    if (fallbackDominant != null &&
        fallbackDominant != const Color(0xFF1E1E2C) &&
        fallbackDominant != const Color(0xFF000000)) {
      final p = AlbumPalette(
        dominant: fallbackDominant,
        vibrant: fallbackVibrant ?? fallbackDominant,
        darkVibrant: fallbackDarkVibrant ?? fallbackDominant,
      );
      _cache[id] = p;
      return p;
    }

    if (_cache.containsKey(id)) {
      return _cache[id]!;
    }

    // Instant deterministic color mapping based on song metadata (Hard-coded color algorithm)
    // Curated with high saturation and deep luminance for rich ambient aura behind the player
    final hash = (song.title.hashCode ^ (song.author.hashCode * 31) ^ (id.hashCode * 17)).abs();
    final double hue = (hash % 360).toDouble();

    final dominant = HSLColor.fromAHSL(1.0, hue, 0.65, 0.22).toColor();
    final vibrant = HSLColor.fromAHSL(1.0, hue, 0.85, 0.52).toColor();
    final darkVibrant = HSLColor.fromAHSL(1.0, (hue + 45) % 360, 0.58, 0.12).toColor();

    final palette = AlbumPalette(
      dominant: dominant,
      vibrant: vibrant,
      darkVibrant: darkVibrant,
    );
    _cache[id] = palette;
    return palette;
  }

  /// Registers an asynchronously extracted palette for a track ID.
  static void registerExtractedPalette(
    String songId,
    Color dominant,
    Color vibrant,
    Color darkVibrant,
  ) {
    if (songId.isNotEmpty) {
      _cache[songId] = AlbumPalette(
        dominant: dominant,
        vibrant: vibrant,
        darkVibrant: darkVibrant,
      );
    }
  }

  /// Clears the palette cache if needed.
  static void clearCache() {
    _cache.clear();
  }
}

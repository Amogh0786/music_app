import 'dart:math';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// Industrial-grade Canonical Song Normalizer & Deduplicator.
///
/// Handles noisy YouTube titles with movie names, actors, skits, and 4K tags,
/// matching them accurately against clean JioSaavn and YouTube Music studio tracks.
class CanonicalSongDedup {
  CanonicalSongDedup._();

  // Noise regex for titles
  static final RegExp _bracketNoise = RegExp(r'\([^)]*\)|\[[^\]]*\]');
  static final RegExp _featNoise = RegExp(r'\b(feat\.?|ft\.?)\b.*$', caseSensitive: false);
  static final RegExp _videoNoiseWords = RegExp(
    r'\b(official\s+video|official\s+music\s+video|official\s+lyric\s+video|lyric\s+video|'
    r'full\s+video\s+song|video\s+song|full\s+song|full\s+audio|audio\s+song|lyrics|'
    r'lyrical|4k\s+video|hd\s+video|4k|8k|hd|1080p|remix|mashup|status\s+video|status|'
    r'ringtone|dialogue|extended\s+version|original\s+soundtrack|ost)\b',
    caseSensitive: false,
  );
  static final RegExp _punctuation = RegExp(r'[^a-zA-Z0-9\s]');
  static final RegExp _whitespace = RegExp(r'\s+');

  // Record label and noise words in artist names
  static const Set<String> _labelNoise = {
    't-series', 'tseries', 'aditya music', 'sony music', 'zee music',
    'lahari music', 'speed audio', 'tips official', 'tips', 'saregama',
    'yrf', 'think music', 'vevo', 'records', 'entertainment', 'music',
    'official', 'channel', 'audio', 'soundtracks', 'company'
  };

  /// Common stopwords ignored during token set comparison
  static const Set<String> _stopwords = {
    'the', 'a', 'an', 'and', 'from', 'in', 'on', 'at', 'to', 'for', 'of',
    'with', 'by', 'song', 'track', 'movie', 'album'
  };

  /// Normalizes a song title to its canonical core name
  static String cleanTitle(String raw) {
    if (raw.trim().isEmpty) return '';

    // 1. Remove feat. / ft. suffixes
    var s = raw.replaceAll(_featNoise, ' ');

    // 2. Remove bracketed text: (Official Video), [4K HDR], (From "Movie")
    s = s.replaceAll(_bracketNoise, ' ');

    // 3. Take primary section before common delimiters: | : – — / or " - "
    final parts = s.split(RegExp(r'\s*[|:–—/]\s*|\s+-\s+'));
    if (parts.isNotEmpty && parts.first.trim().isNotEmpty) {
      s = parts.first;
    }

    // 4. Remove common video noise words
    s = s.replaceAll(_videoNoiseWords, ' ');

    // 5. Remove punctuation and collapse spaces
    s = s.replaceAll(_punctuation, ' ').replaceAll(_whitespace, ' ').trim();

    return s.toLowerCase();
  }

  /// Normalizes artist name, stripping YouTube "- Topic" and record labels
  static String cleanArtist(String raw) {
    if (raw.trim().isEmpty) return '';

    var s = raw.replaceAll(' - Topic', '').replaceAll('- Topic', '').trim();
    final lower = s.toLowerCase();

    // Check if artist is just a record label channel
    for (final label in _labelNoise) {
      if (lower == label || (lower.contains(label) && lower.length < label.length + 6)) {
        return '';
      }
    }

    // Extract primary artist if comma, ampersand, or semicolon separated
    final primaryParts = s.split(RegExp(r'[,;&]'));
    if (primaryParts.isNotEmpty) {
      s = primaryParts.first;
    }

    s = s.replaceAll(_punctuation, ' ').replaceAll(_whitespace, ' ').trim();
    return s.toLowerCase();
  }

  /// Extracts meaningful token set from normalized text
  static Set<String> tokenize(String text) {
    return text
        .toLowerCase()
        .split(_whitespace)
        .where((w) => w.length > 1 && !_stopwords.contains(w))
        .toSet();
  }

  /// Calculates Jaccard similarity between two token sets (0.0 to 1.0)
  static double jaccardSimilarity(Set<String> a, Set<String> b) {
    if (a.isEmpty || b.isEmpty) return 0.0;
    final intersection = a.intersection(b).length;
    final union = a.union(b).length;
    if (union == 0) return 0.0;
    return intersection / union;
  }

  /// Calculates Levenshtein-based similarity (0.0 to 1.0)
  static double stringSimilarity(String s1, String s2) {
    if (s1 == s2) return 1.0;
    if (s1.isEmpty || s2.isEmpty) return 0.0;

    final len1 = s1.length;
    final len2 = s2.length;
    final maxLen = max(len1, len2);
    if (maxLen == 0) return 1.0;

    // Fast-path length discrepancy
    if ((len1 - len2).abs() > (maxLen * 0.6)) return 0.0;

    final dist = _levenshteinDistance(s1, s2);
    return 1.0 - (dist / maxLen);
  }

  static int _levenshteinDistance(String s, String t) {
    if (s == t) return 0;
    if (s.isEmpty) return t.length;
    if (t.isEmpty) return s.length;

    List<int> v0 = List<int>.generate(t.length + 1, (i) => i);
    List<int> v1 = List<int>.filled(t.length + 1, 0);

    for (int i = 0; i < s.length; i++) {
      v1[0] = i + 1;
      for (int j = 0; j < t.length; j++) {
        final cost = (s[i] == t[j]) ? 0 : 1;
        v1[j + 1] = min(v1[j] + 1, min(v0[j + 1] + 1, v0[j] + cost));
      }
      for (int j = 0; j < t.length + 1; j++) {
        v0[j] = v1[j];
      }
    }
    return v0[t.length];
  }

  /// Determines if two song items represent the exact same track.
  static bool areDuplicateSongs({
    required String titleA,
    required String artistA,
    required String titleB,
    required String artistB,
    double threshold = 0.75,
  }) {
    final cleanTA = cleanTitle(titleA);
    final cleanTB = cleanTitle(titleB);

    if (cleanTA.isEmpty || cleanTB.isEmpty) return false;

    // Exact clean title match
    if (cleanTA == cleanTB) return true;

    // Token-set Jaccard overlap
    final tokensA = tokenize(cleanTA);
    final tokensB = tokenize(cleanTB);

    if (tokensA.isNotEmpty && tokensB.isNotEmpty) {
      final jaccard = jaccardSimilarity(tokensA, tokensB);
      if (jaccard >= 0.70) return true;

      // Check if one token set is a complete subset of the other (e.g. "Kesariya" in "Kesariya Dance")
      final intersection = tokensA.intersection(tokensB).length;
      final smallerLen = min(tokensA.length, tokensB.length);
      if (smallerLen > 0 && intersection == smallerLen && smallerLen >= 2) {
        return true;
      }
    }

    // Levenshtein string similarity on clean title
    final titleSim = stringSimilarity(cleanTA, cleanTB);
    if (titleSim >= threshold) return true;

    // Check artist consistency if title similarity is moderately high (>= 0.60)
    if (titleSim >= 0.60) {
      final cleanAA = cleanArtist(artistA);
      final cleanAB = cleanArtist(artistB);
      if (cleanAA.isNotEmpty && cleanAB.isNotEmpty) {
        if (cleanAA == cleanAB || cleanAA.contains(cleanAB) || cleanAB.contains(cleanAA)) {
          return true;
        }
      }
    }

    return false;
  }

  /// Deduplicates [incoming] songs against [primary] existing songs.
  /// If [incoming] is omitted, deduplicates [primary] against itself.
  /// Any song in [incoming] that duplicates a song in [primary] (or earlier in [incoming]) is dropped.
  static List<Video> deduplicateList(List<Video> primary, [List<Video>? incoming]) {
    if (incoming == null) {
      final result = <Video>[];
      for (final song in primary) {
        bool isDup = false;
        for (final existing in result) {
          if (existing.id.value == song.id.value ||
              areDuplicateSongs(
                titleA: existing.title,
                artistA: existing.author,
                titleB: song.title,
                artistB: song.author,
              )) {
            isDup = true;
            break;
          }
        }
        if (!isDup) {
          result.add(song);
        }
      }
      return result;
    }

    final result = <Video>[];
    final allKnown = <Video>[...primary];

    for (final song in incoming) {
      bool isDup = false;
      for (final existing in allKnown) {
        if (existing.id.value == song.id.value ||
            areDuplicateSongs(
              titleA: existing.title,
              artistA: existing.author,
              titleB: song.title,
              artistB: song.author,
            )) {
          isDup = true;
          break;
        }
      }

      if (!isDup) {
        result.add(song);
        allKnown.add(song);
      }
    }

    return result;
  }

  /// Re-orders or spaces a queue of songs so that no two consecutive songs
  /// are from the exact same artist, promoting balanced artist distribution.
  static List<Video> balanceArtistDistribution(List<Video> songs) {
    if (songs.length <= 2) return songs;

    final artistBuckets = <String, List<Video>>{};
    for (final song in songs) {
      final artist = cleanArtist(song.author);
      final key = artist.isNotEmpty ? artist : 'unknown_${song.id.value}';
      artistBuckets.putIfAbsent(key, () => []).add(song);
    }

    // Sort buckets by size descending
    final sortedBuckets = artistBuckets.values.toList()
      ..sort((a, b) => b.length.compareTo(a.length));

    final balanced = <Video>[];
    int maxBucketSize = sortedBuckets.first.length;

    for (int i = 0; i < maxBucketSize; i++) {
      for (final bucket in sortedBuckets) {
        if (i < bucket.length) {
          balanced.add(bucket[i]);
        }
      }
    }

    return balanced;
  }
}

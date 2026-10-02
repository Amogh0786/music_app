import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'canonical_song_dedup.dart';
import 'preferences_service.dart';

/// Client-side personalized candidate re-ranker.
/// Scores candidate songs returned from global co-listening/radio graphs
/// using the user's on-device Taste Matrix (artist affinities, play counts,
/// preferred languages, liked songs, and skip penalties).
class TasteMatrixScorer {
  static final TasteMatrixScorer _instance = TasteMatrixScorer._internal();
  factory TasteMatrixScorer() => _instance;
  TasteMatrixScorer._internal();

  /// Re-ranks [candidates] based on user's personal taste matrix.
  ///
  /// Scoring Model:
  /// - Base Rank: Preserves Google's global acoustic similarity
  /// - Artist Affinity: Rewards artists the user listens to frequently
  /// - Language Bonus: Boosts tracks matching user's preferred languages
  /// - Liked Song Bonus: Boosts familiar favorites
  /// - Fatigue Cap: Prevents any single artist from dominating the queue
  List<Video> scoreAndRankCandidates(
    List<Video> candidates, {
    String? targetLanguage,
    List<String>? likedSongTitles,
    int maxResults = 30,
  }) {
    if (candidates.isEmpty) return [];

    final dedupedCandidates = CanonicalSongDedup.deduplicateList(candidates);
    if (dedupedCandidates.isEmpty) return [];

    final prefs = PreferencesService();
    final matrix = prefs.getTasteMatrix();
    final preferredLangs = prefs.preferredLanguages
        .map((l) => l.toLowerCase())
        .toList();
    final likedSet =
        likedSongTitles?.map((t) => CanonicalSongDedup.cleanTitle(t)).toSet() ??
        <String>{};

    final scored = <MapEntry<Video, double>>[];

    for (int i = 0; i < dedupedCandidates.length; i++) {
      final track = dedupedCandidates[i];
      if (!CanonicalSongDedup.isGenuineSong(track)) continue;

      // 1. Base rank from global acoustic graph (decays with position)
      double score = (dedupedCandidates.length - i) * 0.25;

      // 2. Artist Affinity
      final cleanAuthor = CanonicalSongDedup.cleanArtist(track.author);
      final rawAffinity = matrix.artistAffinities[cleanAuthor] ?? 0.0;
      if (rawAffinity > 0) {
        score += (rawAffinity / 4.0).clamp(0.0, 6.0);
      } else if (rawAffinity < 0) {
        // Skip penalty
        score -= (rawAffinity.abs() / 2.0).clamp(0.0, 4.0);
      }

      // Check if artist is in user's top 5
      if (matrix.topArtists.any(
        (a) => a.toLowerCase() == cleanAuthor.toLowerCase(),
      )) {
        score += 2.5;
      }

      // 3. Language Affinity
      final trackLang = CanonicalSongDedup.detectLanguage(
        track.title,
      )?.toLowerCase();
      if (trackLang != null) {
        if (targetLanguage != null &&
            targetLanguage.toLowerCase() == trackLang) {
          score += 3.5;
        } else if (preferredLangs.contains(trackLang)) {
          score += 2.5;
        } else if (preferredLangs.isNotEmpty &&
            !preferredLangs.contains(trackLang)) {
          // Track is in a language not in user preferences
          score -= 2.0;
        }
      }

      // 4. Liked Song familiarity bonus
      final cleanT = CanonicalSongDedup.cleanTitle(track.title);
      if (likedSet.contains(cleanT)) {
        score += 3.0;
      }

      scored.add(MapEntry(track, score));
    }

    // Sort by descending score
    scored.sort((a, b) => b.value.compareTo(a.value));

    // 5. Apply Artist Fatigue Filter (max 2 songs per artist in sliding window of 5)
    final result = <Video>[];
    final remaining = scored.map((e) => e.key).toList();

    while (remaining.isNotEmpty && result.length < maxResults) {
      Video? chosen;
      for (int i = 0; i < remaining.length; i++) {
        final candidate = remaining[i];

        // Reject if candidate duplicates any song already in result
        final isDup = result.any(
          (existing) =>
              existing.id.value == candidate.id.value ||
              CanonicalSongDedup.areDuplicateSongs(
                titleA: existing.title,
                artistA: existing.author,
                titleB: candidate.title,
                artistB: candidate.author,
              ),
        );
        if (isDup) {
          remaining.removeAt(i);
          i--;
          continue;
        }

        final authorNorm = CanonicalSongDedup.cleanArtist(
          candidate.author,
        ).toLowerCase();

        // Check last 4 tracks in result
        final recentWindow = result.length >= 4
            ? result.sublist(result.length - 4)
            : result;
        final countInRecent = recentWindow.where((r) {
          return CanonicalSongDedup.cleanArtist(r.author).toLowerCase() ==
              authorNorm;
        }).length;

        if (countInRecent < 2) {
          chosen = candidate;
          remaining.removeAt(i);
          break;
        }
      }

      if (chosen != null) {
        result.add(chosen);
      } else if (remaining.isNotEmpty) {
        // If all remaining candidates violate the fatigue cap, pick the next non-duplicate
        result.add(remaining.removeAt(0));
      }
    }

    return result;
  }
}

import '../models/dilse_capsule_data.dart';
import 'preferences_service.dart';

/// 100% On-Device Listening Analytics Service for DilSe Capsule.
/// Computes personalized metrics, listening chronotypes, and top artist distributions
/// completely privately on the client device without telemetry or remote servers.
class CapsuleService {
  static final CapsuleService _instance = CapsuleService._internal();
  factory CapsuleService() => _instance;
  CapsuleService._internal();

  /// Generates the user's on-demand Capsule listening snapshot.
  DilSeCapsuleData buildCapsuleData([PreferencesService? customPrefs]) {
    final prefs = customPrefs ?? PreferencesService();

    // 1. Calculate Top Tracks
    final mostPlayed = prefs.mostPlayedSongs;
    final List<CapsuleTrack> topTracks = [];

    if (mostPlayed.isNotEmpty) {
      for (final item in mostPlayed.take(5)) {
        topTracks.add(
          CapsuleTrack(
            id: (item['id'] as String?) ?? '',
            title: (item['title'] as String?) ?? 'Unknown Track',
            author: (item['author'] as String?) ?? 'Unknown Artist',
            thumbnail: (item['thumbnail'] as String?) ?? '',
            playCount: (item['playCount'] as num?)?.toInt() ?? 1,
          ),
        );
      }
    } else if (prefs.listeningHistory.isNotEmpty) {
      final seenIds = <String>{};
      for (final item in prefs.listeningHistory) {
        final id = item['id'] ?? '';
        if (id.isNotEmpty && !seenIds.contains(id)) {
          seenIds.add(id);
          topTracks.add(
            CapsuleTrack(
              id: id,
              title: item['title'] ?? 'Unknown Track',
              author: item['author'] ?? 'Unknown Artist',
              thumbnail: item['thumbnail'] ?? '',
              playCount: 1,
            ),
          );
          if (topTracks.length >= 5) break;
        }
      }
    }

    // 2. Calculate Top Artists
    final List<CapsuleArtist> topArtists = [];
    final artistEntries = prefs.getTopPlayedArtists(limit: 5);

    int totalArtistPlays = 0;
    for (final e in artistEntries) {
      totalArtistPlays += e.value;
    }

    if (artistEntries.isNotEmpty) {
      for (final e in artistEntries) {
        final pct = totalArtistPlays > 0
            ? ((e.value / totalArtistPlays) * 100.0)
            : (100.0 / artistEntries.length);
        topArtists.add(
          CapsuleArtist(
            name: e.key,
            playCount: e.value,
            percentage: double.parse(pct.toStringAsFixed(1)),
          ),
        );
      }
    } else if (topTracks.isNotEmpty) {
      for (final t in topTracks) {
        topArtists.add(
          CapsuleArtist(
            name: t.author,
            playCount: t.playCount,
            percentage: 20.0,
          ),
        );
      }
    }

    // 3. Compute Stream Counts & Estimated Minutes
    final totalStreams = prefs.totalPlays > 0
        ? prefs.totalPlays
        : (prefs.listeningHistory.isNotEmpty
              ? prefs.listeningHistory.length
              : (topTracks.isNotEmpty ? topTracks.length : 0));

    final totalMinutes = totalStreams > 0
        ? (totalStreams * 3.5).round().clamp(1, 999999)
        : 0;

    final uniqueArtists = prefs.realPlaybackCounts.isNotEmpty
        ? prefs.realPlaybackCounts.length
        : topArtists.length;

    // 4. Chronotype & Peak Listening Hour Analysis
    int lateNight = 0; // 23:00 - 04:59
    int morning = 0; // 05:00 - 11:59
    int afternoon = 0; // 12:00 - 16:59
    int evening = 0; // 17:00 - 22:59

    void checkTimestamp(String? iso) {
      if (iso == null || iso.isEmpty) return;
      try {
        final dt = DateTime.parse(iso).toLocal();
        final h = dt.hour;
        if (h >= 23 || h < 5) {
          lateNight++;
        } else if (h >= 5 && h < 12) {
          morning++;
        } else if (h >= 12 && h < 17) {
          afternoon++;
        } else {
          evening++;
        }
      } catch (_) {}
    }

    for (final t in prefs.listeningHistory) {
      checkTimestamp(t['playedAt']);
    }
    for (final t in mostPlayed) {
      checkTimestamp(t['lastPlayedAt'] as String?);
    }

    String peakTimeDescription;
    String personaTitle;
    String personaDescription;
    String personaEmoji;

    if (totalStreams < 2) {
      personaTitle = 'The Curious Pioneer';
      personaEmoji = '🌱';
      personaDescription =
          'Your musical story on DilSe is just beginning. Every stream you play is crafting your unique acoustic DNA.';
      peakTimeDescription = 'Open Horizons';
    } else {
      // Determine dominant time of day
      int maxCount = lateNight;
      peakTimeDescription = 'Late Night (11 PM – 5 AM)';
      String timeBucket = 'night';

      if (morning > maxCount) {
        maxCount = morning;
        peakTimeDescription = 'Morning (5 AM – 12 PM)';
        timeBucket = 'morning';
      }
      if (afternoon > maxCount) {
        maxCount = afternoon;
        peakTimeDescription = 'Afternoon (12 PM – 5 PM)';
        timeBucket = 'afternoon';
      }
      if (evening > maxCount) {
        maxCount = evening;
        peakTimeDescription = 'Evening (5 PM – 11 PM)';
        timeBucket = 'evening';
      }

      // Check loyalty
      final topArtistPct = topArtists.isNotEmpty
          ? topArtists.first.percentage
          : 0.0;

      if (topArtistPct >= 40.0 && topArtists.isNotEmpty) {
        personaTitle = 'The Devoted Purist';
        personaEmoji = '🔥';
        personaDescription =
            'When an artist speaks to your heart, you stay loyal through every verse. ${topArtists.first.name} dominates your soundscape.';
      } else if (uniqueArtists >= 8) {
        personaTitle = 'The Sonic Explorer';
        personaEmoji = '🧭';
        personaDescription =
            'Genre borders and languages don\'t constrain your listening. You seek emotional truth wherever the melody leads.';
      } else if (timeBucket == 'night') {
        personaTitle = 'The Midnight Dreamer';
        personaEmoji = '🌙';
        personaDescription =
            'Your soul awakens when the world goes quiet. Late-night frequencies and contemplative melodies are your true sanctuary.';
      } else if (timeBucket == 'morning') {
        personaTitle = 'The Dawn Sprinter';
        personaEmoji = '🌅';
        personaDescription =
            'You ignite your days with positive rhythms and energizing cadences, setting the pace before the world catches up.';
      } else if (timeBucket == 'afternoon') {
        personaTitle = 'The Flow State Seeker';
        personaEmoji = '⚡';
        personaDescription =
            'Music is your productivity engine. You lock into deep concentration with steady tempos and immersive grooves.';
      } else {
        personaTitle = 'The Twilight Romantic';
        personaEmoji = '🌆';
        personaDescription =
            'As dusk settles over the day, you melt away stress with rich instrumentals and heartfelt vocal harmonies.';
      }
    }

    // 5. Acoustic Vibe Scores
    final profile = prefs.audioProfile;
    final Map<String, double> vibeScores = {
      'Energy': profile.avgEnergy > 0 ? profile.avgEnergy : 0.74,
      'Dance': profile.avgDanceability > 0 ? profile.avgDanceability : 0.68,
      'Acoustic': profile.avgAcousticness > 0 ? profile.avgAcousticness : 0.58,
      'Valence': profile.avgValence > 0 ? profile.avgValence : 0.70,
    };

    final topLanguages = prefs.preferredLanguages.isNotEmpty
        ? prefs.preferredLanguages.take(4).toList()
        : ['Hindi', 'Telugu', 'Tamil', 'English'];

    return DilSeCapsuleData(
      totalMinutes: totalMinutes,
      totalStreams: totalStreams,
      uniqueArtistsCount: uniqueArtists,
      topArtists: topArtists,
      topTracks: topTracks,
      personaTitle: personaTitle,
      personaDescription: personaDescription,
      personaEmoji: personaEmoji,
      topLanguages: topLanguages,
      peakTimeDescription: peakTimeDescription,
      vibeScores: vibeScores,
      generatedAt: DateTime.now(),
      hasEnoughData: totalStreams > 0,
    );
  }
}

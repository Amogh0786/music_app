/// Represents a top artist entry in the DilSe Capsule.
class CapsuleArtist {
  final String name;
  final int playCount;
  final double percentage;

  const CapsuleArtist({
    required this.name,
    required this.playCount,
    required this.percentage,
  });
}

class CapsuleTrack {
  final String id;
  final String title;
  final String author;
  final String thumbnail;
  final int playCount;

  const CapsuleTrack({
    required this.id,
    required this.title,
    required this.author,
    required this.thumbnail,
    required this.playCount,
  });
}

class DilSeCapsuleData {
  final int totalMinutes;
  final int totalStreams;
  final int uniqueArtistsCount;
  final List<CapsuleArtist> topArtists;
  final List<CapsuleTrack> topTracks;
  final String personaTitle;
  final String personaDescription;
  final String personaEmoji;
  final List<String> topLanguages;
  final String peakTimeDescription;
  final Map<String, double> vibeScores;
  final DateTime generatedAt;
  final bool hasEnoughData;

  const DilSeCapsuleData({
    required this.totalMinutes,
    required this.totalStreams,
    required this.uniqueArtistsCount,
    required this.topArtists,
    required this.topTracks,
    required this.personaTitle,
    required this.personaDescription,
    required this.personaEmoji,
    required this.topLanguages,
    required this.peakTimeDescription,
    required this.vibeScores,
    required this.generatedAt,
    required this.hasEnoughData,
  });

  factory DilSeCapsuleData.empty() => DilSeCapsuleData(
    totalMinutes: 0,
    totalStreams: 0,
    uniqueArtistsCount: 0,
    topArtists: const [],
    topTracks: const [],
    personaTitle: 'The Curious Pioneer',
    personaDescription:
        'Your musical story on DilSe is just beginning. Every stream you play is crafting your unique acoustic DNA.',
    personaEmoji: '🌱',
    topLanguages: const ['Hindi', 'Telugu', 'Tamil', 'English'],
    peakTimeDescription: 'Open Horizons',
    vibeScores: const {
      'Energy': 0.74,
      'Dance': 0.68,
      'Acoustic': 0.58,
      'Valence': 0.70,
    },
    generatedAt: DateTime.now(),
    hasEnoughData: false,
  );
}

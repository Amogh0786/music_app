/// Represents a JioSaavn movie or soundtrack album.
class JioAlbum {
  final String id;
  final String title;
  final String artist;
  final String artwork;
  final String year;
  final int songCount;
  final String language;
  final String type;

  /// Song list — only populated after calling [MusicService.fetchAlbumTracks].
  final List<Map<String, dynamic>> songs;

  const JioAlbum({
    required this.id,
    required this.title,
    required this.artist,
    required this.artwork,
    required this.year,
    required this.songCount,
    required this.language,
    this.type = 'album',
    this.songs = const [],
  });

  factory JioAlbum.fromJson(Map<String, dynamic> json) {
    final rawSongs = json['songs'];
    final List<Map<String, dynamic>> songs = rawSongs is List
        ? rawSongs.map((s) => Map<String, dynamic>.from(s as Map)).toList()
        : [];
    final count = json['songCount'] as int? ?? songs.length;
    final rawType =
        json['type'] as String? ?? (count <= 1 ? 'single' : 'album');
    return JioAlbum(
      id: json['id']?.toString() ?? '',
      title: json['title'] as String? ?? 'Unknown Album',
      artist: json['artist'] as String? ?? 'Various Artists',
      artwork: json['artwork'] as String? ?? '',
      year: json['year']?.toString() ?? '',
      songCount: count,
      language: (json['language'] as String? ?? '').toLowerCase(),
      type: rawType,
      songs: songs,
    );
  }

  JioAlbum copyWith({
    List<Map<String, dynamic>>? songs,
    int? songCount,
    String? type,
    String? artwork,
  }) {
    return JioAlbum(
      id: id,
      title: title,
      artist: artist,
      artwork: artwork ?? this.artwork,
      year: year,
      songCount: songCount ?? this.songCount,
      language: language,
      type: type ?? this.type,
      songs: songs ?? this.songs,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'artist': artist,
    'artwork': artwork,
    'year': year,
    'songCount': songCount,
    'language': language,
    'type': type,
    'songs': songs,
  };

  @override
  String toString() =>
      'JioAlbum($id, "$title", $year, $type, ${songs.length} songs)';
}

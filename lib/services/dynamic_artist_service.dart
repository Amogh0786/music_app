import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'preferences_service.dart';
import 'music_service.dart';
import 'playlist_artist_filter.dart';
import 'canonical_song_dedup.dart';

/// Data model representing an artist in the Search section.
class ArtistItem {
  final String name;
  final String genre;
  final String imageUrl;
  final String language;
  final String badge;
  final bool isFromUserHistory;

  const ArtistItem({
    required this.name,
    required this.genre,
    required this.imageUrl,
    required this.language,
    required this.badge,
    this.isFromUserHistory = false,
  });

  ArtistItem copyWith({
    String? name,
    String? genre,
    String? imageUrl,
    String? language,
    String? badge,
    bool? isFromUserHistory,
  }) {
    return ArtistItem(
      name: name ?? this.name,
      genre: genre ?? this.genre,
      imageUrl: imageUrl ?? this.imageUrl,
      language: language ?? this.language,
      badge: badge ?? this.badge,
      isFromUserHistory: isFromUserHistory ?? this.isFromUserHistory,
    );
  }
}

/// Service that dynamically fetches, curates, and ranks artists based on
/// user's listening habits, genre similarity, and popular artists across languages.
class DynamicArtistService {
  static final DynamicArtistService _instance =
      DynamicArtistService._internal();
  factory DynamicArtistService() => _instance;
  DynamicArtistService._internal();

  /// Runtime memory cache for dynamically fetched artist images.
  final Map<String, String> _artistImageCache = {};

  /// Pre-verified, high-resolution artist catalog with verified 500x500 CDN URLs
  /// covering diverse languages (Telugu, Tamil, Hindi, Punjabi, English, Malayalam).
  static const List<ArtistItem> _curatedCatalog = [
    // --- Telugu ---
    ArtistItem(
      name: 'Devi Sri Prasad',
      genre: 'Tollywood • Mass & Dance Beats',
      imageUrl:
          'https://cdn-images.dzcdn.net/images/artist/a904f8ee6cc4dcb472f75bd8ae1a21da/500x500-000000-80-0-0.jpg',
      language: 'Telugu',
      badge: 'TOP COMPOSER',
    ),
    ArtistItem(
      name: 'Thaman S',
      genre: 'Tollywood • EDM & Mass Grooves',
      imageUrl:
          'https://cdn-images.dzcdn.net/images/artist/f42d76b5c7e4e5dcb1afb373321f16c4/500x500-000000-80-0-0.jpg',
      language: 'Telugu',
      badge: 'BEATS KING',
    ),
    ArtistItem(
      name: 'Sid Sriram',
      genre: 'Carnatic, Melody & Soul',
      imageUrl:
          'https://cdn-images.dzcdn.net/images/artist/fbe3e1d17fc6958e047f011f74233f82/500x500-000000-80-0-0.jpg',
      language: 'Telugu',
      badge: 'SOULFUL',
    ),
    ArtistItem(
      name: 'Anurag Kulkarni',
      genre: 'Tollywood • Folk & Melodies',
      imageUrl:
          'https://cdn-images.dzcdn.net/images/artist/f9f1f4491e7efc579dff25792bbc0fd6/500x500-000000-80-0-0.jpg',
      language: 'Telugu',
      badge: 'MELODIC',
    ),
    ArtistItem(
      name: 'Ram Miriyala',
      genre: 'Telugu Indie • Folk Rock',
      imageUrl:
          'https://cdn-images.dzcdn.net/images/artist/43f399df39ffe548e7ed9b5495abf6e1/500x500-000000-80-0-0.jpg',
      language: 'Telugu',
      badge: 'INDIE HIT',
    ),
    ArtistItem(
      name: 'M.M. Keeravaani',
      genre: 'Oscar Maestro • Epic Melodies',
      imageUrl:
          'https://cdn-images.dzcdn.net/images/artist/dda61305d6a8f2953a74e5a417605237/500x500-000000-80-0-0.jpg',
      language: 'Telugu',
      badge: 'MAESTRO',
    ),
    ArtistItem(
      name: 'Mickey J Meyer',
      genre: 'Tollywood • Youthful Melodies',
      imageUrl:
          'https://cdn-images.dzcdn.net/images/artist/afaa927b76799f4b6d682e809b6cb440/500x500-000000-80-0-0.jpg',
      language: 'Telugu',
      badge: 'NOSTALGIA',
    ),

    // --- Tamil ---
    ArtistItem(
      name: 'Anirudh Ravichander',
      genre: 'Rockstar • Modern Pop & Mass',
      imageUrl:
          'https://cdn-images.dzcdn.net/images/artist/9da0a547b39e99bc35c6a9724aef91bf/500x500-000000-80-0-0.jpg',
      language: 'Tamil',
      badge: 'ROCKSTAR',
    ),
    ArtistItem(
      name: 'A.R. Rahman',
      genre: 'The Mozart of Madras • Sufi & Pop',
      imageUrl:
          'https://cdn-images.dzcdn.net/images/artist/c04a1ff9cdd57d305c51663654a21590/500x500-000000-80-0-0.jpg',
      language: 'Tamil',
      badge: 'MAESTRO',
    ),
    ArtistItem(
      name: 'Sai Abhyankkar',
      genre: 'Tamil Indie • Viral RnB & Pop',
      imageUrl:
          'https://cdn-images.dzcdn.net/images/artist/234646e93d6ab2923f3bdc363f53d330/500x500-000000-80-0-0.jpg',
      language: 'Tamil',
      badge: 'VIRAL HIT',
    ),
    ArtistItem(
      name: 'Yuvan Shankar Raja',
      genre: 'BGM King • Lo-Fi & Melancholy',
      imageUrl:
          'https://cdn-images.dzcdn.net/images/artist/1dbf7d81a2e964d9c707e53478407974/500x500-000000-80-0-0.jpg',
      language: 'Tamil',
      badge: 'VIBES',
    ),
    ArtistItem(
      name: 'Santhosh Narayanan',
      genre: 'Raw Indie • Acoustic & Folk',
      imageUrl:
          'https://cdn-images.dzcdn.net/images/artist/74004fed94dddf9ae2d7c83084eaf1ad/500x500-000000-80-0-0.jpg',
      language: 'Tamil',
      badge: 'RAW INDIE',
    ),
    ArtistItem(
      name: 'Harris Jayaraj',
      genre: 'Romantic Pop & Timeless Melodies',
      imageUrl:
          'https://cdn-images.dzcdn.net/images/artist/b10caf45eae518a2b16997874ded7143/500x500-000000-80-0-0.jpg',
      language: 'Tamil',
      badge: 'CLASSIC',
    ),

    // --- Hindi / Bollywood ---
    ArtistItem(
      name: 'Arijit Singh',
      genre: 'Bollywood • Romantic & Soul',
      imageUrl:
          'https://cdn-images.dzcdn.net/images/artist/ac5350cff290edd5b69fa584b8b1bd4f/500x500-000000-80-0-0.jpg',
      language: 'Hindi',
      badge: 'SOUL KING',
    ),
    ArtistItem(
      name: 'Pritam',
      genre: 'Bollywood • Chartbuster Anthems',
      imageUrl:
          'https://cdn-images.dzcdn.net/images/artist/d4914ccd414067cd5e2c108867079a85/500x500-000000-80-0-0.jpg',
      language: 'Hindi',
      badge: 'HITMAKER',
    ),
    ArtistItem(
      name: 'Shreya Ghoshal',
      genre: 'Bollywood • Melodious Vocals',
      imageUrl:
          'https://cdn-images.dzcdn.net/images/artist/3bb832d37d10ff2affcfa9afdc7c68a0/500x500-000000-80-0-0.jpg',
      language: 'Hindi',
      badge: 'QUEEN',
    ),
    ArtistItem(
      name: 'Badshah',
      genre: 'Desi Hip-Hop & Party Anthems',
      imageUrl:
          'https://cdn-images.dzcdn.net/images/artist/5b90b89299a7d42f81d79afa263a85d2/500x500-000000-80-0-0.jpg',
      language: 'Hindi',
      badge: 'PARTY KING',
    ),

    // --- Punjabi ---
    ArtistItem(
      name: 'Diljit Dosanjh',
      genre: 'Global Punjabi • Folk & Pop',
      imageUrl:
          'https://cdn-images.dzcdn.net/images/artist/79b85e695e0ca6529e56bf3b628e92bd/500x500-000000-80-0-0.jpg',
      language: 'Punjabi',
      badge: 'G.O.A.T',
    ),
    ArtistItem(
      name: 'Karan Aujla',
      genre: 'Punjabi Hip-Hop & Trap',
      imageUrl:
          'https://cdn-images.dzcdn.net/images/artist/a91a1d5ea91e85e4f0966569b50e8d6a/500x500-000000-80-0-0.jpg',
      language: 'Punjabi',
      badge: 'CHARTBUSTER',
    ),
    ArtistItem(
      name: 'AP Dhillon',
      genre: 'Punjabi R&B • Retro Melodies',
      imageUrl:
          'https://cdn-images.dzcdn.net/images/artist/52594ac9fa763dc163ed13d21cb130ec/500x500-000000-80-0-0.jpg',
      language: 'Punjabi',
      badge: 'RETRO WAVE',
    ),
    ArtistItem(
      name: 'Sidhu Moose Wala',
      genre: 'Punjabi Rap & Legend Folk',
      imageUrl:
          'https://cdn-images.dzcdn.net/images/artist/f559ebe3851db26a6a47a76b1d95748f/500x500-000000-80-0-0.jpg',
      language: 'Punjabi',
      badge: 'LEGEND',
    ),

    // --- Global / English ---
    ArtistItem(
      name: 'The Weeknd',
      genre: 'Dark R&B • Synth-Pop',
      imageUrl:
          'https://cdn-images.dzcdn.net/images/artist/581693b4724a7fcfa754455101e13a44/500x500-000000-80-0-0.jpg',
      language: 'English',
      badge: 'AFTER HOURS',
    ),
    ArtistItem(
      name: 'Taylor Swift',
      genre: 'Pop & Narrative Anthems',
      imageUrl:
          'https://cdn-images.dzcdn.net/images/artist/cc2495870fe1a792ad0cdb05501ad5ec/500x500-000000-80-0-0.jpg',
      language: 'English',
      badge: 'POP QUEEN',
    ),
    ArtistItem(
      name: 'Ed Sheeran',
      genre: 'Acoustic Pop & Ballads',
      imageUrl:
          'https://cdn-images.dzcdn.net/images/artist/d6bb84390641d8ae9118228d9544e53d/500x500-000000-80-0-0.jpg',
      language: 'English',
      badge: 'ACOUSTIC',
    ),
    ArtistItem(
      name: 'Dua Lipa',
      genre: 'Dance Pop & Future Nostalgia',
      imageUrl:
          'https://cdn-images.dzcdn.net/images/artist/877872aaf75694f11d53c318700ab2b5/500x500-000000-80-0-0.jpg',
      language: 'English',
      badge: 'DANCE POP',
    ),
    ArtistItem(
      name: 'Billie Eilish',
      genre: 'Alt-Pop • Dark & Soulful',
      imageUrl:
          'https://cdn-images.dzcdn.net/images/artist/8eab1a9a644889aabaca1e193e05f984/500x500-000000-80-0-0.jpg',
      language: 'English',
      badge: 'ALT POP',
    ),
    ArtistItem(
      name: 'Bruno Mars',
      genre: 'Funk, Pop & Retro Soul',
      imageUrl:
          'https://cdn-images.dzcdn.net/images/artist/90f0b5b11df4f87ee878f38569b5995b/500x500-000000-80-0-0.jpg',
      language: 'English',
      badge: '24K MAGIC',
    ),

    // --- Malayalam ---
    ArtistItem(
      name: 'Sushin Shyam',
      genre: 'Malayalam • Electronic & Indie',
      imageUrl:
          'https://cdn-images.dzcdn.net/images/artist/6ba914ca28d2c5cc21dc3effa07c690d/500x500-000000-80-0-0.jpg',
      language: 'Malayalam',
      badge: 'NEW WAVE',
    ),
  ];

  /// Canonical map to find curated items by lower-cased / normalized artist keys.
  static final Map<String, ArtistItem> _catalogByNormalized = {
    for (final a in _curatedCatalog) PlaylistArtistFilter.normalize(a.name): a,
    'dsp': _curatedCatalog.firstWhere((a) => a.name == 'Devi Sri Prasad'),
    'devi sri prasad': _curatedCatalog.firstWhere(
      (a) => a.name == 'Devi Sri Prasad',
    ),
    'anirudh': _curatedCatalog.firstWhere(
      (a) => a.name == 'Anirudh Ravichander',
    ),
    'anirudh ravichander': _curatedCatalog.firstWhere(
      (a) => a.name == 'Anirudh Ravichander',
    ),
    'sid sriram': _curatedCatalog.firstWhere((a) => a.name == 'Sid Sriram'),
    'arijit singh': _curatedCatalog.firstWhere((a) => a.name == 'Arijit Singh'),
    'ar rahman': _curatedCatalog.firstWhere((a) => a.name == 'A.R. Rahman'),
    'a r rahman': _curatedCatalog.firstWhere((a) => a.name == 'A.R. Rahman'),
    'rahman': _curatedCatalog.firstWhere((a) => a.name == 'A.R. Rahman'),
    'thaman': _curatedCatalog.firstWhere((a) => a.name == 'Thaman S'),
    's thaman': _curatedCatalog.firstWhere((a) => a.name == 'Thaman S'),
    'keeravani': _curatedCatalog.firstWhere((a) => a.name == 'M.M. Keeravaani'),
    'yuvan': _curatedCatalog.firstWhere((a) => a.name == 'Yuvan Shankar Raja'),
    'santhosh': _curatedCatalog.firstWhere(
      (a) => a.name == 'Santhosh Narayanan',
    ),
    'harris': _curatedCatalog.firstWhere((a) => a.name == 'Harris Jayaraj'),
  };

  /// Generates the dynamic list of artists tailored to the user:
  /// 1. User's top listened artists (from history, play counts, most played)
  /// 2. Genre and language-similar artists
  /// 3. Popular trending artists across diverse languages
  List<ArtistItem> getDynamicArtists() {
    final prefs = PreferencesService();
    final musicService = MusicService();

    final List<ArtistItem> result = [];
    final Set<String> addedNames = {};
    final Set<String> userLanguages = {};

    // 1. Gather artist candidates from user listening habits
    final List<String> userArtistNames = [];

    // (a) Most played artist
    if (prefs.mostPlayedArtist.isNotEmpty) {
      userArtistNames.add(prefs.mostPlayedArtist);
    }

    // (b) Top played artists ranking
    final topList = prefs.getTopPlayedArtists(limit: 15);
    for (final entry in topList) {
      if (entry.key.trim().isNotEmpty) {
        userArtistNames.add(entry.key);
      }
    }

    // (c) Most played songs list
    for (final song in prefs.mostPlayedSongs.take(15)) {
      final author = (song['author'] as String?) ?? '';
      final title = (song['title'] as String?) ?? '';
      final extracted = _extractArtists(author, title);
      userArtistNames.addAll(extracted);
    }

    // (d) Liked songs
    for (final song in musicService.likedSongs.take(15)) {
      final author = song['author'] ?? '';
      final title = song['title'] ?? '';
      final extracted = _extractArtists(author, title);
      userArtistNames.addAll(extracted);
    }

    // (e) Listening history
    for (final song in prefs.listeningHistory.reversed.take(20)) {
      final author = song['author'] ?? '';
      final title = song['title'] ?? '';
      final extracted = _extractArtists(author, title);
      userArtistNames.addAll(extracted);
    }

    // 2. Process user artists and place them first
    for (final rawArtist in userArtistNames) {
      final norm = PlaylistArtistFilter.normalize(rawArtist);
      if (norm.isEmpty || _isBlacklistedChannel(norm)) continue;

      final matchedInCatalog = _catalogByNormalized[norm];
      final canonicalName =
          matchedInCatalog?.name ?? _formatArtistName(rawArtist);
      final key = canonicalName.toLowerCase();

      if (addedNames.contains(key)) continue;

      if (matchedInCatalog != null) {
        userLanguages.add(matchedInCatalog.language);
        result.add(
          matchedInCatalog.copyWith(
            isFromUserHistory: true,
            badge: 'TOP ARTIST',
          ),
        );
      } else {
        // Dynamic artist from user history not in static catalog
        final cachedImg = _artistImageCache[key];
        final artistItem = ArtistItem(
          name: canonicalName,
          genre: 'Most Played • Fan Favorite',
          imageUrl: cachedImg ?? _generateAvatarPlaceholder(canonicalName),
          language: 'For You',
          badge: 'TOP ARTIST',
          isFromUserHistory: true,
        );
        result.add(artistItem);

        // Fetch image in background if not cached yet
        if (cachedImg == null) {
          _fetchArtistImageAsync(canonicalName);
        }
      }
      addedNames.add(key);
    }

    // 3. Add genre/language-similar artists based on detected user languages
    if (userLanguages.isNotEmpty) {
      for (final artist in _curatedCatalog) {
        final key = artist.name.toLowerCase();
        if (addedNames.contains(key)) continue;

        if (userLanguages.contains(artist.language)) {
          result.add(artist.copyWith(badge: 'FOR YOU'));
          addedNames.add(key);
        }
      }
    }

    // 4. Fill with popular artists of all languages to guarantee variety
    for (final artist in _curatedCatalog) {
      final key = artist.name.toLowerCase();
      if (!addedNames.contains(key)) {
        result.add(artist);
        addedNames.add(key);
      }
    }

    return result;
  }

  /// Extracts genuine artist names from song author & title
  static List<String> _extractArtists(String author, String title) {
    final extracted = PlaylistArtistFilter.extractArtistsFromSong({
      'author': author,
      'title': title,
    });
    if (extracted.isNotEmpty) return extracted;

    final cleaned = CanonicalSongDedup.cleanArtist(author);
    if (cleaned.isNotEmpty) return [cleaned];

    if (author.trim().isNotEmpty) return [author.trim()];
    return [];
  }

  static bool _isBlacklistedChannel(String norm) {
    return norm == 'aditya music' ||
        norm == 'tseries' ||
        norm == 't-series' ||
        norm == 'sony music' ||
        norm == 'zee music' ||
        norm == 'speed audio' ||
        norm == 'saregama' ||
        norm == 'lahari music' ||
        norm == 'tips official';
  }

  static String _formatArtistName(String raw) {
    final words = raw.trim().split(RegExp(r'\s+'));
    return words
        .map((w) {
          if (w.isEmpty) return '';
          return '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}';
        })
        .join(' ');
  }

  static String _generateAvatarPlaceholder(String name) {
    final encoded = Uri.encodeComponent(name);
    return 'https://ui-avatars.com/api/?name=$encoded&background=1E1E2C&color=fff&size=512&bold=true';
  }

  /// Background fetch for unknown artist Deezer CDN image
  Future<void> _fetchArtistImageAsync(String artistName) async {
    final key = artistName.toLowerCase();
    if (_artistImageCache.containsKey(key)) return;

    try {
      final url = Uri.parse(
        'https://api.deezer.com/search/artist?q=${Uri.encodeComponent(artistName)}&limit=1',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final items = data['data'] as List<dynamic>?;
        if (items != null && items.isNotEmpty) {
          final first = items.first as Map<String, dynamic>;
          final img =
              (first['picture_big'] ?? first['picture_medium']) as String?;
          if (img != null && img.isNotEmpty && !img.contains('//500x500')) {
            _artistImageCache[key] = img;
          }
        }
      }
    } catch (e) {
      debugPrint(
        '[DynamicArtistService] Image fetch error for $artistName: $e',
      );
    }
  }
}

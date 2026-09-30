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
          'https://c.saavncdn.com/artists/M__M__Keeravani_002_20240129101710_500x500.webp',
      language: 'Telugu',
      badge: 'MAESTRO',
    ),
    ArtistItem(
      name: 'Mickey J Meyer',
      genre: 'Tollywood • Youthful Melodies',
      imageUrl: 'https://c.saavncdn.com/artists/Mickey_J_Meyer_500x500.webp',
      language: 'Telugu',
      badge: 'NOSTALGIA',
    ),
    ArtistItem(
      name: 'S.P. Balasubrahmanyam',
      genre: 'Legendary Maestro • Evergreen',
      imageUrl:
          'https://c.saavncdn.com/artists/S_P_Balasubrahmanyam_500x500.webp',
      language: 'Telugu',
      badge: 'LEGEND',
    ),
    ArtistItem(
      name: 'K.S. Chithra',
      genre: 'Melody Queen of India',
      imageUrl:
          'https://c.saavncdn.com/artists/K_S_Chithra_002_20190906071921_500x500.webp',
      language: 'Telugu',
      badge: 'QUEEN',
    ),
    ArtistItem(
      name: 'Mangli',
      genre: 'Folk Anthems & High Energy',
      imageUrl:
          'https://c.saavncdn.com/artists/Mangli_Satyavathi_001_20240701121028_500x500.webp',
      language: 'Telugu',
      badge: 'FOLK QUEEN',
    ),
    ArtistItem(
      name: 'Sunitha',
      genre: 'Tollywood • Timeless Melodies',
      imageUrl:
          'https://c.saavncdn.com/artists/Sunitha_Upadrashta_003_20240424064243_500x500.webp',
      language: 'Telugu',
      badge: 'MELODY',
    ),
    ArtistItem(
      name: 'Karthik',
      genre: 'Soulful Vocals & Romantic Hits',
      imageUrl: 'https://c.saavncdn.com/artists/Karthik_500x500.webp',
      language: 'Telugu',
      badge: 'ROMANTIC',
    ),
    ArtistItem(
      name: 'Haricharan',
      genre: 'Carnatic & Film Melodies',
      imageUrl: 'https://c.saavncdn.com/artists/Haricharan_500x500.webp',
      language: 'Telugu',
      badge: 'SOULFUL',
    ),

    // --- Tamil ---
    ArtistItem(
      name: 'Anirudh Ravichander',
      genre: 'Rockstar • Modern Pop & Mass',
      imageUrl:
          'https://c.saavncdn.com/artists/Anirudh_Ravichander_003_20260121134149_500x500.webp',
      language: 'Tamil',
      badge: 'ROCKSTAR',
    ),
    ArtistItem(
      name: 'A.R. Rahman',
      genre: 'The Mozart of Madras • Sufi & Pop',
      imageUrl:
          'https://c.saavncdn.com/artists/AR_Rahman_002_20210120084455_500x500.webp',
      language: 'Tamil',
      badge: 'MAESTRO',
    ),
    ArtistItem(
      name: 'Sai Abhyankkar',
      genre: 'Tamil Indie • Viral RnB & Pop',
      imageUrl:
          'https://c.saavncdn.com/artists/Sai_Abhyankkar_003_20250707122433_500x500.webp',
      language: 'Tamil',
      badge: 'VIRAL HIT',
    ),
    ArtistItem(
      name: 'Yuvan Shankar Raja',
      genre: 'BGM King • Lo-Fi & Melancholy',
      imageUrl:
          'https://c.saavncdn.com/artists/Yuvan_Shankar_Raja_002_20180802174245_500x500.webp',
      language: 'Tamil',
      badge: 'VIBES',
    ),
    ArtistItem(
      name: 'Santhosh Narayanan',
      genre: 'Raw Indie • Acoustic & Folk',
      imageUrl:
          'https://c.saavncdn.com/artists/Santhosh_Narayanan_002_20250527101718_500x500.webp',
      language: 'Tamil',
      badge: 'RAW INDIE',
    ),
    ArtistItem(
      name: 'Harris Jayaraj',
      genre: 'Romantic Pop & Timeless Melodies',
      imageUrl:
          'https://c.saavncdn.com/artists/Harris_Jayaraj_002_20230718071330_500x500.webp',
      language: 'Tamil',
      badge: 'CLASSIC',
    ),
    ArtistItem(
      name: 'Ilaiyaraaja',
      genre: 'Isaignani • Timeless Orchestrations',
      imageUrl:
          'https://c.saavncdn.com/artists/Ilaiyaraaja_001_20251020081419_500x500.webp',
      language: 'Tamil',
      badge: 'MAESTRO',
    ),
    ArtistItem(
      name: 'G.V. Prakash Kumar',
      genre: 'Acoustic Folk & Chartbusters',
      imageUrl:
          'https://c.saavncdn.com/artists/G_V__Prakash_Kumar_003_20251113063655_500x500.webp',
      language: 'Tamil',
      badge: 'HITMAKER',
    ),

    // --- Hindi / Bollywood ---
    ArtistItem(
      name: 'Arijit Singh',
      genre: 'Bollywood • Romantic & Soul',
      imageUrl:
          'https://c.saavncdn.com/artists/Arijit_Singh_004_20241118063717_500x500.webp',
      language: 'Hindi',
      badge: 'SOUL KING',
    ),
    ArtistItem(
      name: 'Pritam',
      genre: 'Bollywood • Chartbuster Anthems',
      imageUrl:
          'https://c.saavncdn.com/artists/Pritam_Chakraborty-20170711073326_500x500.webp',
      language: 'Hindi',
      badge: 'HITMAKER',
    ),
    ArtistItem(
      name: 'Shreya Ghoshal',
      genre: 'Bollywood • Melodious Vocals',
      imageUrl:
          'https://c.saavncdn.com/artists/Shreya_Ghoshal_007_20241101074144_500x500.webp',
      language: 'Hindi',
      badge: 'QUEEN',
    ),
    ArtistItem(
      name: 'Badshah',
      genre: 'Desi Hip-Hop & Party Anthems',
      imageUrl:
          'https://c.saavncdn.com/artists/Badshah_006_20241118064015_500x500.webp',
      language: 'Hindi',
      badge: 'PARTY KING',
    ),
    ArtistItem(
      name: 'Atif Aslam',
      genre: 'Sufi Rock & Soulful Ballads',
      imageUrl:
          'https://cdn-images.dzcdn.net/images/artist/0ea90444148fff9c11d77f06a344724e/500x500-000000-80-0-0.jpg',
      language: 'Hindi',
      badge: 'SOULFUL',
    ),
    ArtistItem(
      name: 'Sonu Nigam',
      genre: 'Golden Voice • Evergreen Romantic',
      imageUrl:
          'https://c.saavncdn.com/artists/Sonu_Nigam_003_20260813182013_500x500.webp',
      language: 'Hindi',
      badge: 'LEGEND',
    ),
    ArtistItem(
      name: 'Shankar Mahadevan',
      genre: 'Breathless • Fusion & Classical',
      imageUrl: 'https://c.saavncdn.com/artists/Shankar_Mahadevan_500x500.webp',
      language: 'Hindi',
      badge: 'VIRTUOSO',
    ),
    ArtistItem(
      name: 'Armaan Malik',
      genre: 'Prince of Romance • Pop Ballads',
      imageUrl:
          'https://c.saavncdn.com/artists/Armaan_Malik_006_20260813132832_500x500.webp',
      language: 'Hindi',
      badge: 'POP PRINCE',
    ),
    ArtistItem(
      name: 'Neha Kakkar',
      genre: 'Peppy Party Hits & Pop',
      imageUrl:
          'https://c.saavncdn.com/artists/Neha_Kakkar_007_20241212115832_500x500.webp',
      language: 'Hindi',
      badge: 'PARTY POP',
    ),
    ArtistItem(
      name: 'Jubin Nautiyal',
      genre: 'Soulful Melodies & Devotional',
      imageUrl:
          'https://c.saavncdn.com/artists/Jubin_Nautiyal_003_20231130204020_500x500.webp',
      language: 'Hindi',
      badge: 'DEVOTION',
    ),

    // --- Punjabi ---
    ArtistItem(
      name: 'Diljit Dosanjh',
      genre: 'Global Punjabi • Folk & Pop',
      imageUrl:
          'https://c.saavncdn.com/artists/Diljit_Dosanjh_005_20231025073054_500x500.webp',
      language: 'Punjabi',
      badge: 'G.O.A.T',
    ),
    ArtistItem(
      name: 'Karan Aujla',
      genre: 'Punjabi Hip-Hop & Trap',
      imageUrl:
          'https://c.saavncdn.com/artists/Karan_Aujla_005_20260925061936_500x500.webp',
      language: 'Punjabi',
      badge: 'CHARTBUSTER',
    ),
    ArtistItem(
      name: 'AP Dhillon',
      genre: 'Punjabi R&B • Retro Melodies',
      imageUrl:
          'https://c.saavncdn.com/artists/AP_Dhillon_004_20251023102150_500x500.jpg',
      language: 'Punjabi',
      badge: 'RETRO WAVE',
    ),
    ArtistItem(
      name: 'Sidhu Moose Wala',
      genre: 'Punjabi Rap & Legend Folk',
      imageUrl:
          'https://c.saavncdn.com/artists/Sidhu_Moose_Wala_004_20250617183705_500x500.webp',
      language: 'Punjabi',
      badge: 'LEGEND',
    ),
    ArtistItem(
      name: 'Guru Randhawa',
      genre: 'High Rated Punjabi Pop',
      imageUrl:
          'https://c.saavncdn.com/artists/Guru_Randhawa_004_20250701125845_500x500.webp',
      language: 'Punjabi',
      badge: 'POP HIT',
    ),

    // --- Malayalam ---
    ArtistItem(
      name: 'Sushin Shyam',
      genre: 'Malayalam • Electronic & Indie',
      imageUrl:
          'https://c.saavncdn.com/artists/Sushin_Shyam_002_20250707125538_500x500.webp',
      language: 'Malayalam',
      badge: 'NEW WAVE',
    ),
    ArtistItem(
      name: 'K.J. Yesudas',
      genre: 'Celestial Voice • Classical Legend',
      imageUrl: 'https://c.saavncdn.com/artists/KJ_Yesudas_500x500.webp',
      language: 'Malayalam',
      badge: 'LEGEND',
    ),
    ArtistItem(
      name: 'Hesham Abdul Wahab',
      genre: 'Soulful Malayalam Indie & Melodies',
      imageUrl:
          'https://c.saavncdn.com/artists/Hesham_Abdul_Wahab_001_20220919094035_500x500.webp',
      language: 'Malayalam',
      badge: 'SOULFUL',
    ),

    // --- Global / English ---
    ArtistItem(
      name: 'The Weeknd',
      genre: 'Dark R&B • Synth-Pop',
      imageUrl:
          'https://c.saavncdn.com/artists/The_Weeknd_002_20241003071400_500x500.webp',
      language: 'English',
      badge: 'AFTER HOURS',
    ),
    ArtistItem(
      name: 'Taylor Swift',
      genre: 'Pop & Narrative Anthems',
      imageUrl:
          'https://c.saavncdn.com/artists/Taylor_Swift_003_20200226074119_500x500.webp',
      language: 'English',
      badge: 'POP QUEEN',
    ),
    ArtistItem(
      name: 'Ed Sheeran',
      genre: 'Acoustic Pop & Ballads',
      imageUrl:
          'https://c.saavncdn.com/artists/Ed_Sheeran_002_20250625073038_500x500.webp',
      language: 'English',
      badge: 'ACOUSTIC',
    ),
    ArtistItem(
      name: 'Dua Lipa',
      genre: 'Dance Pop & Future Nostalgia',
      imageUrl:
          'https://c.saavncdn.com/artists/Dua_Lipa_004_20231120090922_500x500.webp',
      language: 'English',
      badge: 'DANCE POP',
    ),
    ArtistItem(
      name: 'Billie Eilish',
      genre: 'Alt-Pop • Dark & Soulful',
      imageUrl:
          'https://c.saavncdn.com/artists/Billie_Eilish_20190211151539_500x500.webp',
      language: 'English',
      badge: 'ALT POP',
    ),
    ArtistItem(
      name: 'Bruno Mars',
      genre: 'Funk, Pop & Retro Soul',
      imageUrl:
          'https://c.saavncdn.com/artists/Bruno_Mars_003_20260324060413_500x500.webp',
      language: 'English',
      badge: '24K MAGIC',
    ),
  ];

  /// Canonical map to find curated items by lower-cased / normalized artist keys.
  static final Map<String, ArtistItem> _catalogByNormalized = {
    for (final a in _curatedCatalog) PlaylistArtistFilter.normalize(a.name): a,
    // Telugu Aliases
    'dsp': _curatedCatalog.firstWhere((a) => a.name == 'Devi Sri Prasad'),
    'devi sri prasad': _curatedCatalog.firstWhere(
      (a) => a.name == 'Devi Sri Prasad',
    ),
    'thaman': _curatedCatalog.firstWhere((a) => a.name == 'Thaman S'),
    's thaman': _curatedCatalog.firstWhere((a) => a.name == 'Thaman S'),
    'thaman s': _curatedCatalog.firstWhere((a) => a.name == 'Thaman S'),
    'sid sriram': _curatedCatalog.firstWhere((a) => a.name == 'Sid Sriram'),
    'anurag kulkarni': _curatedCatalog.firstWhere(
      (a) => a.name == 'Anurag Kulkarni',
    ),
    'ram miriyala': _curatedCatalog.firstWhere((a) => a.name == 'Ram Miriyala'),
    'keeravani': _curatedCatalog.firstWhere((a) => a.name == 'M.M. Keeravaani'),
    'm m keeravani': _curatedCatalog.firstWhere(
      (a) => a.name == 'M.M. Keeravaani',
    ),
    'mm keeravaani': _curatedCatalog.firstWhere(
      (a) => a.name == 'M.M. Keeravaani',
    ),
    'm.m. keeravaani': _curatedCatalog.firstWhere(
      (a) => a.name == 'M.M. Keeravaani',
    ),
    'mickey j meyer': _curatedCatalog.firstWhere(
      (a) => a.name == 'Mickey J Meyer',
    ),
    'spb': _curatedCatalog.firstWhere((a) => a.name == 'S.P. Balasubrahmanyam'),
    's p balasubrahmanyam': _curatedCatalog.firstWhere(
      (a) => a.name == 'S.P. Balasubrahmanyam',
    ),
    's.p. balasubrahmanyam': _curatedCatalog.firstWhere(
      (a) => a.name == 'S.P. Balasubrahmanyam',
    ),
    'balasubrahmanyam': _curatedCatalog.firstWhere(
      (a) => a.name == 'S.P. Balasubrahmanyam',
    ),
    'chithra': _curatedCatalog.firstWhere((a) => a.name == 'K.S. Chithra'),
    'k s chithra': _curatedCatalog.firstWhere((a) => a.name == 'K.S. Chithra'),
    'k.s. chithra': _curatedCatalog.firstWhere((a) => a.name == 'K.S. Chithra'),
    'mangli': _curatedCatalog.firstWhere((a) => a.name == 'Mangli'),
    'sunitha': _curatedCatalog.firstWhere((a) => a.name == 'Sunitha'),
    'karthik': _curatedCatalog.firstWhere((a) => a.name == 'Karthik'),
    'haricharan': _curatedCatalog.firstWhere((a) => a.name == 'Haricharan'),

    // Tamil Aliases
    'anirudh': _curatedCatalog.firstWhere(
      (a) => a.name == 'Anirudh Ravichander',
    ),
    'anirudh ravichander': _curatedCatalog.firstWhere(
      (a) => a.name == 'Anirudh Ravichander',
    ),
    'ar rahman': _curatedCatalog.firstWhere((a) => a.name == 'A.R. Rahman'),
    'a r rahman': _curatedCatalog.firstWhere((a) => a.name == 'A.R. Rahman'),
    'a.r. rahman': _curatedCatalog.firstWhere((a) => a.name == 'A.R. Rahman'),
    'rahman': _curatedCatalog.firstWhere((a) => a.name == 'A.R. Rahman'),
    'sai abhyankkar': _curatedCatalog.firstWhere(
      (a) => a.name == 'Sai Abhyankkar',
    ),
    'yuvan': _curatedCatalog.firstWhere((a) => a.name == 'Yuvan Shankar Raja'),
    'yuvan shankar raja': _curatedCatalog.firstWhere(
      (a) => a.name == 'Yuvan Shankar Raja',
    ),
    'santhosh': _curatedCatalog.firstWhere(
      (a) => a.name == 'Santhosh Narayanan',
    ),
    'santhosh narayanan': _curatedCatalog.firstWhere(
      (a) => a.name == 'Santhosh Narayanan',
    ),
    'harris': _curatedCatalog.firstWhere((a) => a.name == 'Harris Jayaraj'),
    'harris jayaraj': _curatedCatalog.firstWhere(
      (a) => a.name == 'Harris Jayaraj',
    ),
    'ilaiyaraaja': _curatedCatalog.firstWhere((a) => a.name == 'Ilaiyaraaja'),
    'ilayaraja': _curatedCatalog.firstWhere((a) => a.name == 'Ilaiyaraaja'),
    'gv prakash': _curatedCatalog.firstWhere(
      (a) => a.name == 'G.V. Prakash Kumar',
    ),
    'g.v. prakash kumar': _curatedCatalog.firstWhere(
      (a) => a.name == 'G.V. Prakash Kumar',
    ),

    // Hindi Aliases
    'arijit singh': _curatedCatalog.firstWhere((a) => a.name == 'Arijit Singh'),
    'pritam': _curatedCatalog.firstWhere((a) => a.name == 'Pritam'),
    'shreya ghoshal': _curatedCatalog.firstWhere(
      (a) => a.name == 'Shreya Ghoshal',
    ),
    'badshah': _curatedCatalog.firstWhere((a) => a.name == 'Badshah'),
    'atif aslam': _curatedCatalog.firstWhere((a) => a.name == 'Atif Aslam'),
    'sonu nigam': _curatedCatalog.firstWhere((a) => a.name == 'Sonu Nigam'),
    'shankar mahadevan': _curatedCatalog.firstWhere(
      (a) => a.name == 'Shankar Mahadevan',
    ),
    'armaan malik': _curatedCatalog.firstWhere((a) => a.name == 'Armaan Malik'),
    'neha kakkar': _curatedCatalog.firstWhere((a) => a.name == 'Neha Kakkar'),
    'jubin nautiyal': _curatedCatalog.firstWhere(
      (a) => a.name == 'Jubin Nautiyal',
    ),

    // Punjabi Aliases
    'diljit dosanjh': _curatedCatalog.firstWhere(
      (a) => a.name == 'Diljit Dosanjh',
    ),
    'karan aujla': _curatedCatalog.firstWhere((a) => a.name == 'Karan Aujla'),
    'ap dhillon': _curatedCatalog.firstWhere((a) => a.name == 'AP Dhillon'),
    'sidhu moose wala': _curatedCatalog.firstWhere(
      (a) => a.name == 'Sidhu Moose Wala',
    ),
    'guru randhawa': _curatedCatalog.firstWhere(
      (a) => a.name == 'Guru Randhawa',
    ),

    // Malayalam Aliases
    'sushin shyam': _curatedCatalog.firstWhere((a) => a.name == 'Sushin Shyam'),
    'kj yesudas': _curatedCatalog.firstWhere((a) => a.name == 'K.J. Yesudas'),
    'k.j. yesudas': _curatedCatalog.firstWhere((a) => a.name == 'K.J. Yesudas'),
    'hesham abdul wahab': _curatedCatalog.firstWhere(
      (a) => a.name == 'Hesham Abdul Wahab',
    ),

    // Global
    'the weeknd': _curatedCatalog.firstWhere((a) => a.name == 'The Weeknd'),
    'taylor swift': _curatedCatalog.firstWhere((a) => a.name == 'Taylor Swift'),
    'ed sheeran': _curatedCatalog.firstWhere((a) => a.name == 'Ed Sheeran'),
    'dua lipa': _curatedCatalog.firstWhere((a) => a.name == 'Dua Lipa'),
    'billie eilish': _curatedCatalog.firstWhere(
      (a) => a.name == 'Billie Eilish',
    ),
    'bruno mars': _curatedCatalog.firstWhere((a) => a.name == 'Bruno Mars'),
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
      if (norm.isEmpty || !_isValidArtistName(rawArtist)) continue;

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

        // Safely fetch verified image in background if not cached yet
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
    if (extracted.isNotEmpty) {
      return extracted.where(_isValidArtistName).toList();
    }

    final cleaned = CanonicalSongDedup.cleanArtist(author);
    if (cleaned.isNotEmpty && _isValidArtistName(cleaned)) {
      return [cleaned];
    }

    if (author.trim().isNotEmpty && _isValidArtistName(author)) {
      return [author.trim()];
    }
    return [];
  }

  static bool _isValidArtistName(String raw) {
    final s = raw.trim();
    if (s.length < 3 || s.length > 35) return false;

    final lower = s.toLowerCase();
    if (_isBlacklistedChannel(lower)) return false;

    // Reject non-artist keywords, record labels, and common video/soundtrack tokens
    const nonArtistTokens = [
      'aditya',
      't-series',
      'tseries',
      'sony music',
      'zee music',
      'speed audio',
      'saregama',
      'lahari music',
      'tips official',
      'geetha arts',
      'mythri',
      'annapurna',
      'suresh productions',
      'mango music',
      'madhura',
      'think music',
      'muzik247',
      'svcc',
      'sithara',
      'dvv',
      'entertainment',
      'records',
      'productions',
      'company',
      'channel',
      'jukebox',
      'mashup',
      'lyrical',
      'video song',
      'official song',
      'full song',
      'remix',
      'promo',
      'teaser',
      'trailer',
      'cover song',
      'karaoke',
      'theme',
      'title track',
      '(from',
      'from "',
      'feat.',
      'ft.',
    ];

    for (final token in nonArtistTokens) {
      if (lower.contains(token)) return false;
    }

    return true;
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

  /// Background fetch for unknown artist from JioSaavn official catalog
  Future<void> _fetchArtistImageAsync(String artistName) async {
    final key = artistName.toLowerCase();
    if (_artistImageCache.containsKey(key)) return;

    try {
      final url = Uri.parse(
        'https://www.jiosaavn.com/api.php?__call=search.getArtistResults&_format=json&cc=in&api_version=4&ctx=android&q=${Uri.encodeComponent(artistName)}',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final items = data['results'] as List<dynamic>?;
        if (items != null && items.isNotEmpty) {
          final first = items.first as Map<String, dynamic>;
          final returnedName = (first['name'] as String? ?? '').toLowerCase();
          // Check that the returned artist name actually matches our search query
          if (returnedName.contains(key) || key.contains(returnedName)) {
            final rawImg = first['image'] as String?;
            if (rawImg != null &&
                rawImg.contains('c.saavncdn.com/artists/') &&
                !rawImg.contains('artist-default')) {
              final img = rawImg
                  .replaceAll('50x50', '500x500')
                  .replaceAll('150x150', '500x500');
              _artistImageCache[key] = img;
            }
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

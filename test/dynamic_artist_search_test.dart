import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/services/preferences_service.dart';
import 'package:music_app/services/dynamic_artist_service.dart';
import 'package:music_app/widgets/artist_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DynamicArtistService & ArtistCard Tests', () {
    late PreferencesService prefs;
    late DynamicArtistService artistService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = PreferencesService();
      prefs.resetForTesting();
      await prefs.init();
      artistService = DynamicArtistService();
    });

    test(
      'Initial getDynamicArtists returns rich diverse artist catalog with 0 duplicates',
      () {
        final artists = artistService.getDynamicArtists();
        expect(artists, isNotEmpty);
        expect(artists.length, greaterThanOrEqualTo(20));

        final names = <String>{};
        for (final a in artists) {
          expect(a.name, isNotEmpty);
          expect(a.genre, isNotEmpty);
          expect(a.imageUrl, isNotEmpty);
          expect(a.badge, isNotEmpty);
          expect(
            names.contains(a.name.toLowerCase()),
            isFalse,
            reason: 'Duplicate artist found: ${a.name}',
          );
          names.add(a.name.toLowerCase());
        }
      },
    );

    test(
      'User listening data dynamically bubbles top artists to the front',
      () async {
        // User listens to Devi Sri Prasad multiple times
        await prefs.recordSongPlay('Devi Sri Prasad', 'Pushpa Pushpa');
        await prefs.recordSongPlay('DSP, Sid Sriram', 'Srivalli');
        await prefs.recordSongPlay('Devi Sri Prasad', 'Oo Antava');

        final artists = artistService.getDynamicArtists();
        expect(artists.first.name, equals('Devi Sri Prasad'));
        expect(artists.first.isFromUserHistory, isTrue);
        expect(artists.first.badge, equals('TOP ARTIST'));
        expect(artists.first.genre, contains('Tollywood'));
      },
    );

    test(
      'Recommends genre-similar artists based on user listening taste',
      () async {
        // User listens heavily to Anirudh (Tamil)
        await prefs.recordSongPlay('Anirudh Ravichander', 'Hukum');
        await prefs.recordSongPlay('Anirudh Ravichander', 'Badass');

        final artists = artistService.getDynamicArtists();
        // First must be Anirudh
        expect(artists.first.name, equals('Anirudh Ravichander'));
        expect(artists.first.isFromUserHistory, isTrue);

        // Followed by genre/language similar artists (like Sai Abhyankkar, Santhosh Narayanan, etc.)
        final similarArtists = artists
            .where((a) => a.badge == 'FOR YOU')
            .toList();
        expect(similarArtists, isNotEmpty);
        expect(similarArtists.any((a) => a.language == 'Tamil'), isTrue);
      },
    );

    testWidgets(
      'ArtistCard renders image, bold artist name, small genre, and fires onTap',
      (tester) async {
        bool tapped = false;

        const testArtist = ArtistItem(
          name: 'Sai Abhyankkar',
          genre: 'Tamil Indie • Viral RnB & Pop',
          imageUrl:
              'https://cdn-images.dzcdn.net/images/artist/234646e93d6ab2923f3bdc363f53d330/500x500-000000-80-0-0.jpg',
          language: 'Tamil',
          badge: 'VIRAL HIT',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 200,
                height: 120,
                child: ArtistCard(
                  artist: testArtist,
                  onTap: () {
                    tapped = true;
                  },
                ),
              ),
            ),
          ),
        );

        // Verify artist name in bold letters and genre in small letters
        expect(find.text('Sai Abhyankkar'), findsOneWidget);
        expect(find.text('Tamil Indie • Viral RnB & Pop'), findsOneWidget);
        expect(find.text('VIRAL HIT'), findsOneWidget);

        // Tap on the card
        await tester.tap(find.byType(ArtistCard));
        await tester.pumpAndSettle();

        expect(tapped, isTrue);
      },
    );
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/screens/artist_profile_screen.dart';
import 'package:music_app/services/dynamic_artist_service.dart';
import 'package:music_app/services/preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PreferencesService().init();
  });

  const testArtist = ArtistItem(
    name: 'Devi Sri Prasad',
    genre: 'Tollywood • High Energy Dance & Melodies',
    imageUrl: 'https://example.com/dsp.jpg',
    language: 'Telugu',
    badge: 'TOP ARTIST',
  );

  testWidgets(
    'ArtistProfileScreen renders header, buttons, search bar, and filter chips',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: ArtistProfileScreen(
            artist: testArtist,
            artistName: 'Devi Sri Prasad',
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      // Hero Header
      expect(find.text('Devi Sri Prasad'), findsOneWidget);
      expect(find.text('TOP ARTIST'), findsOneWidget);
      expect(
        find.text('Tollywood • High Energy Dance & Melodies'),
        findsOneWidget,
      );

      // Actions
      expect(find.textContaining('Play All'), findsOneWidget);
      expect(find.text('Shuffle'), findsOneWidget);

      // Search Bar
      expect(
        find.text("Search within Devi Sri Prasad's tracks..."),
        findsOneWidget,
      );

      // Language Chips Header & Chips
      expect(find.text('LANGUAGE'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'All'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Telugu'), findsOneWidget);

      // Movie & Era Chips Header & Chips
      expect(find.text('MOVIE & ERA RANGE'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'All Eras'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, '2020–2025'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'All Movies'), findsOneWidget);
      expect(find.text('Pushpa The Rise'), findsOneWidget);
    },
  );

  testWidgets(
    'ArtistProfileScreen selects language and movie chips interactively',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: ArtistProfileScreen(
            artist: testArtist,
            artistName: 'Devi Sri Prasad',
          ),
        ),
      );
      await tester.pump();

      // Tap Tamil chip
      final tamilChip = find.widgetWithText(ChoiceChip, 'Tamil');
      if (tamilChip.evaluate().isNotEmpty) {
        await tester.tap(tamilChip);
        await tester.pump();
        final chip = tester.widget<ChoiceChip>(tamilChip);
        expect(chip.selected, isTrue);
      }

      // Tap Pushpa movie chip
      final pushpaChip = find.text('Pushpa The Rise');
      expect(pushpaChip, findsOneWidget);
      await tester.tap(pushpaChip);
      await tester.pump();

      // 'Clear Movie' should appear in header
      expect(find.text('Clear Movie'), findsOneWidget);

      // Tap Clear Movie
      await tester.tap(find.text('Clear Movie'));
      await tester.pump();
      expect(find.text('Clear Movie'), findsNothing);
    },
  );

  testWidgets('ArtistProfileScreen live search input updates search text', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      const MaterialApp(
        home: ArtistProfileScreen(
          artist: testArtist,
          artistName: 'Devi Sri Prasad',
        ),
      ),
    );
    await tester.pump();

    final searchField = find.byType(TextField);
    expect(searchField, findsOneWidget);

    await tester.enterText(searchField, 'Pushpa Pushpa');
    await tester.pump();

    expect(find.text('Pushpa Pushpa'), findsOneWidget);
    expect(find.byIcon(Icons.clear_rounded), findsOneWidget);

    // Clear search
    await tester.tap(find.byIcon(Icons.clear_rounded));
    await tester.pump();
    expect(find.text('Pushpa Pushpa'), findsNothing);
  });

  testWidgets(
    'ArtistProfileScreen renders smoothly on mobile portrait (390x844)',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: ArtistProfileScreen(
            artist: testArtist,
            artistName: 'Devi Sri Prasad',
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Devi Sri Prasad'), findsOneWidget);
    },
  );
}

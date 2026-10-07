import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/models/dilse_capsule_data.dart';
import 'package:music_app/screens/dilse_capsule_screen.dart';
import 'package:music_app/services/capsule_service.dart';
import 'package:music_app/services/preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Crash Prevention & Edge Case Rigorous Suite', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      FlutterError.onError = (details) {
        FlutterError.dumpErrorToConsole(details);
      };
    });

    test(
      'CapsuleService handles heavily corrupted or null data without throwing',
      () {
        final prefs = PreferencesService();
        final service = CapsuleService();

        // Corrupted items with empty strings and invalid formats
        prefs.listeningHistory.addAll([
          {'id': '', 'title': '', 'author': '', 'playedAt': 'NOT_A_DATE'},
          {
            'id': 'valid_1',
            'title': 'Valid Song',
            'author': 'Valid Artist',
            'playedAt': '2026-10-07T03:00:00Z',
          },
        ]);

        prefs.mostPlayedSongs.addAll([
          {'id': '', 'playCount': -5, 'lastPlayedAt': 'INVALID'},
          {
            'id': 'mp_1',
            'title': 'MP Song',
            'author': 'MP Artist',
            'playCount': 100,
            'lastPlayedAt': '2026-10-07T14:30:00Z',
          },
        ]);

        final capsule = service.buildCapsuleData(prefs);
        expect(capsule, isNotNull);
        expect(capsule.totalStreams, greaterThanOrEqualTo(0));
        expect(capsule.totalMinutes, greaterThanOrEqualTo(0));
        expect(capsule.topTracks.isNotEmpty, isTrue);
        expect(capsule.topArtists.isNotEmpty, isTrue);
      },
    );

    testWidgets(
      'DilSeCapsuleScreen renders without layout overflow on ultra-narrow 320px screen',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final extremeData = DilSeCapsuleData(
          totalMinutes: 999999,
          totalStreams: 88888,
          uniqueArtistsCount: 500,
          topArtists: const [
            CapsuleArtist(
              name:
                  'Extremely Long Artist Name That Could Potentially Cause An Overflow If Not Properly Clamped Or Elided',
              playCount: 5000,
              percentage: 65.5,
            ),
            CapsuleArtist(
              name:
                  'Another Very Long Artist Co-Author Collaboration Studio Ensemble',
              playCount: 2000,
              percentage: 25.0,
            ),
          ],
          topTracks: const [
            CapsuleTrack(
              id: 'long_1',
              title:
                  'Extremely Long Track Title That Extends Beyond Normal Mobile Device Viewport Boundaries',
              author:
                  'Extremely Long Artist Name That Could Potentially Cause An Overflow',
              thumbnail: '',
              playCount: 1200,
            ),
          ],
          personaTitle: 'The Multi-Hyphenate Chronotype Explorer',
          personaDescription:
              'A very detailed multi-sentence description that spans multiple lines across a very narrow mobile screen.',
          personaEmoji: '🌌',
          topLanguages: const [
            'Telugu',
            'Hindi',
            'Tamil',
            'Kannada',
            'Malayalam',
            'English',
          ],
          peakTimeDescription: 'Late Night (11 PM – 5 AM)',
          vibeScores: const {
            'Energy': 0.95,
            'Dance': 0.88,
            'Acoustic': 0.12,
            'Valence': 0.77,
          },
          generatedAt: DateTime.now(),
          hasEnoughData: true,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: DilSeCapsuleScreen(
              initialData: extremeData,
              autoAdvance: false,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Slide 0 Intro
        expect(find.text('DILSE CAPSULE'), findsOneWidget);
        expect(tester.takeException(), isNull);

        // Slide 1 Tracks
        await tester.tapAt(const Offset(280, 300));
        await tester.pumpAndSettle();
        expect(find.text('Your Top Tracks'), findsOneWidget);
        expect(tester.takeException(), isNull);

        // Slide 2 Artists
        await tester.tapAt(const Offset(280, 300));
        await tester.pumpAndSettle();
        expect(find.text('Artists Who Moved You'), findsOneWidget);
        expect(tester.takeException(), isNull);

        // Slide 3 Persona
        await tester.tapAt(const Offset(280, 300));
        await tester.pumpAndSettle();
        expect(
          find.text('The Multi-Hyphenate Chronotype Explorer'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);

        // Slide 4 Grand Card
        await tester.tapAt(const Offset(280, 300));
        await tester.pumpAndSettle();
        expect(find.text('Save Card'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'DilSeCapsuleScreen renders smoothly with completely empty data (brand new user)',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final emptyData = DilSeCapsuleData.empty();

        await tester.pumpWidget(
          MaterialApp(
            home: DilSeCapsuleScreen(
              initialData: emptyData,
              autoAdvance: false,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Slide 0 Intro
        expect(find.text('DILSE CAPSULE'), findsOneWidget);
        expect(find.text('0'), findsNWidgets(2)); // 0 Minutes, 0 Streams

        // Slide 1 Empty Tracks
        await tester.tapAt(const Offset(350, 400));
        await tester.pumpAndSettle();
        expect(
          find.text('Play tracks to see your top songs ranked here!'),
          findsOneWidget,
        );

        // Slide 2 Empty Artists
        await tester.tapAt(const Offset(350, 400));
        await tester.pumpAndSettle();
        expect(
          find.text('Stream music to discover your artist affinity!'),
          findsOneWidget,
        );

        // Slide 3 Empty Persona
        await tester.tapAt(const Offset(350, 400));
        await tester.pumpAndSettle();
        expect(find.text('The Curious Pioneer'), findsOneWidget);

        // Slide 4 Grand Card
        await tester.tapAt(const Offset(350, 400));
        await tester.pumpAndSettle();
        expect(find.text('Exploring new rhythms...'), findsOneWidget);
        expect(find.text('First tracks incoming...'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'DilSeCapsuleScreen handles rapid forward and backward scrubbing without crashes',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final testData = CapsuleService().buildCapsuleData(
          PreferencesService(),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: DilSeCapsuleScreen(initialData: testData, autoAdvance: false),
          ),
        );
        await tester.pumpAndSettle();

        // Step forward through all slides and beyond
        for (int i = 0; i < 6; i++) {
          await tester.tapAt(const Offset(350, 400));
          await tester.pumpAndSettle();
        }
        expect(find.text('Save Card'), findsOneWidget);

        // Step backward through all slides and beyond
        for (int i = 0; i < 6; i++) {
          await tester.tapAt(const Offset(40, 400));
          await tester.pumpAndSettle();
        }
        expect(find.text('DILSE CAPSULE'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}

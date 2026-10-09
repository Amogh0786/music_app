import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/screens/profile_screen.dart';
import 'package:music_app/screens/settings_screen.dart';
import 'package:music_app/screens/dilse_capsule_screen.dart';
import 'package:music_app/services/preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'userName': 'Tejassxo',
      'realPlaybackCountsJson': json.encode({
        'Anuv Jain': 34,
        'The Weeknd': 26,
        'Coke Studio Bharat': 14,
        'Other Artist': 16,
      }),
      'mostPlayedSongsJson': json.encode({
        'test_song_1': {
          'id': 'test_song_1',
          'title': 'Husn',
          'author': 'Anuv Jain',
          'thumbnail': 'https://example.com/husn.jpg',
          'playCount': 22,
          'lastPlayedAt': DateTime.now().toIso8601String(),
        },
        'test_song_2': {
          'id': 'test_song_2',
          'title': 'Blinding Lights',
          'author': 'The Weeknd',
          'thumbnail': 'https://example.com/blinding.jpg',
          'playCount': 18,
          'lastPlayedAt': DateTime.now().toIso8601String(),
        },
      }),
      'listeningHistoryJson': json.encode([
        {
          'id': 'test_song_1',
          'title': 'Husn',
          'author': 'Anuv Jain',
          'thumbnail': 'https://example.com/husn.jpg',
        },
      ]),
    });
    await PreferencesService().init();
  });

  group('ProfileScreen Spotify-grade Widget Tests', () {
    testWidgets('Renders Spotify-style hero header and metadata on Desktop', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(const MaterialApp(home: ProfileScreen()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // Hero Header
      expect(find.text('PROFILE'), findsOneWidget);
      expect(find.text('Tejassxo'), findsOneWidget);
      expect(find.textContaining('Streams'), findsOneWidget);

      // Action Bar Buttons
      expect(find.text('Your DilSe Capsule'), findsOneWidget);
      expect(find.text('READY'), findsOneWidget);
      expect(find.text('Edit Profile'), findsOneWidget);

      // Listening Highlights Bar
      expect(find.text('Total Plays'), findsOneWidget);
      expect(find.text('90'), findsOneWidget);
      expect(find.text('Liked Songs'), findsOneWidget);
      expect(find.text('Offline Music'), findsOneWidget);
      expect(find.text('Top Artist'), findsOneWidget);
      expect(find.text('Anuv Jain'), findsWidgets);

      // Top Artists Section
      expect(find.text('Top artists this month'), findsOneWidget);
      expect(find.text('Live Sync'), findsOneWidget);
      expect(find.text('The Weeknd'), findsWidgets);
      expect(find.text('#1'), findsOneWidget);

      // Top Tracks Section
      expect(find.text('Top tracks this month'), findsOneWidget);
      expect(find.text('Husn'), findsWidgets);
      expect(find.text('Blinding Lights'), findsOneWidget);
      expect(find.textContaining('Play All'), findsOneWidget);
      expect(find.text('Shuffle'), findsOneWidget);

      // Settings Tile
      expect(find.text('Player & Audio Preferences'), findsOneWidget);
    });

    testWidgets('Renders on mobile size (390x844) without overflow', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(const MaterialApp(home: ProfileScreen()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Tejassxo'), findsOneWidget);
      expect(find.text('Total Plays'), findsOneWidget);
      expect(find.text('Your DilSe Capsule'), findsOneWidget);
    });

    testWidgets('Tapping Settings opens SettingsScreen', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(const MaterialApp(home: ProfileScreen()));
      await tester.pumpAndSettle();

      final settingsBtn = find.byTooltip('Settings & Preferences');
      expect(settingsBtn, findsOneWidget);
      await tester.tap(settingsBtn);
      await tester.pumpAndSettle();

      expect(find.byType(SettingsScreen), findsOneWidget);
    });

    testWidgets('Tapping Capsule button opens DilSeCapsuleScreen', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(const MaterialApp(home: ProfileScreen()));
      await tester.pumpAndSettle();

      final capsuleBtn = find.text('Your DilSe Capsule');
      expect(capsuleBtn, findsOneWidget);
      await tester.tap(capsuleBtn);
      await tester.pumpAndSettle();

      expect(find.byType(DilSeCapsuleScreen), findsOneWidget);
    });
  });
}

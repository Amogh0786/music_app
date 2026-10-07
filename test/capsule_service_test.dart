import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:music_app/services/preferences_service.dart';
import 'package:music_app/services/capsule_service.dart';
import 'package:music_app/models/dilse_capsule_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PreferencesService().init();
    await PreferencesService().clearListeningHistory();
    await PreferencesService().clearMostPlayedSongs();
  });

  group('CapsuleService Tests', () {
    test('buildCapsuleData returns valid fallback for brand new user', () {
      final service = CapsuleService();
      final data = service.buildCapsuleData();

      expect(data, isA<DilSeCapsuleData>());
      expect(data.totalMinutes, equals(0));
      expect(data.totalStreams, equals(0));
      expect(data.personaTitle, equals('The Curious Pioneer'));
      expect(data.personaEmoji, equals('🌱'));
      expect(data.vibeScores, isNotEmpty);
      expect(data.vibeScores.containsKey('Energy'), isTrue);
      expect(data.hasEnoughData, isFalse);
    });

    test(
      'buildCapsuleData accurately computes top tracks and artists',
      () async {
        final prefs = PreferencesService();

        // Record multiple song plays
        await prefs.recordSongPlay('Arijit Singh', 'Tum Hi Ho');
        await prefs.recordSongPlay('Arijit Singh', 'Kesariya');
        await prefs.recordSongPlay('Anirudh Ravichander', 'Hukum');

        final service = CapsuleService();
        final data = service.buildCapsuleData(prefs);

        expect(data.totalStreams, greaterThanOrEqualTo(3));
        expect(data.totalMinutes, greaterThan(0));
        expect(data.topArtists, isNotEmpty);
        expect(data.topArtists.first.name, contains('Arijit'));
        expect(data.hasEnoughData, isTrue);
      },
    );

    test(
      'buildCapsuleData determines Devoted Purist when single artist dominates',
      () async {
        final prefs = PreferencesService();

        // Heavily play single artist
        for (int i = 0; i < 10; i++) {
          await prefs.recordSongPlay('A.R. Rahman', 'Jai Ho $i');
        }

        final service = CapsuleService();
        final data = service.buildCapsuleData(prefs);

        expect(data.topArtists.first.name, equals('A.R. Rahman'));
        expect(data.topArtists.first.percentage, greaterThanOrEqualTo(40.0));
        expect(data.personaTitle, equals('The Devoted Purist'));
        expect(data.personaEmoji, equals('🔥'));
      },
    );
  });
}

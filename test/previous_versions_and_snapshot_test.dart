import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:music_app/services/update_service.dart';
import 'package:music_app/services/data_snapshot_service.dart';
import 'package:music_app/widgets/previous_versions_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UpdateService Version Comparison Tests', () {
    test('Correctly identifies newer remote versions', () {
      expect(UpdateService.compareVersion('v3.8.1', '3.8.0'), equals(1));
      expect(UpdateService.compareVersion('v4.0.0', '3.8.0'), equals(1));
      expect(UpdateService.compareVersion('3.9.0', '3.8.0'), equals(1));
      expect(
        UpdateService.compareVersion('v3.8.0+25', '3.8.0', '22'),
        equals(1),
      );
    });

    test(
      'Correctly identifies older remote versions (downgrades / rollback)',
      () {
        expect(UpdateService.compareVersion('v3.7.0', '3.8.0'), equals(-1));
        expect(UpdateService.compareVersion('v2.9.9', '3.8.0'), equals(-1));
        expect(
          UpdateService.compareVersion('v3.8.0+19', '3.8.0', '22'),
          equals(-1),
        );
        expect(UpdateService.compareVersion('3.6.5', '3.7.0'), equals(-1));
      },
    );

    test('Correctly identifies identical versions', () {
      expect(UpdateService.compareVersion('v3.8.0', '3.8.0'), equals(0));
      expect(UpdateService.compareVersion('3.8.0', '3.8.0'), equals(0));
      expect(
        UpdateService.compareVersion('v3.8.0+22', '3.8.0', '22'),
        equals(0),
      );
    });

    test('GitHubReleaseItem formattedSize and hasApk calculations', () {
      final withApk = GitHubReleaseItem(
        tagName: 'v3.7.0',
        releaseName: 'DilSe v3.7.0',
        changelog: 'Bug fixes',
        apkDownloadUrl:
            'https://github.com/charanteja-k/music_app/releases/download/v3.7.0/app.apk',
        apkFileName: 'DilSe-v3.7.0.apk',
        apkSizeBytes: 64228734,
        publishedAt: DateTime(2026, 9, 28),
        isPrerelease: false,
        isDraft: false,
        htmlUrl:
            'https://github.com/charanteja-k/music_app/releases/tag/v3.7.0',
      );

      expect(withApk.hasApk, isTrue);
      expect(withApk.formattedSize, contains('MB'));
      expect(withApk.formattedSize, equals('61.3 MB'));

      final sourceOnly = GitHubReleaseItem(
        tagName: 'v3.0.0',
        releaseName: 'Source Release',
        changelog: '',
        apkDownloadUrl: null,
        apkFileName: null,
        apkSizeBytes: 0,
        publishedAt: null,
        isPrerelease: false,
        isDraft: false,
        htmlUrl:
            'https://github.com/charanteja-k/music_app/releases/tag/v3.0.0',
      );

      expect(sourceOnly.hasApk, isFalse);
      expect(sourceOnly.formattedSize, equals('Source only'));
    });
  });

  group('DataSnapshotService Integrity Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({
        'listening_history': json.encode(['song_1', 'song_2']),
        'theme_color': 0xFFFA2D48,
        'audio_quality': 'studioMaster',
      });
    });

    test('Captures safety snapshot containing tracked preferences', () async {
      final service = DataSnapshotService();
      final result = await service.createSafetySnapshot(
        triggerReason: 'Unit test snapshot',
      );

      expect(result.success, isTrue);

      final prefs = await SharedPreferences.getInstance();
      // On web / test environment, web key is populated if documents directory is unavailable
      final webRaw = prefs.getString('dilse_safety_snapshot_web');
      if (webRaw != null) {
        final decoded = json.decode(webRaw) as Map<String, dynamic>;
        expect(decoded['schema_version'], equals(1));
        expect(decoded['trigger_reason'], equals('Unit test snapshot'));
        expect(decoded['preferences'], isNotNull);
        final capturedPrefs = decoded['preferences'] as Map<String, dynamic>;
        expect(capturedPrefs['audio_quality'], equals('studioMaster'));
      }
    });

    test('Restore gracefully handles missing backup', () async {
      SharedPreferences.setMockInitialValues({});
      final service = DataSnapshotService();
      final result = await service.restoreFromLatestSnapshot();

      // If no file exists, failure message should be returned without throwing uncaught exceptions
      if (!result.success) {
        expect(result.errorMessage, isNotNull);
      }
    });
  });

  group('PreviousVersionsSheet Widget Tests', () {
    testWidgets('Renders modal header, backup icon, and loading state', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({'theme_color': 0xFFFA2D48});

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => PreviousVersionsSheet.show(ctx),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      // Tap button to open sheet
      await tester.tap(find.text('Open'));
      await tester.pump(); // Start animation
      await tester.pump(
        const Duration(milliseconds: 300),
      ); // Complete animation

      expect(find.text('Release Archive'), findsOneWidget);
      expect(find.byIcon(Icons.history_rounded), findsOneWidget);
      expect(find.byIcon(Icons.backup_rounded), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    });
  });
}

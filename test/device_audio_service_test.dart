import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/services/device_audio_service.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DeviceAudioService ID Generation Tests', () {
    test(
      'generateLocalId produces strictly 11-char string valid for VideoId',
      () {
        final samplePaths = [
          '/storage/emulated/0/Music/Coldplay - Yellow.mp3',
          '/storage/emulated/0/Download/track01.flac',
          'C:\\Users\\User\\Music\\song with spaces and symbols #1 (2024).m4a',
          '/data/user/0/com.example.music_app/cache/sample.wav',
          'a',
        ];

        final videoIdRegex = RegExp(r'^[a-zA-Z0-9_-]{11}$');

        for (final path in samplePaths) {
          final id = DeviceAudioService.generateLocalId(path);
          expect(
            id.length,
            equals(11),
            reason: 'ID for $path must be 11 characters',
          );
          expect(
            videoIdRegex.hasMatch(id),
            isTrue,
            reason: 'ID $id must match VideoId format',
          );

          // Verify VideoId doesn't throw
          expect(() => VideoId(id), returnsNormally);
        }
      },
    );

    test('generateLocalId is deterministic for identical paths', () {
      const path = '/storage/emulated/0/Music/A.R. Rahman - Urvashi.mp3';
      final id1 = DeviceAudioService.generateLocalId(path);
      final id2 = DeviceAudioService.generateLocalId(path);
      expect(id1, equals(id2));
    });

    test('generateLocalId differentiates distinct paths', () {
      const path1 = '/storage/emulated/0/Music/SongA.mp3';
      const path2 = '/storage/emulated/0/Music/SongB.mp3';
      final id1 = DeviceAudioService.generateLocalId(path1);
      final id2 = DeviceAudioService.generateLocalId(path2);
      expect(id1, isNot(equals(id2)));
    });
  });

  group('AudioTagParser Heuristics Tests', () {
    test(
      'parseFile falls back to filename splitting when tags absent',
      () async {
        // Create a temporary empty file named with Artist - Title format
        final tempDir = await Directory.systemTemp.createTemp('dilse_test_');
        final tempFile = File('${tempDir.path}/Anirudh - Hukum.mp3');
        await tempFile.writeAsBytes([0, 0, 0, 0]);

        final parsed = await AudioTagParser.parseFile(tempFile, 'test_id');
        expect(parsed.artist, equals('Anirudh'));
        expect(parsed.title, equals('Hukum'));

        await tempDir.delete(recursive: true);
      },
    );

    test('parseFile cleans track numbers from filename', () async {
      final tempDir = await Directory.systemTemp.createTemp('dilse_test_');
      final tempFile = File(
        '${tempDir.path}/01. Sid Sriram - Samajavaragamana.flac',
      );
      await tempFile.writeAsBytes([0, 0, 0, 0]);

      final parsed = await AudioTagParser.parseFile(tempFile, 'test_id');
      expect(parsed.artist, equals('Sid Sriram'));
      expect(parsed.title, equals('Samajavaragamana'));

      await tempDir.delete(recursive: true);
    });

    test('parseFile handles files without artist delimiter', () async {
      final tempDir = await Directory.systemTemp.createTemp('dilse_test_');
      final tempFile = File('${tempDir.path}/Midnight_Memories.m4a');
      await tempFile.writeAsBytes([0, 0, 0, 0]);

      final parsed = await AudioTagParser.parseFile(tempFile, 'test_id');
      expect(parsed.title, equals('Midnight_Memories'));
      expect(parsed.artist, equals('Device Audio'));

      await tempDir.delete(recursive: true);
    });
  });

  group('DeviceAudioService Catalog Manipulation Tests', () {
    test('getSongById finds indexed track or returns null', () {
      final service = DeviceAudioService();
      expect(service.getSongById('non_existent_id'), isNull);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/services/preferences_service.dart';
import 'package:music_app/services/music_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Audio Engine & Formats Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      PreferencesService().resetForTesting();
    });

    test('AudioQualityPreset enum extensions provide accurate metadata', () {
      expect(AudioQualityPreset.studioMaster.label, 'Studio Master (320 kbps)');
      expect(AudioQualityPreset.studioMaster.shortLabel, '320 kbps');
      expect(AudioQualityPreset.studioMaster.badge, '320K');
      expect(AudioQualityPreset.studioMaster.approxBitrate, 320);

      expect(AudioQualityPreset.high.label, 'High Fidelity (160 kbps)');
      expect(AudioQualityPreset.high.shortLabel, '160 kbps');
      expect(AudioQualityPreset.high.badge, '160K');
      expect(AudioQualityPreset.high.approxBitrate, 160);

      expect(AudioQualityPreset.balanced.label, 'Balanced (128 kbps)');
      expect(AudioQualityPreset.balanced.shortLabel, '128 kbps');
      expect(AudioQualityPreset.balanced.badge, '128K');
      expect(AudioQualityPreset.balanced.approxBitrate, 128);

      expect(AudioQualityPreset.dataSaver.label, 'Data Saver (64 kbps)');
      expect(AudioQualityPreset.dataSaver.shortLabel, '64 kbps');
      expect(AudioQualityPreset.dataSaver.badge, '64K');
      expect(AudioQualityPreset.dataSaver.approxBitrate, 64);
    });

    test('AudioFormatPreference enum extensions provide accurate metadata', () {
      expect(AudioFormatPreference.auto.label, 'Auto (Smart Engine)');
      expect(AudioFormatPreference.auto.shortLabel, 'Auto');
      expect(AudioFormatPreference.auto.badge, 'AUTO');

      expect(AudioFormatPreference.opus.label, 'Opus (WebM Audio)');
      expect(AudioFormatPreference.opus.shortLabel, 'Opus');
      expect(AudioFormatPreference.opus.badge, 'OPUS');

      expect(AudioFormatPreference.aac.label, 'AAC (MP4 / Apple Core)');
      expect(AudioFormatPreference.aac.shortLabel, 'AAC');
      expect(AudioFormatPreference.aac.badge, 'AAC');

      expect(AudioFormatPreference.mp3.label, 'MP3 (Direct Audio)');
      expect(AudioFormatPreference.mp3.shortLabel, 'MP3');
      expect(AudioFormatPreference.mp3.badge, 'MP3');
    });

    test('PreferencesService persists and updates AudioQualityPreset & AudioFormatPreference', () async {
      SharedPreferences.setMockInitialValues({
        'audioQualityPreset': 'studioMaster',
        'audioFormatPreference': 'opus',
      });

      final prefs = PreferencesService();
      await prefs.init();

      expect(prefs.audioQuality, AudioQualityPreset.studioMaster);
      expect(prefs.audioFormat, AudioFormatPreference.opus);

      await prefs.setAudioQuality(AudioQualityPreset.dataSaver);
      expect(prefs.audioQuality, AudioQualityPreset.dataSaver);

      final sp = await SharedPreferences.getInstance();
      expect(sp.getString('audioQualityPreset'), 'dataSaver');

      await prefs.setAudioFormat(AudioFormatPreference.aac);
      expect(prefs.audioFormat, AudioFormatPreference.aac);
      expect(sp.getString('audioFormatPreference'), 'aac');
    });

    test('MusicService.adaptJioSaavnBitrate adapts JioSaavn CDN bitrate according to quality preset', () {
      const jioSaavnSampleUrl =
          'https://aac.saavncdn.com/123/sample_song_hash_160.mp4';
      const nonJioSaavnUrl =
          'https://rr4---sn-ab5sznzs.googlevideo.com/videoplayback?expire=123';

      // Studio Master -> _320.mp4
      final studioUrl = MusicService.adaptJioSaavnBitrate(
        jioSaavnSampleUrl,
        AudioQualityPreset.studioMaster,
      );
      expect(studioUrl, 'https://aac.saavncdn.com/123/sample_song_hash_320.mp4');

      // High -> _160.mp4
      final highUrl = MusicService.adaptJioSaavnBitrate(
        studioUrl,
        AudioQualityPreset.high,
      );
      expect(highUrl, 'https://aac.saavncdn.com/123/sample_song_hash_160.mp4');

      // Balanced -> _160.mp4
      final balancedUrl = MusicService.adaptJioSaavnBitrate(
        studioUrl,
        AudioQualityPreset.balanced,
      );
      expect(balancedUrl, 'https://aac.saavncdn.com/123/sample_song_hash_160.mp4');

      // Data Saver -> _48.mp4
      final dataSaverUrl = MusicService.adaptJioSaavnBitrate(
        studioUrl,
        AudioQualityPreset.dataSaver,
      );
      expect(dataSaverUrl, 'https://aac.saavncdn.com/123/sample_song_hash_48.mp4');

      // Non-JioSaavn URLs must not be modified
      final unmodifiedUrl = MusicService.adaptJioSaavnBitrate(
        nonJioSaavnUrl,
        AudioQualityPreset.studioMaster,
      );
      expect(unmodifiedUrl, nonJioSaavnUrl);
    });

    test('ActiveStreamInfo computes correct displayTag across sources and codecs', () {
      const jioSaavn320 = ActiveStreamInfo(
        format: 'AAC (.mp4)',
        qualityLabel: '320 kbps (Studio Master)',
        source: 'JioSaavn Studio CDN',
      );
      expect(jioSaavn320.displayTag, '320 KBPS');

      const jioSaavn160 = ActiveStreamInfo(
        format: 'AAC (.mp4)',
        qualityLabel: '160 kbps (High Fidelity)',
        source: 'JioSaavn Studio CDN',
      );
      expect(jioSaavn160.displayTag, '160 KBPS');

      const ytOpus = ActiveStreamInfo(
        format: 'Opus (.webm)',
        qualityLabel: '160 kbps',
        source: 'YouTube Direct Audio',
        tag: 251,
      );
      expect(ytOpus.displayTag, 'OPUS 160K');

      const ytAacHd = ActiveStreamInfo(
        format: 'AAC (.mp4)',
        qualityLabel: '192 kbps',
        source: 'YouTube Direct Audio',
        tag: 22,
        isHd: true,
      );
      expect(ytAacHd.displayTag, 'AAC HD');

      const ytAac140 = ActiveStreamInfo(
        format: 'AAC (.mp4)',
        qualityLabel: '128 kbps',
        source: 'YouTube Direct Audio',
        tag: 140,
      );
      expect(ytAac140.displayTag, 'AAC 128K');

      const offline = ActiveStreamInfo(
        format: 'AAC (.m4a)',
        qualityLabel: 'Offline Local File',
        source: 'Offline Storage',
      );
      expect(offline.displayTag, 'OFFLINE');
    });
  });
}

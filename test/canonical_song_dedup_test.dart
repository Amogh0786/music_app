import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/services/canonical_song_dedup.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

void main() {
  group('CanonicalSongDedup Tests', () {
    test('Cleans noisy YouTube titles accurately', () {
      const noisyTitle1 = 'Kesariya - Brahmāstra | Ranbir | Alia | Pritam | Arijit Singh | Full Song 4K';
      final clean1 = CanonicalSongDedup.cleanTitle(noisyTitle1);
      expect(clean1, equals('kesariya'));

      const noisyTitle2 = 'Tum Hi Ho (Official Video) [4K] - Aashiqui 2';
      final clean2 = CanonicalSongDedup.cleanTitle(noisyTitle2);
      expect(clean2, equals('tum hi ho'));

      const cleanJioTitle = 'Kesariya';
      final cleanJio = CanonicalSongDedup.cleanTitle(cleanJioTitle);
      expect(cleanJio, equals('kesariya'));
    });

    test('Detects duplicate songs across JioSaavn and YouTube', () {
      final isDup = CanonicalSongDedup.areDuplicateSongs(
        titleA: 'Kesariya',
        artistA: 'Pritam, Arijit Singh',
        titleB: 'Kesariya - Brahmāstra | Ranbir | Alia | Pritam | Arijit Singh | Full Song 4K',
        artistB: 'Sony Music India',
      );
      expect(isDup, isTrue);

      final isNotDup = CanonicalSongDedup.areDuplicateSongs(
        titleA: 'Kesariya',
        artistA: 'Arijit Singh',
        titleB: 'Channa Mereya',
        artistB: 'Arijit Singh',
      );
      expect(isNotDup, isFalse);
    });

    test('Deduplicates a mixed list of JioSaavn and YouTube songs', () {
      final jioSong = Video(
        VideoId('rjkrTnma000'),
        'Kesariya',
        'Pritam, Arijit Singh',
        ChannelId('UC0WP5P-fwGlLyO4yOE76T8g'),
        DateTime.now(),
        '',
        null,
        '',
        const Duration(minutes: 4),
        ThumbnailSet('rjkrTnma000'),
        null,
        Engagement(0, null, null),
        false,
      );

      final ytDupSong = Video(
        VideoId('BddP6PYo2gs'),
        'Kesariya - Brahmāstra | Ranbir | Alia | Pritam | Arijit Singh | Full Song 4K',
        'Sony Music India',
        ChannelId('UC0WP5P-fwGlLyO4yOE76T8g'),
        DateTime.now(),
        '',
        null,
        '',
        const Duration(minutes: 4, seconds: 28),
        ThumbnailSet('BddP6PYo2gs'),
        null,
        Engagement(0, null, null),
        false,
      );

      final distinctYtSong = Video(
        VideoId('ElZfdU54Cp8'),
        'Apna Bana Le',
        'Arijit Singh',
        ChannelId('UC0WP5P-fwGlLyO4yOE76T8g'),
        DateTime.now(),
        '',
        null,
        '',
        const Duration(minutes: 4, seconds: 20),
        ThumbnailSet('ElZfdU54Cp8'),
        null,
        Engagement(0, null, null),
        false,
      );

      final deduped = CanonicalSongDedup.deduplicateList(
        [jioSong],
        [ytDupSong, distinctYtSong],
      );

      expect(deduped.length, equals(1));
      expect(deduped.first.id.value, equals('ElZfdU54Cp8'));
    });

    test('Balances artist distribution across the queue', () {
      Video makeSong(String id, String artist) => Video(
            VideoId(id.padRight(11, '0')),
            'Track $id',
            artist,
            ChannelId('UC0WP5P-fwGlLyO4yOE76T8g'),
            DateTime.now(),
            '',
            null,
            '',
            const Duration(minutes: 3),
            ThumbnailSet(id.padRight(11, '0')),
            null,
            Engagement(0, null, null),
            false,
          );

      final clustered = [
        makeSong('1', 'Arijit Singh'),
        makeSong('2', 'Arijit Singh'),
        makeSong('3', 'Arijit Singh'),
        makeSong('4', 'Anirudh'),
        makeSong('5', 'Anirudh'),
        makeSong('6', 'Diljit'),
      ];

      final balanced = CanonicalSongDedup.balanceArtistDistribution(clustered);
      expect(balanced.length, equals(6));
      // First song is Arijit, second should NOT be Arijit!
      expect(balanced[0].author, equals('Arijit Singh'));
      expect(balanced[1].author, isNot(equals('Arijit Singh')));
    });

    test('Rejects non-music videos (speeches, dance clips, cricket themes, teasers)', () {
      Video makeVideo(String id, String title, String author, {Duration? duration}) => Video(
            VideoId(id.padRight(11, '0')),
            title,
            author,
            ChannelId('UC0WP5P-fwGlLyO4yOE76T8g'),
            DateTime.now(),
            '',
            null,
            '',
            duration ?? const Duration(minutes: 3, seconds: 30),
            ThumbnailSet(id.padRight(11, '0')),
            null,
            Engagement(0, null, null),
            false,
          );

      // Real cases from the screenshot
      final speechVideo = makeVideo(
        'speech1',
        'Lyricist Sri Harsha Emani Speech @ Suttamla Soosi Song Launch Event',
        'Shreyas Media',
      );
      expect(CanonicalSongDedup.isGenuineSong(speechVideo), isFalse);

      final danceVideo = makeVideo(
        'dance1',
        'Anand Deverakonda & Vaishnavi Chaitanya Dances to Sanchaame Song',
        'GR Lyrics',
      );
      expect(CanonicalSongDedup.isGenuineSong(danceVideo), isFalse);

      final cricketVideo = makeVideo(
        'cricket1',
        'Shreyas Iyer Cricket Theme',
        'Kamaal',
      );
      expect(CanonicalSongDedup.isGenuineSong(cricketVideo), isFalse);

      final teaserVideo = makeVideo(
        'teaser1',
        'Nagabandham Official Teaser 4K',
        'NIK Studios',
        duration: const Duration(seconds: 45), // Too short!
      );
      expect(CanonicalSongDedup.isGenuineSong(teaserVideo), isFalse);

      final interviewVideo = makeVideo(
        'interview1',
        'Director Exclusive Interview with Telugu FilmNagar',
        'Telugu FilmNagar',
      );
      expect(CanonicalSongDedup.isGenuineSong(interviewVideo), isFalse);

      // Authentic music tracks MUST pass
      final realSong1 = makeVideo(
        'song1',
        'Namo Re (From "Nagabandham") (Telugu)',
        'Sindhuja Srinivasan, Aishwarya Daruri',
      );
      expect(CanonicalSongDedup.isGenuineSong(realSong1), isTrue);

      final realSong2 = makeVideo(
        'song2',
        'Veera Naga (From "Nagabandham")',
        'Deepak Blue',
      );
      expect(CanonicalSongDedup.isGenuineSong(realSong2), isTrue);

      final realSong3 = makeVideo(
        'song3',
        'Adhento Gaani Vunnapaatuga',
        'Anirudh Ravichander',
      );
      expect(CanonicalSongDedup.isGenuineSong(realSong3), isTrue);
    });

    test('cleanArtist strips media houses, lyrics channels, and studios', () {
      expect(CanonicalSongDedup.cleanArtist('Shreyas Media'), equals(''));
      expect(CanonicalSongDedup.cleanArtist('Tips Telugu'), equals(''));
      expect(CanonicalSongDedup.cleanArtist('GR Lyrics'), equals(''));
      expect(CanonicalSongDedup.cleanArtist('NIK Studios'), equals(''));
      expect(CanonicalSongDedup.cleanArtist('Abhishek Pictures'), equals(''));
      expect(CanonicalSongDedup.cleanArtist('Telugu FilmNagar'), equals(''));
      expect(CanonicalSongDedup.cleanArtist('Sindhuja Srinivasan'), equals('sindhuja srinivasan'));
      expect(CanonicalSongDedup.cleanArtist('Anirudh Ravichander'), equals('anirudh ravichander'));
    });

    test('Validates language compatibility across tracks', () {
      expect(CanonicalSongDedup.detectLanguage('Namo Re (From "Nagabandham") (Telugu)'), equals('telugu'));
      expect(CanonicalSongDedup.detectLanguage('Kamaal Kari Jaane O (Punjabi)'), equals('punjabi'));
      expect(CanonicalSongDedup.detectLanguage('Kesariya (Hindi)'), equals('hindi'));

      // Telugu seed rejects Punjabi track
      expect(
        CanonicalSongDedup.isLanguageCompatible('telugu', 'Kamaal Kari Jaane O (Punjabi)'),
        isFalse,
      );
      // Telugu seed accepts Telugu track
      expect(
        CanonicalSongDedup.isLanguageCompatible('telugu', 'Veera Naga (Telugu)'),
        isTrue,
      );
      // Telugu seed accepts unlabelled tracks
      expect(
        CanonicalSongDedup.isLanguageCompatible('telugu', 'Adhento Gaani Vunnapaatuga'),
        isTrue,
      );
    });

    test('Contradictory artists with identical song titles are not duplicates', () {
      final isDup = CanonicalSongDedup.areDuplicateSongs(
        titleA: 'Starboy',
        artistA: 'The Weeknd',
        titleB: 'Starboy',
        artistB: 'ZZang KARAOKE',
      );
      expect(isDup, isFalse);

      final isDupCover = CanonicalSongDedup.areDuplicateSongs(
        titleA: 'Blinding Lights',
        artistA: 'The Weeknd',
        titleB: 'Blinding Lights',
        artistB: 'Boostereo',
      );
      expect(isDupCover, isFalse);

      final isGenuineDup = CanonicalSongDedup.areDuplicateSongs(
        titleA: 'Blinding Lights',
        artistA: 'The Weeknd',
        titleB: 'Blinding Lights',
        artistB: 'The Weeknd, Daft Punk',
      );
      expect(isGenuineDup, isTrue);
    });

    test('Unicode script detection detects Indian scripts with high accuracy', () {
      expect(CanonicalSongDedup.detectScript('నిను చూస్తూ ఉంటె కన్నులు రెండు తిప్పేస్తావే'), equals('telugu'));
      expect(CanonicalSongDedup.detectScript('நான் பாக்குறேன் பாக்குறேன் பாக்காம நீ எங்க போற?'), equals('tamil'));
      expect(CanonicalSongDedup.detectScript('എൻ കൺമണി, കൺമണി കണ്ണുകളെന്നെ കാണുന്നില്ലേ?'), equals('malayalam'));
      expect(CanonicalSongDedup.detectScript('मुझको इतना बताए कोई'), equals('hindi'));
      expect(CanonicalSongDedup.detectScript('ನಿನ ನೋಡುವುದಾದರೆ ಕಣ್ಣಿನ ನೋಟ'), equals('kannada'));
      expect(CanonicalSongDedup.detectScript('This is an English sentence without Indian scripts'), isNull);
    });

    test('scoreLyricsCandidate strictly rejects cross-language dubs and accepts genuine lyrics', () {
      final teluguSongTitle = 'Srivalli';
      final teluguSongArtist = 'Sid Sriram';

      // Candidate 1: Malayalam dub lyrics
      final malayalamCandidate = {
        'id': 101,
        'trackName': 'Srivalli (From "Pushpa - The Rise")',
        'artistName': 'Sid Sriram',
        'albumName': 'Soulful Hits Of Sid Sriram',
        'duration': 221.0,
        'syncedLyrics': '[00:22.01] എൻ കൺമണി, കൺമണി കണ്ണുകളെന്നെ കാണുന്നില്ലേ?\n[00:28.00] ...',
      };

      // Candidate 2: Tamil dub lyrics
      final tamilCandidate = {
        'id': 102,
        'trackName': 'Srivalli',
        'artistName': 'Sid Sriram',
        'albumName': 'Srivalli (From "Pushpa - The Rise Part - 01 ")',
        'duration': 221.0,
        'syncedLyrics': '[00:22.23] நான் பாக்குறேன் பாக்குறேன் பாக்காம நீ எங்க போற?\n[00:28.00] ...',
      };

      // Candidate 3: Hindi dub candidate with [Hindi] tag
      final hindiCandidate = {
        'id': 103,
        'trackName': 'Srivalli - Hindi',
        'artistName': 'Javed Ali',
        'albumName': 'Pushpa - The Rise [Hindi]',
        'duration': 224.0,
        'syncedLyrics': '[00:22.68] नज़रें मिलते ही नज़रों से नज़रों को चुराए\n[00:28.00] ...',
      };

      // Candidate 4: Genuine Telugu lyrics
      final teluguCandidate = {
        'id': 104,
        'trackName': 'Srivalli',
        'artistName': 'Sid Sriram, Devi Sri Prasad',
        'albumName': 'Srivalli (From "Pushpa - The Rise")(Telugu)',
        'duration': 221.0,
        'syncedLyrics': '[00:21.81] నిను చూస్తూ ఉంటె కన్నులు రెండు తిప్పేస్తావే\n[00:28.00] ...',
      };

      // When target language is Telugu:
      final scoreMalayalam = CanonicalSongDedup.scoreLyricsCandidate(
        targetLang: 'telugu',
        targetTitle: teluguSongTitle,
        targetArtist: teluguSongArtist,
        targetDuration: 221,
        candidate: malayalamCandidate,
      );
      expect(scoreMalayalam, lessThan(0), reason: 'Malayalam lyrics must be rejected for Telugu song');

      final scoreTamil = CanonicalSongDedup.scoreLyricsCandidate(
        targetLang: 'telugu',
        targetTitle: teluguSongTitle,
        targetArtist: teluguSongArtist,
        targetDuration: 221,
        candidate: tamilCandidate,
      );
      expect(scoreTamil, lessThan(0), reason: 'Tamil lyrics must be rejected for Telugu song');

      final scoreHindi = CanonicalSongDedup.scoreLyricsCandidate(
        targetLang: 'telugu',
        targetTitle: teluguSongTitle,
        targetArtist: teluguSongArtist,
        targetDuration: 221,
        candidate: hindiCandidate,
      );
      expect(scoreHindi, lessThan(0), reason: 'Hindi lyrics/album must be rejected for Telugu song');

      final scoreTelugu = CanonicalSongDedup.scoreLyricsCandidate(
        targetLang: 'telugu',
        targetTitle: teluguSongTitle,
        targetArtist: teluguSongArtist,
        targetDuration: 221,
        candidate: teluguCandidate,
      );
      expect(scoreTelugu, greaterThanOrEqualTo(500), reason: 'Authentic Telugu lyrics must score high');

      // Conversely, if target language is Tamil:
      final scoreTamilForTamil = CanonicalSongDedup.scoreLyricsCandidate(
        targetLang: 'tamil',
        targetTitle: teluguSongTitle,
        targetArtist: teluguSongArtist,
        targetDuration: 221,
        candidate: tamilCandidate,
      );
      expect(scoreTamilForTamil, greaterThanOrEqualTo(500), reason: 'Tamil lyrics must be accepted for Tamil target');

      final scoreTeluguForTamil = CanonicalSongDedup.scoreLyricsCandidate(
        targetLang: 'tamil',
        targetTitle: teluguSongTitle,
        targetArtist: teluguSongArtist,
        targetDuration: 221,
        candidate: teluguCandidate,
      );
      expect(scoreTeluguForTamil, lessThan(0), reason: 'Telugu lyrics must be rejected for Tamil target');
    });
  });
}

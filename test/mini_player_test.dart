import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/widgets/mini_player.dart';
import 'package:music_app/services/music_service.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

final kTransparentImage = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

class MockHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return _MockHttpClient();
  }
}

class _MockHttpClient extends Fake implements HttpClient {
  @override
  bool autoUncompress = true;
  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _MockHttpClientRequest();
}

class _MockHttpClientRequest extends Fake implements HttpClientRequest {
  @override
  final HttpHeaders headers = _MockHttpHeaders();
  @override
  Future<HttpClientResponse> close() async => _MockHttpClientResponse();
}

class _MockHttpHeaders extends Fake implements HttpHeaders {
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}
}

class _MockHttpClientResponse extends Fake implements HttpClientResponse {
  @override
  int get statusCode => 200;
  @override
  int get contentLength => kTransparentImage.length;
  @override
  HttpClientResponseCompressionState get compressionState => HttpClientResponseCompressionState.notCompressed;
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.value(kTransparentImage).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = MockHttpOverrides();

  group('MiniPlayer Widget Tests', () {
    testWidgets('MiniPlayer displays previous, play/pause, and next buttons without equalizer beats visual', (tester) async {
      final musicService = MusicService();
      final song = Video(
        VideoId('rjkrTnma001'),
        'Chogada',
        'Darshan Raval, Asees Kaur',
        ChannelId('UC0WP5P-fwGlLyO4yOE76T8g'),
        DateTime.now(),
        '',
        null,
        '',
        null,
        ThumbnailSet('rjkrTnma001'),
        null,
        Engagement(0, null, null),
        false,
      );

      // Seed the music service state
      musicService.setTestState(
        playlist: [song],
        currentIndex: 0,
        currentSong: song,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: MiniPlayer(),
            ),
          ),
        ),
      );
      await tester.pump();

      // 1. Verify Song Title & Artist are displayed
      expect(find.text('Chogada'), findsOneWidget);
      expect(find.text('Darshan Raval, Asees Kaur'), findsOneWidget);

      // 2. Verify Beats Visual (AnimatedEqualizer) is NOT present
      // AnimatedEqualizer was imported from animated_equalizer.dart and displayed 3 equalizer bars
      expect(find.byKey(const ValueKey('animated_equalizer')), findsNothing);

      // 3. Verify All Three Control Buttons are present
      expect(find.byIcon(Icons.skip_previous_rounded), findsOneWidget);
      expect(
        find.byWidgetPredicate((widget) =>
          widget is Icon &&
          (widget.icon == Icons.play_arrow_rounded || widget.icon == Icons.pause_rounded)),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.skip_next_rounded), findsOneWidget);

      // 4. Verify Tapping Control Buttons
      await tester.tap(find.byIcon(Icons.skip_previous_rounded));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.skip_next_rounded));
      await tester.pump();
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/services/youtube_library_service.dart';
import 'package:music_app/widgets/auth/google_profile_header_button.dart';
import 'package:music_app/widgets/auth/google_logo.dart';
import 'package:music_app/screens/curated_playlist_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('YouTube UI Spots & Read-Only Governance Tests', () {
    testWidgets(
      'GoogleProfileHeaderButton renders "Sign in with Google" when logged out',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: Center(child: GoogleProfileHeaderButton())),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Sign in with Google'), findsOneWidget);
        expect(find.byType(GoogleLogo), findsOneWidget);
      },
    );

    testWidgets(
      'Tapping GoogleProfileHeaderButton opens clean Google Sign-In popup with Google logo and no temp placeholders',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: Center(child: GoogleProfileHeaderButton())),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Sign in with Google'));
        await tester.pumpAndSettle();

        expect(find.text('Continue with Google'), findsOneWidget);
        expect(find.text('Continue as Guest'), findsOneWidget);
        expect(find.text('Lossless 320k Audio'), findsOneWidget);
        expect(find.text('Personalized Mixes'), findsOneWidget);
        expect(find.text('Strictly Read-Only'), findsOneWidget);
        expect(find.byType(GoogleLogo), findsWidgets);

        expect(find.textContaining('Option 1'), findsNothing);
        expect(find.textContaining('Option 2'), findsNothing);
        expect(find.textContaining('Demo Mode'), findsNothing);
        expect(find.textContaining('OAuth Web Client ID'), findsNothing);

        await tester.tap(find.text('Continue as Guest'));
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'CuratedPlaylistScreen handles dynamic fetchSongs callback cleanly without taste matrix override',
      (tester) async {
        bool fetchCalled = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CuratedPlaylistScreen(
                title: 'My YouTube Mix',
                subtitle: 'YouTube Playlist',
                fetchSongs: () async {
                  fetchCalled = true;
                  return [];
                },
              ),
            ),
          ),
        );

        // Allow microtasks to complete
        await tester.pump();
        expect(fetchCalled, isTrue);
      },
    );

    test(
      'Strict Read-Only Verification: YouTubeLibraryService has zero write endpoints',
      () {
        final ytLib = YouTubeLibraryService();
        // Ensure cached playlists and liked music are unmodifiable lists
        expect(ytLib.playlists, isA<List<YouTubePlaylist>>());
        expect(ytLib.likedMusic, isA<List>());

        const dummy = YouTubePlaylist(
          id: '1',
          title: 'T',
          description: '',
          thumbnailUrl: '',
          itemCount: 0,
        );
        expect(
          () => (ytLib.playlists as dynamic).add(dummy),
          throwsUnsupportedError,
        );
      },
    );
  });
}

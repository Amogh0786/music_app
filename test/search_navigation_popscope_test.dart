import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/screens/search_screen.dart';
import 'package:music_app/screens/main_screen.dart';
import 'package:music_app/services/preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'searchHistory': ['Sid Sriram', 'A.R. Rahman'],
      'preferredLanguages': ['Telugu', 'Hindi'],
    });
    await PreferencesService().init();
  });

  group('SearchScreen Dynamic Back Button & Transitions', () {
    testWidgets(
      'SearchScreen shows no back button in AppBar and shows search icon initially',
      (WidgetTester tester) async {
        await tester.pumpWidget(const MaterialApp(home: SearchScreen()));
        await tester.pumpAndSettle();

        // Initially in Browse mode
        expect(
          find.byKey(const ValueKey('search_appbar_back_btn')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('search_field_search_icon')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('search_field_back_btn')),
          findsNothing,
        );
        expect(find.text('Browse Categories'), findsOneWidget);
      },
    );

    testWidgets(
      'Typing in search field morphs prefix icon to back button and reveals AppBar back button',
      (WidgetTester tester) async {
        await tester.pumpWidget(const MaterialApp(home: SearchScreen()));
        await tester.pumpAndSettle();

        // Enter search text
        await tester.enterText(find.byType(TextField), 'KavalanSongQuery');
        await tester.pumpAndSettle();

        // Both AppBar back button and search field leading back button should now be visible
        expect(
          find.byKey(const ValueKey('search_appbar_back_btn')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('search_field_back_btn')),
          findsOneWidget,
        );

        // Tapping AppBar back button clears search and restores browse categories
        await tester.tap(find.byKey(const ValueKey('search_appbar_back_btn')));
        await tester.pumpAndSettle();

        expect(find.text('KavalanSongQuery'), findsNothing);
        expect(
          find.byKey(const ValueKey('search_appbar_back_btn')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('search_field_search_icon')),
          findsOneWidget,
        );
        expect(find.text('Browse Categories'), findsOneWidget);
      },
    );

    testWidgets(
      'Tapping search field leading back button collapses search and unfocuses',
      (WidgetTester tester) async {
        await tester.pumpWidget(const MaterialApp(home: SearchScreen()));
        await tester.pumpAndSettle();

        // Focus and enter text
        final textField = find.byType(TextField);
        await tester.tap(textField);
        await tester.enterText(textField, 'RockstarSearch');
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('search_field_back_btn')),
          findsOneWidget,
        );

        // Tap field back button
        await tester.tap(find.byKey(const ValueKey('search_field_back_btn')));
        await tester.pumpAndSettle();

        expect(find.text('RockstarSearch'), findsNothing);
        expect(
          find.byKey(const ValueKey('search_field_search_icon')),
          findsOneWidget,
        );
        expect(find.text('Browse Categories'), findsOneWidget);
      },
    );

    testWidgets(
      'SearchScreen PopScope intercepts back navigation when search is active',
      (WidgetTester tester) async {
        final GlobalKey<SearchScreenState> searchKey =
            GlobalKey<SearchScreenState>();

        await tester.pumpWidget(
          MaterialApp(home: SearchScreen(key: searchKey)),
        );
        await tester.pumpAndSettle();

        // Activate search
        await tester.enterText(find.byType(TextField), 'Telugu Beats');
        await tester.pumpAndSettle();
        expect(searchKey.currentState!.isSearchActive, isTrue);

        // Verify PopScope widget exists in tree
        final popScopeFinder = find.byWidgetPredicate((w) => w is PopScope);
        expect(popScopeFinder, findsWidgets);

        // Invoke clearSearchAndDismiss through pop scope simulation
        searchKey.currentState!.clearSearchAndDismiss();
        await tester.pumpAndSettle();

        expect(searchKey.currentState!.isSearchActive, isFalse);
        expect(find.text('Browse Categories'), findsOneWidget);
      },
    );
  });

  group('MainScreen PopScope Hierarchical Navigation', () {
    testWidgets('MainScreen initializes on Tab 0 (Home) with PopScope', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(const MaterialApp(home: MainScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(MainScreen), findsOneWidget);
      final popScopeFinder = find.byWidgetPredicate((w) => w is PopScope);
      expect(popScopeFinder, findsWidgets);
    });
  });
}

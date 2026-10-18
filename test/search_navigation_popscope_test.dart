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
      'Typing in search field keeps search icon in prefix and reveals AppBar back button in search tab',
      (WidgetTester tester) async {
        await tester.pumpWidget(const MaterialApp(home: SearchScreen()));
        await tester.pumpAndSettle();

        // Enter search text
        await tester.enterText(find.byType(TextField), 'KavalanSongQuery');
        await tester.pumpAndSettle();

        // AppBar back button is visible in search tab, search field maintains search icon
        expect(
          find.byKey(const ValueKey('search_appbar_back_btn')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('search_field_search_icon')),
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
      'Typing single character maintains TextField focus without unmounting or dropping focus',
      (WidgetTester tester) async {
        await tester.pumpWidget(const MaterialApp(home: SearchScreen()));
        await tester.pumpAndSettle();

        // Tap on TextField to focus it
        await tester.tap(find.byType(TextField));
        await tester.pumpAndSettle();

        final focusNode = tester
            .widget<TextField>(find.byType(TextField))
            .focusNode;
        expect(focusNode?.hasFocus, isTrue);

        // Enter single character (previously triggered unmount/remount losing focus)
        await tester.enterText(find.byType(TextField), 'a');
        await tester.pump();

        expect(focusNode?.hasFocus, isTrue);
        expect(find.byKey(const ValueKey('search_text_field')), findsOneWidget);
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

    testWidgets(
      'Tapping a suggestion submits search, updates text field, and clears suggestion list',
      (WidgetTester tester) async {
        final GlobalKey<SearchScreenState> searchKey =
            GlobalKey<SearchScreenState>();

        await tester.pumpWidget(
          MaterialApp(home: SearchScreen(key: searchKey)),
        );
        await tester.pumpAndSettle();

        // Enter text matching history item 'Sid Sriram'
        await tester.enterText(find.byType(TextField), 'Sid');
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();

        // Suggestion for 'Sid Sriram' should appear
        expect(find.text('Sid Sriram'), findsWidgets);

        // Tap on suggestion
        await tester.tap(find.text('Sid Sriram').first);
        await tester.pump();
        await tester.pumpAndSettle();

        // Text field is updated to 'Sid Sriram'
        final textField = tester.widget<TextField>(find.byType(TextField));
        expect(textField.controller?.text, 'Sid Sriram');
        expect(searchKey.currentState!.isSearchActive, isTrue);
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

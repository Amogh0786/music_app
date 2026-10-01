import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/widgets/responsive_wrapper.dart';

void main() {
  testWidgets('ResponsiveWrapper renders full-width on mobile viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ResponsiveWrapper(
            child: SizedBox(
              key: Key('test_content'),
              height: 100,
              width: double.infinity,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final contentFinder = find.byKey(const Key('test_content'));
    expect(contentFinder, findsOneWidget);
    final renderBox = tester.renderObject<RenderBox>(contentFinder);
    expect(renderBox.size.width, equals(390.0));
  });

  testWidgets(
    'ResponsiveWrapper constrains and centers on wide desktop viewport',
    (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ResponsiveWrapper(
              child: SizedBox(
                key: Key('test_content_desktop'),
                height: 100,
                width: double.infinity,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final contentFinder = find.byKey(const Key('test_content_desktop'));
      expect(contentFinder, findsOneWidget);
      final renderBox = tester.renderObject<RenderBox>(contentFinder);
      expect(
        renderBox.size.width,
        equals(ResponsiveWrapper.maxDesktopContentWidth),
      );
    },
  );
}

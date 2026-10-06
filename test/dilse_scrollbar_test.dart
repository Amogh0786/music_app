import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/widgets/dilse_scrollbar.dart';

void main() {
  testWidgets('DilSeScrollbar renders child properly', (tester) async {
    final controller = ScrollController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DilSeScrollbar(
            controller: controller,
            child: ListView.builder(
              controller: controller,
              itemCount: 5,
              itemBuilder: (context, i) => ListTile(title: Text('Item $i')),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Item 0'), findsOneWidget);
    expect(find.text('Item 4'), findsOneWidget);
    controller.dispose();
  });

  testWidgets('DilSeScrollbar responds to vertical scroll gesture', (
    tester,
  ) async {
    final controller = ScrollController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DilSeScrollbar(
            controller: controller,
            child: ListView.builder(
              controller: controller,
              itemCount: 100,
              itemExtent: 60.0,
              itemBuilder: (context, i) => ListTile(title: Text('Song $i')),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(controller.offset, equals(0.0));

    // Scroll down via standard scroll
    await tester.drag(find.text('Song 0'), const Offset(0, -300));
    await tester.pumpAndSettle();

    expect(controller.offset, greaterThan(0.0));
    controller.dispose();
  });

  testWidgets(
    'DilSeScrollbar drag gesture on right edge seeks scroll position',
    (tester) async {
      final controller = ScrollController();
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DilSeScrollbar(
              controller: controller,
              bottomPadding: 0.0,
              child: ListView.builder(
                controller: controller,
                itemCount: 100,
                itemExtent: 60.0,
                itemBuilder: (context, i) => ListTile(title: Text('Track $i')),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Trigger initial scroll notification so metrics are computed
      controller.jumpTo(10.0);
      await tester.pump();

      // Drag along right edge (x = 390) from top to middle
      final rightEdgeTop = const Offset(390, 50);
      final gesture = await tester.startGesture(rightEdgeTop);
      await tester.pump();

      // Drag downward to middle
      await gesture.moveTo(const Offset(390, 400));
      await tester.pump();

      expect(controller.offset, greaterThan(10.0));

      await gesture.up();
      await tester.pumpAndSettle();

      controller.dispose();
    },
  );

  testWidgets('DilSeScrollbar bubbleLabelBuilder formats custom text', (
    tester,
  ) async {
    final controller = ScrollController();
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DilSeScrollbar(
            controller: controller,
            showBubble: true,
            bubbleLabelBuilder: (progress, maxScroll) =>
                'Seek: ${(progress * 100).round()}%',
            child: ListView.builder(
              controller: controller,
              itemCount: 100,
              itemExtent: 60.0,
              itemBuilder: (context, i) => ListTile(title: Text('Audio $i')),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    controller.jumpTo(20.0);
    await tester.pump();

    final gesture = await tester.startGesture(const Offset(390, 100));
    await tester.pump();
    await gesture.moveTo(const Offset(390, 400));
    await tester.pump();

    expect(find.textContaining('Seek:'), findsOneWidget);

    await gesture.up();
    await tester.pumpAndSettle();

    controller.dispose();
  });
}

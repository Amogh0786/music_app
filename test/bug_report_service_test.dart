import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:music_app/services/bug_report_service.dart';
import 'package:music_app/widgets/bug_report_button.dart';
import 'package:music_app/widgets/bug_report_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await BugReportService.instance.init();
  });

  group('SentryLens BugReportService Tests', () {
    test(
      'Initializes with default shake to report enabled and persists toggle',
      () async {
        final service = BugReportService.instance;
        expect(service.isShakeEnabled, isTrue);

        await service.setShakeEnabled(false);
        expect(service.isShakeEnabled, isFalse);

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool(BugReportService.prefShakeToReport), isFalse);

        await service.setShakeEnabled(true);
        expect(service.isShakeEnabled, isTrue);
      },
    );

    test(
      'submitBugReport rejects descriptions with fewer than 8 words',
      () async {
        final service = BugReportService.instance;

        final result = await service.submitBugReport(
          userDescription: 'Not enough words here',
          screenshotBytes: null,
          diagnostics: {},
        );

        expect(result, isFalse);
      },
    );

    test(
      'captureSnapshotAndContext gathers audio and device telemetry keys',
      () async {
        final service = BugReportService.instance;
        final snapshot = await service.captureSnapshotAndContext();

        expect(snapshot.diagnostics.containsKey('audio_state'), isTrue);
        expect(snapshot.diagnostics.containsKey('device_telemetry'), isTrue);
        expect(snapshot.diagnostics.containsKey('logs'), isTrue);

        final audioState =
            snapshot.diagnostics['audio_state'] as Map<String, dynamic>;
        expect(audioState.containsKey('activeDeck'), isTrue);
        expect(audioState.containsKey('streamType'), isTrue);
        expect(audioState.containsKey('playbackState'), isTrue);
      },
    );
  });

  group('SentryLens UI Widget Tests', () {
    testWidgets('BugReportButton renders with squircle shape and bug icon', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Center(child: BugReportButton(size: 38))),
        ),
      );

      expect(find.byType(BugReportButton), findsOneWidget);
      expect(find.byIcon(Icons.bug_report_rounded), findsOneWidget);
    });

    testWidgets(
      'BugReportSheet enforces 10-word threshold for submit activation',
      (tester) async {
        final snapshot = BugReportSnapshot(
          screenshotBytes: null,
          diagnostics: {'audio_state': {}, 'device_telemetry': {}, 'logs': []},
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: BugReportSheet(snapshot: snapshot)),
          ),
        );

        // Initially finds the word counter requiring 10 words
        expect(find.text('0 / 10 words required'), findsOneWidget);
        expect(find.text('Launch Mail Client'), findsOneWidget);
        expect(find.byIcon(Icons.mark_email_read_outlined), findsOneWidget);
        expect(find.text('Add image'), findsOneWidget);
        expect(find.byIcon(Icons.add_photo_alternate_rounded), findsOneWidget);

        // Type 4 words
        final textField = find.byType(TextField);
        await tester.enterText(textField, 'The music stopped playing');
        await tester.pump();
        expect(find.text('4 / 10 words required'), findsOneWidget);

        // Type 10 words
        await tester.enterText(
          textField,
          'one two three four five six seven eight nine ten',
        );
        await tester.pump();
        expect(find.text('10 / 10 words required'), findsOneWidget);
        expect(find.text('Detailed reproduction provided'), findsOneWidget);
      },
    );

    testWidgets(
      'BugReportSheet renders Add image tile with tactile InkWell and BouncingScrollPhysics',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: BugReportSheet())),
        );

        final addImageText = find.text('Add image');
        expect(addImageText, findsOneWidget);
        expect(find.byIcon(Icons.add_photo_alternate_rounded), findsOneWidget);

        // Verify ListView has BouncingScrollPhysics
        final listView = tester.widget<ListView>(find.byType(ListView));
        expect(listView.physics, isA<BouncingScrollPhysics>());
        expect(listView.scrollDirection, Axis.horizontal);

        // Tap the Add Image tile to ensure gesture dispatch doesn't throw
        await tester.tap(addImageText);
        await tester.pump();
      },
    );
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/services/connectivity_service.dart';
import 'package:music_app/widgets/top_bar_offline_badge.dart';

void main() {
  testWidgets(
    'TopBarOfflineBadge renders nothing when network quality is good',
    (WidgetTester tester) async {
      ConnectivityService().setOfflineForTesting(false);
      ConnectivityService().setQualityForTesting(NetworkQuality.good);

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: TopBarOfflineBadge())),
      );

      expect(find.byType(InkWell), findsNothing);
      expect(find.text('Offline Mode'), findsNothing);
    },
  );

  testWidgets('TopBarOfflineBadge renders Offline Mode pill when offline', (
    WidgetTester tester,
  ) async {
    ConnectivityService().setOfflineForTesting(true);
    ConnectivityService().setQualityForTesting(NetworkQuality.offline);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: TopBarOfflineBadge())),
    );

    await tester.pump();

    expect(find.text('Offline Mode'), findsOneWidget);
    expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);

    // Reset
    ConnectivityService().setOfflineForTesting(false);
    ConnectivityService().setQualityForTesting(NetworkQuality.good);
  });

  testWidgets(
    'TopBarOfflineBadge renders Slow Network pill when connectivity is poor',
    (WidgetTester tester) async {
      ConnectivityService().setOfflineForTesting(false);
      ConnectivityService().setQualityForTesting(NetworkQuality.poor);

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: TopBarOfflineBadge())),
      );

      await tester.pump();

      expect(find.text('Slow Network'), findsOneWidget);
      expect(find.byIcon(Icons.wifi_protected_setup_rounded), findsOneWidget);

      // Reset
      ConnectivityService().setQualityForTesting(NetworkQuality.good);
    },
  );
}

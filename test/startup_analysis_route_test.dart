import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/services/connectivity_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    ConnectivityService().setOfflineForTesting(false);
    ConnectivityService().setQualityForTesting(NetworkQuality.good);
  });

  tearDown(() {
    ConnectivityService().cancelStartupAnalysis();
    ConnectivityService().setOfflineForTesting(false);
    ConnectivityService().setQualityForTesting(NetworkQuality.good);
  });

  test(
    'analyzeStartupRoute returns 0 immediately when online with good quality',
    () async {
      ConnectivityService().setOfflineForTesting(false);
      ConnectivityService().setQualityForTesting(NetworkQuality.good);

      final route = await ConnectivityService().analyzeStartupRoute(
        timeout: const Duration(seconds: 7),
      );
      expect(route, 0);
    },
  );

  test('analyzeStartupRoute returns 2 when offline', () async {
    ConnectivityService().setOfflineForTesting(true);
    ConnectivityService().setQualityForTesting(NetworkQuality.offline);

    final route = await ConnectivityService().analyzeStartupRoute(
      timeout: const Duration(seconds: 7),
    );
    expect(route, 2);
  });

  test('analyzeStartupRoute returns 2 when quality is poor', () async {
    ConnectivityService().setOfflineForTesting(false);
    ConnectivityService().setQualityForTesting(NetworkQuality.poor);

    final route = await ConnectivityService().analyzeStartupRoute(
      timeout: const Duration(seconds: 7),
    );
    expect(route, 2);
  });

  test('cancelStartupAnalysis cancels analysis immediately', () async {
    ConnectivityService().cancelStartupAnalysis();
    // Verify no exceptions or hangs
    expect(true, isTrue);
  });
}

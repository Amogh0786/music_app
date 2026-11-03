import 'package:flutter/material.dart';
import '../services/connectivity_service.dart';
import '../screens/main_screen.dart';
import '../layouts/desktop_layout_state.dart';

/// Minimalist matte pill badge displayed on the top bar beside the Account icon.
///
/// Indicates whether the application is currently operating in `< Offline Mode >`
/// or experiencing low connectivity. Adheres strictly to Rule #9 (Zero Neons, Zero Gradients,
/// solid matte palette with obsidian background and amber/slate indicators).
///
/// When the connection recovers, this badge automatically and quietly collapses without
/// user intervention.
class TopBarOfflineBadge extends StatelessWidget {
  const TopBarOfflineBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<NetworkQuality>(
      valueListenable: ConnectivityService.qualityNotifier,
      builder: (context, quality, _) {
        final isOffline =
            quality == NetworkQuality.offline ||
            ConnectivityService().isOffline;
        final isPoor = quality == NetworkQuality.poor && !isOffline;

        if (!isOffline && !isPoor) {
          return const SizedBox.shrink();
        }

        final label = isOffline ? 'Offline Mode' : 'Slow Network';
        final icon = isOffline
            ? Icons.cloud_off_rounded
            : Icons.wifi_protected_setup_rounded;

        // Solid matte palette: Obsidian background (#161618), subtle matte border (#2E2E32),
        // solid amber accent (#F59E0B) for warning.
        return Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                // Smoothly switch to Library / Offline tab on tap
                MainScreen.switchToTab(2);
                DesktopLayoutState.activeNavTab.value = DesktopNavTab.library;
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 4.5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF161618),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF2E2E32),
                    width: 1.0,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF59E0B),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(icon, size: 13, color: const Color(0xFFF59E0B)),
                    const SizedBox(width: 5),
                    Text(
                      label,
                      style: const TextStyle(
                        color: Color(0xFFE2E8F0),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

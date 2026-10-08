import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../widgets/keyboard_playback_controller.dart';
import '../widgets/desktop/desktop_top_nav_bar.dart';
import '../widgets/desktop/desktop_resize_divider.dart';
import '../widgets/desktop/desktop_now_playing_bar.dart';
import '../widgets/desktop/desktop_left_sidebar.dart';
import '../widgets/desktop/desktop_right_panel.dart';
import 'desktop_main_viewport.dart';
import 'desktop_layout_state.dart';

/// Spotify-grade 3-Column Desktop Application Shell.
///
/// Automatically branches based on viewport width:
/// - Wide Viewport (`kIsWeb && constraints.maxWidth >= 1024` or desktop): Renders 3-Column Shell.
/// - Mobile / Narrow (`constraints.maxWidth < 1024` or native mobile): Renders [mobileBody] unmodified.
class DesktopAppShell extends StatelessWidget {
  final Widget mobileBody;

  const DesktopAppShell({super.key, required this.mobileBody});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = kIsWeb && constraints.maxWidth >= 1024;

        if (!isDesktop) {
          return mobileBody;
        }

        return KeyboardPlaybackController(
          child: Scaffold(
            backgroundColor: const Color(0xFF0B0B0F),
            body: Column(
              children: [
                // 1. Top Navigation Bar (64px)
                const SizedBox(
                  height: 64.0,
                  child: RepaintBoundary(child: DesktopTopNavBar()),
                ),

                // 2. Center 3-Column Spatial Grid
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Left Sidebar (Collapsible 72px <-> 280px-398px)
                      ValueListenableBuilder<double>(
                        valueListenable: DesktopLayoutState.leftSidebarWidth,
                        builder: (context, width, _) {
                          return SizedBox(
                            width: width,
                            child: RepaintBoundary(
                              child: DesktopLeftSidebar(width: width),
                            ),
                          );
                        },
                      ),

                      // Tactical Left Resize Divider
                      const DesktopResizeDivider(isRightSide: false),

                      // Center Main Content Viewport (Expanded flex 1)
                      const Expanded(
                        child: RepaintBoundary(child: DesktopMainViewport()),
                      ),

                      // Right Contextual Panel with Resizer (Toggleable & Resizable)
                      ValueListenableBuilder<bool>(
                        valueListenable: DesktopLayoutState.isRightPanelVisible,
                        builder: (context, isVisible, _) {
                          if (!isVisible) return const SizedBox.shrink();

                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const DesktopResizeDivider(isRightSide: true),
                              ValueListenableBuilder<double>(
                                valueListenable:
                                    DesktopLayoutState.rightPanelWidth,
                                builder: (context, width, _) {
                                  return SizedBox(
                                    width: width,
                                    child: const RepaintBoundary(
                                      child: DesktopRightPanel(),
                                    ),
                                  );
                                },
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),

                // 3. Bottom Edge-to-Edge Player Deck (90px)
                const SizedBox(
                  height: 90.0,
                  child: RepaintBoundary(child: DesktopNowPlayingBar()),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

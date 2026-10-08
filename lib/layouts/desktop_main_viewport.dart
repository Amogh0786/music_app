import 'package:flutter/material.dart';
import '../screens/home_screen.dart';
import '../screens/search_screen.dart';
import '../screens/library_screen.dart';
import 'desktop_layout_state.dart';

/// Spotify-grade Center Main Viewport (#main-view).
///
/// Features:
/// 1. Independent vertical scrolling container for central navigation routes.
/// 2. Preserves scroll states using [PageStorageKey] and [IndexedStack].
/// 3. Automatically updates when [DesktopLayoutState.activeNavTab] changes.
class DesktopMainViewport extends StatelessWidget {
  const DesktopMainViewport({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      decoration: BoxDecoration(
        color: const Color(0xFF12121A),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1.0,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12.0),
        child: ValueListenableBuilder<DesktopNavTab>(
          valueListenable: DesktopLayoutState.activeNavTab,
          builder: (context, activeTab, _) {
            final tabIndex = _getTabIndex(activeTab);

            return IndexedStack(
              index: tabIndex,
              children: const [
                // Tab 0: Home Screen
                HomeScreen(key: PageStorageKey('desktop_home_viewport')),

                // Tab 1: Search Screen
                SearchScreen(key: PageStorageKey('desktop_search_viewport')),

                // Tab 2: Library Screen
                LibraryScreen(key: PageStorageKey('desktop_library_viewport')),
              ],
            );
          },
        ),
      ),
    );
  }

  int _getTabIndex(DesktopNavTab tab) {
    switch (tab) {
      case DesktopNavTab.home:
        return 0;
      case DesktopNavTab.search:
        return 1;
      case DesktopNavTab.library:
        return 2;
    }
  }
}

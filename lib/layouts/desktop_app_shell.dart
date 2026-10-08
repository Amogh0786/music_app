import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../screens/home_screen.dart';
import '../widgets/desktop/desktop_resize_divider.dart';
import '../widgets/desktop/desktop_now_playing_bar.dart';
import '../widgets/desktop/desktop_left_sidebar.dart';
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

        return Scaffold(
          backgroundColor: const Color(0xFF0B0B0F),
          body: Column(
            children: [
              // 1. Top Navigation Bar (64px)
              const SizedBox(
                height: 64.0,
                child: RepaintBoundary(child: DesktopTopNavBarPlaceholder()),
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

                    // Tactical Resize Divider
                    const DesktopResizeDivider(),

                    // Center Main Content Viewport (Expanded flex 1)
                    const Expanded(
                      child: RepaintBoundary(
                        child: DesktopMainViewportPlaceholder(),
                      ),
                    ),

                    // Right Contextual Panel (280px Toggleable)
                    ValueListenableBuilder<bool>(
                      valueListenable: DesktopLayoutState.isRightPanelVisible,
                      builder: (context, isVisible, _) {
                        if (!isVisible) return const SizedBox.shrink();
                        return const SizedBox(
                          width: 280.0,
                          child: RepaintBoundary(
                            child: DesktopRightPanelPlaceholder(),
                          ),
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
        );
      },
    );
  }
}

/// Placeholder for Desktop Top Navigation Bar (Height: 64px)
class DesktopTopNavBarPlaceholder extends StatelessWidget {
  const DesktopTopNavBarPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      decoration: BoxDecoration(
        color: const Color(0xFF0B0B0F),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1.0,
          ),
        ),
      ),
      child: Row(
        children: [
          // Logo & Branding
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 34.0,
                height: 34.0,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFA2D48), Color(0xFFFF6B81)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10.0),
                ),
                child: const Icon(
                  Icons.music_note_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12.0),
              const Text(
                'DilSe Music',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16.0,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(width: 32.0),

          // Search Pill Placeholder (Ctrl+Shift+L Focus Intent)
          Expanded(
            child: Container(
              height: 40.0,
              constraints: const BoxConstraints(maxWidth: 480.0),
              padding: const EdgeInsets.symmetric(horizontal: 14.0),
              decoration: BoxDecoration(
                color: const Color(0xFF16161E),
                borderRadius: BorderRadius.circular(20.0),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                  width: 1.0,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.search_rounded,
                    color: Colors.white.withValues(alpha: 0.5),
                    size: 18.0,
                  ),
                  const SizedBox(width: 10.0),
                  Expanded(
                    child: Text(
                      'What do you want to play?',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 13.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6.0,
                      vertical: 2.5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(5.0),
                    ),
                    child: Text(
                      'Ctrl+Shift+L',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 24.0),

          // Right Top Nav Controls (Panel Toggle & Profile)
          IconButton(
            tooltip: 'Toggle Right Panel',
            icon: Icon(
              Icons.view_sidebar_rounded,
              color: Colors.white.withValues(alpha: 0.7),
              size: 20.0,
            ),
            onPressed: () => DesktopLayoutState.toggleRightPanel(),
          ),
          const SizedBox(width: 8.0),
          Container(
            width: 34.0,
            height: 34.0,
            decoration: BoxDecoration(
              color: const Color(0xFF16161E),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.12),
                width: 1.0,
              ),
            ),
            child: const Icon(
              Icons.person_rounded,
              color: Colors.white70,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }
}

/// Placeholder for Left Sidebar (DesktopLibrary)
class DesktopLeftSidebarPlaceholder extends StatelessWidget {
  final double width;

  const DesktopLeftSidebarPlaceholder({super.key, required this.width});

  @override
  Widget build(BuildContext context) {
    final isCollapsed = width <= 80.0;

    return Container(
      margin: const EdgeInsets.fromLTRB(8.0, 8.0, 0.0, 8.0),
      padding: EdgeInsets.symmetric(
        horizontal: isCollapsed ? 8.0 : 16.0,
        vertical: 14.0,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF16161E),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: isCollapsed
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: [
          // Header: Your Library + Collapse Toggle
          Row(
            mainAxisAlignment: isCollapsed
                ? MainAxisAlignment.center
                : MainAxisAlignment.spaceBetween,
            children: [
              if (!isCollapsed)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.library_music_rounded,
                      color: Colors.white.withValues(alpha: 0.8),
                      size: 20.0,
                    ),
                    const SizedBox(width: 10.0),
                    const Text(
                      'Your Library',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                tooltip: isCollapsed ? 'Expand Library' : 'Collapse Library',
                icon: Icon(
                  isCollapsed
                      ? Icons.chevron_right_rounded
                      : Icons.chevron_left_rounded,
                  color: Colors.white.withValues(alpha: 0.7),
                  size: 20.0,
                ),
                onPressed: () => DesktopLayoutState.toggleLeftSidebar(),
              ),
            ],
          ),

          const SizedBox(height: 16.0),

          // Library Items Placeholder
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildSidebarItem(
                  icon: Icons.favorite_rounded,
                  label: 'Liked Songs',
                  isCollapsed: isCollapsed,
                  color: const Color(0xFFFA2D48),
                ),
                _buildSidebarItem(
                  icon: Icons.download_done_rounded,
                  label: 'Downloaded',
                  isCollapsed: isCollapsed,
                  color: const Color(0xFF1DB954),
                ),
                _buildSidebarItem(
                  icon: Icons.playlist_play_rounded,
                  label: 'Daily Mix & Playlists',
                  isCollapsed: isCollapsed,
                  color: const Color(0xFF4A90E2),
                ),
                _buildSidebarItem(
                  icon: Icons.history_rounded,
                  label: 'Listening History',
                  isCollapsed: isCollapsed,
                  color: Colors.amber,
                ),
                _buildSidebarItem(
                  icon: Icons.album_rounded,
                  label: 'Albums & Soundtracks',
                  isCollapsed: isCollapsed,
                  color: Colors.purpleAccent,
                ),
                _buildSidebarItem(
                  icon: Icons.folder_rounded,
                  label: 'Device Audio',
                  isCollapsed: isCollapsed,
                  color: Colors.tealAccent,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem({
    required IconData icon,
    required String label,
    required bool isCollapsed,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Tooltip(
        message: isCollapsed ? label : '',
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isCollapsed ? 8.0 : 12.0,
            vertical: 10.0,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: Row(
            mainAxisAlignment: isCollapsed
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 18.0),
              if (!isCollapsed) ...[
                const SizedBox(width: 12.0),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 13.0,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Placeholder for Center Main Content Viewport
class DesktopMainViewportPlaceholder extends StatelessWidget {
  const DesktopMainViewportPlaceholder({super.key});

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
        child: const HomeScreen(),
      ),
    );
  }
}

/// Placeholder for Right Contextual Panel (NowPlayingView / Synced Lyrics / Queue)
class DesktopRightPanelPlaceholder extends StatelessWidget {
  const DesktopRightPanelPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 8.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: const Color(0xFF16161E),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Strip with Close Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Now Playing',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                icon: Icon(
                  Icons.close_rounded,
                  color: Colors.white.withValues(alpha: 0.7),
                  size: 18.0,
                ),
                onPressed: () => DesktopLayoutState.toggleRightPanel(),
              ),
            ],
          ),

          const SizedBox(height: 14.0),

          // 1:1 Studio Artwork Hero Card
          AspectRatio(
            aspectRatio: 1.0,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1F1F2B),
                borderRadius: BorderRadius.circular(10.0),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Center(
                child: Icon(
                  Icons.music_note_rounded,
                  color: Colors.white.withValues(alpha: 0.2),
                  size: 48.0,
                ),
              ),
            ),
          ),

          const SizedBox(height: 14.0),

          // Active Synced Lyrics Card Placeholder
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: const Color(0xFF1F1F2B),
              borderRadius: BorderRadius.circular(10.0),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.lyrics_rounded,
                      color: Color(0xFFFA2D48),
                      size: 16.0,
                    ),
                    const SizedBox(width: 8.0),
                    Text(
                      'Synced Lyrics',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8.0),
                Text(
                  'Tap play to stream synchronized lyrics...',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 12.0,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12.0),

          // Next in Queue Preview Placeholder
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: const Color(0xFF1F1F2B),
                borderRadius: BorderRadius.circular(10.0),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.queue_music_rounded,
                        color: Color(0xFF4A90E2),
                        size: 16.0,
                      ),
                      const SizedBox(width: 8.0),
                      Text(
                        'Up Next in Queue',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8.0),
                  Expanded(
                    child: Center(
                      child: Text(
                        '50-track smart radio ready',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Placeholder for Fixed 90px Bottom Desktop Now Playing Deck
class DesktopNowPlayingBarPlaceholder extends StatelessWidget {
  const DesktopNowPlayingBarPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      decoration: BoxDecoration(
        color: const Color(0xFF16161E),
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1.0,
          ),
        ),
      ),
      child: Row(
        children: [
          // Left: Track Info + Like
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Container(
                  width: 56.0,
                  height: 56.0,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1F1F2B),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: const Icon(
                    Icons.music_note_rounded,
                    color: Colors.white38,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14.0),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'DilSe Music Desktop',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2.0),
                      Text(
                        'Ready to stream',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 12.0,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.favorite_border_rounded,
                    color: Colors.white.withValues(alpha: 0.6),
                    size: 20.0,
                  ),
                  onPressed: () {},
                ),
              ],
            ),
          ),

          // Center: Playback Controls & Timeline Scrubber (Flexible 4)
          Expanded(
            flex: 5,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.shuffle_rounded,
                        color: Colors.white38,
                        size: 18,
                      ),
                      onPressed: () {},
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.skip_previous_rounded,
                        color: Colors.white70,
                        size: 22,
                      ),
                      onPressed: () {},
                    ),
                    const SizedBox(width: 8.0),
                    Container(
                      width: 36.0,
                      height: 36.0,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.black,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 8.0),
                    IconButton(
                      icon: const Icon(
                        Icons.skip_next_rounded,
                        color: Colors.white70,
                        size: 22,
                      ),
                      onPressed: () {},
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.repeat_rounded,
                        color: Colors.white38,
                        size: 18,
                      ),
                      onPressed: () {},
                    ),
                  ],
                ),
                const SizedBox(height: 4.0),
                Row(
                  children: [
                    Text(
                      '0:00',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 11.0,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(width: 8.0),
                    Expanded(
                      child: Container(
                        height: 4.0,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(2.0),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8.0),
                    Text(
                      '0:00',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 11.0,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Right: Context Toggles & Volume
          Expanded(
            flex: 3,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: 'Lyrics',
                  icon: const Icon(
                    Icons.lyrics_outlined,
                    color: Colors.white54,
                    size: 18,
                  ),
                  onPressed: () => DesktopLayoutState.setContextTab(
                    DesktopContextTab.lyrics,
                  ),
                ),
                IconButton(
                  tooltip: 'Queue',
                  icon: const Icon(
                    Icons.queue_music_rounded,
                    color: Colors.white54,
                    size: 18,
                  ),
                  onPressed: () =>
                      DesktopLayoutState.setContextTab(DesktopContextTab.queue),
                ),
                const SizedBox(width: 8.0),
                const Icon(
                  Icons.volume_up_rounded,
                  color: Colors.white54,
                  size: 18,
                ),
                const SizedBox(width: 8.0),
                SizedBox(
                  width: 90.0,
                  child: Container(
                    height: 4.0,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2.0),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

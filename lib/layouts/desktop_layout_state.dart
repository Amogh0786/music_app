import 'package:flutter/foundation.dart';

/// Contextual tabs available in the Right-hand Desktop Context Panel.
enum DesktopContextTab { nowPlaying, lyrics, queue, chords }

/// Lightweight, primitive ValueNotifier state holder for the Spotify-grade Desktop Shell.
///
/// Designed to avoid heavy state packages or root-level rebuilds.
/// Individual layout regions subscribe ONLY to the ValueNotifiers they care about.
class DesktopLayoutState {
  DesktopLayoutState._();

  /// Width of the resizable left library sidebar (clamped between 72.0 and 398.0).
  static final ValueNotifier<double> leftSidebarWidth = ValueNotifier<double>(
    280.0,
  );

  /// Whether the left sidebar is currently in collapsed icon-strip mode (72px).
  static final ValueNotifier<bool> isLeftSidebarCollapsed = ValueNotifier<bool>(
    false,
  );

  /// Whether the right-hand Now Playing / Queue / Lyrics contextual panel is visible.
  static final ValueNotifier<bool> isRightPanelVisible = ValueNotifier<bool>(
    true,
  );

  /// Active tab inside the right-hand contextual panel.
  static final ValueNotifier<DesktopContextTab> contextTab =
      ValueNotifier<DesktopContextTab>(DesktopContextTab.nowPlaying);

  /// Updates left sidebar width with tactical snap mechanics:
  /// - If dragged below 120px: snaps immediately to 72px (collapsed icon strip).
  /// - Otherwise: clamps between 72px and 398px.
  static void updateLeftSidebarWidth(double newWidth) {
    if (newWidth <= 120.0) {
      leftSidebarWidth.value = 72.0;
      isLeftSidebarCollapsed.value = true;
    } else {
      leftSidebarWidth.value = newWidth.clamp(72.0, 398.0);
      isLeftSidebarCollapsed.value = false;
    }
  }

  /// Toggles the left sidebar between expanded (280px) and collapsed (72px).
  static void toggleLeftSidebar() {
    if (isLeftSidebarCollapsed.value || leftSidebarWidth.value <= 72.0) {
      leftSidebarWidth.value = 280.0;
      isLeftSidebarCollapsed.value = false;
    } else {
      leftSidebarWidth.value = 72.0;
      isLeftSidebarCollapsed.value = true;
    }
  }

  /// Toggles the visibility of the right contextual panel.
  static void toggleRightPanel() {
    isRightPanelVisible.value = !isRightPanelVisible.value;
  }

  /// Sets the active contextual tab in the right panel and reveals it if hidden.
  static void setContextTab(DesktopContextTab tab) {
    contextTab.value = tab;
    if (!isRightPanelVisible.value) {
      isRightPanelVisible.value = true;
    }
  }
}

import 'package:flutter/foundation.dart';

/// Contextual tabs available in the Right-hand Desktop Context Panel.
enum DesktopContextTab { nowPlaying, lyrics, queue, chords }

/// Central Viewport tabs/routes available in the Desktop Shell.
enum DesktopNavTab {
  home,
  search,
  library,
  customPlaylist,
  artistProfile,
  album,
}

/// Lightweight, primitive ValueNotifier state holder for the Spotify-grade Desktop Shell.
///
/// Designed to avoid heavy state packages or root-level rebuilds.
/// Individual layout regions subscribe ONLY to the ValueNotifiers they care about.
class DesktopLayoutState {
  DesktopLayoutState._();

  /// Active central viewport navigation tab.
  static final ValueNotifier<DesktopNavTab> activeNavTab =
      ValueNotifier<DesktopNavTab>(DesktopNavTab.home);

  /// Active custom playlist ID rendered inside the central desktop viewport.
  static final ValueNotifier<String?> activePlaylistId = ValueNotifier<String?>(
    null,
  );

  /// Active artist name rendered inside the central desktop viewport.
  static final ValueNotifier<String?> activeArtistName = ValueNotifier<String?>(
    null,
  );

  /// Active album data rendered inside the central desktop viewport.
  static final ValueNotifier<Map<String, dynamic>?> activeAlbumData =
      ValueNotifier<Map<String, dynamic>?>(null);

  /// Global search query from the top navigation bar.
  static final ValueNotifier<String> globalSearchQuery = ValueNotifier<String>(
    '',
  );

  /// Width of the resizable left library sidebar (clamped between 72.0 and 398.0).
  static final ValueNotifier<double> leftSidebarWidth = ValueNotifier<double>(
    280.0,
  );

  /// Whether the left sidebar is currently in collapsed icon-strip mode (72px).
  static final ValueNotifier<bool> isLeftSidebarCollapsed = ValueNotifier<bool>(
    false,
  );

  /// Width of the resizable right contextual panel (clamped between 240.0 and 460.0).
  static final ValueNotifier<double> rightPanelWidth = ValueNotifier<double>(
    300.0,
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

  /// Updates right panel width clamped between 240.0 and 460.0.
  static void updateRightPanelWidth(double newWidth) {
    rightPanelWidth.value = newWidth.clamp(240.0, 460.0);
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

  /// Sets the active central viewport navigation tab.
  static void setNavTab(DesktopNavTab tab) {
    if (tab != DesktopNavTab.customPlaylist &&
        tab != DesktopNavTab.artistProfile &&
        tab != DesktopNavTab.album) {
      activePlaylistId.value = null;
      activeArtistName.value = null;
      activeAlbumData.value = null;
    }
    activeNavTab.value = tab;
  }

  /// Opens a custom playlist inside the central desktop viewport while keeping side panels docked.
  static void openPlaylist(String playlistId) {
    activePlaylistId.value = playlistId;
    activeArtistName.value = null;
    activeAlbumData.value = null;
    activeNavTab.value = DesktopNavTab.customPlaylist;
  }

  /// Opens an artist profile inside the central desktop viewport while keeping side panels docked.
  static void openArtist(String artistName) {
    activeArtistName.value = artistName;
    activePlaylistId.value = null;
    activeAlbumData.value = null;
    activeNavTab.value = DesktopNavTab.artistProfile;
  }

  /// Opens an album inside the central desktop viewport while keeping side panels docked.
  static void openAlbum({
    dynamic album,
    String? albumId,
    String? albumTitle,
    String? albumArtwork,
    String? albumArtist,
  }) {
    activeAlbumData.value = {
      'album': album,
      'albumId': albumId,
      'albumTitle': albumTitle,
      'albumArtwork': albumArtwork,
      'albumArtist': albumArtist,
    };
    activePlaylistId.value = null;
    activeArtistName.value = null;
    activeNavTab.value = DesktopNavTab.album;
  }

  /// Closes the detail view and returns to the home/library view.
  static void closeDetailView() {
    activePlaylistId.value = null;
    activeArtistName.value = null;
    activeAlbumData.value = null;
    if (activeNavTab.value == DesktopNavTab.customPlaylist ||
        activeNavTab.value == DesktopNavTab.artistProfile ||
        activeNavTab.value == DesktopNavTab.album) {
      activeNavTab.value = DesktopNavTab.home;
    }
  }
}

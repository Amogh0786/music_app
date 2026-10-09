import 'package:flutter/material.dart';
import '../screens/home_screen.dart';
import '../screens/search_screen.dart';
import '../screens/library_screen.dart';
import '../screens/custom_playlist_screen.dart';
import '../screens/artist_profile_screen.dart';
import '../screens/album_screen.dart';
import '../models/jio_album.dart';
import 'desktop_layout_state.dart';

/// Spotify-grade Center Main Viewport (#main-view).
///
/// Features:
/// 1. Independent vertical scrolling container for central navigation routes.
/// 2. Preserves scroll states using [PageStorageKey] and [IndexedStack].
/// 3. Automatically updates when [DesktopLayoutState.activeNavTab] changes.
/// 4. Renders playlists, artist profiles, and albums seamlessly inside the desktop spatial grid.
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
            if (activeTab == DesktopNavTab.customPlaylist) {
              return ValueListenableBuilder<String?>(
                valueListenable: DesktopLayoutState.activePlaylistId,
                builder: (context, playlistId, _) {
                  if (playlistId == null || playlistId.isEmpty) {
                    return _buildIndexedStack(DesktopNavTab.home);
                  }
                  return CustomPlaylistScreen(
                    key: ValueKey('desktop_playlist_$playlistId'),
                    playlistId: playlistId,
                  );
                },
              );
            }

            if (activeTab == DesktopNavTab.artistProfile) {
              return ValueListenableBuilder<String?>(
                valueListenable: DesktopLayoutState.activeArtistName,
                builder: (context, artistName, _) {
                  if (artistName == null || artistName.isEmpty) {
                    return _buildIndexedStack(DesktopNavTab.home);
                  }
                  return ArtistProfileScreen(
                    key: ValueKey('desktop_artist_$artistName'),
                    artistName: artistName,
                  );
                },
              );
            }

            if (activeTab == DesktopNavTab.album) {
              return ValueListenableBuilder<Map<String, dynamic>?>(
                valueListenable: DesktopLayoutState.activeAlbumData,
                builder: (context, albumData, _) {
                  if (albumData == null) {
                    return _buildIndexedStack(DesktopNavTab.home);
                  }
                  final album = albumData['album'] as JioAlbum?;
                  final albumId = albumData['albumId'] as String?;
                  final albumTitle = albumData['albumTitle'] as String?;
                  final albumArtwork = albumData['albumArtwork'] as String?;
                  final albumArtist = albumData['albumArtist'] as String?;

                  return AlbumScreen(
                    key: ValueKey(
                      'desktop_album_${albumId ?? albumTitle ?? 'default'}',
                    ),
                    album: album,
                    albumId: albumId,
                    albumTitle: albumTitle,
                    albumArtwork: albumArtwork,
                    albumArtist: albumArtist,
                  );
                },
              );
            }

            return _buildIndexedStack(activeTab);
          },
        ),
      ),
    );
  }

  Widget _buildIndexedStack(DesktopNavTab tab) {
    return IndexedStack(
      index: _getTabIndex(tab),
      children: const [
        HomeScreen(key: PageStorageKey('desktop_home_viewport')),
        SearchScreen(key: PageStorageKey('desktop_search_viewport')),
        LibraryScreen(key: PageStorageKey('desktop_library_viewport')),
      ],
    );
  }

  int _getTabIndex(DesktopNavTab tab) {
    switch (tab) {
      case DesktopNavTab.home:
      case DesktopNavTab.customPlaylist:
      case DesktopNavTab.artistProfile:
      case DesktopNavTab.album:
        return 0;
      case DesktopNavTab.search:
        return 1;
      case DesktopNavTab.library:
        return 2;
    }
  }
}

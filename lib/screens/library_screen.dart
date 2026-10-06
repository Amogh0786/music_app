import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/music_service.dart';
import '../services/preferences_service.dart';
import 'spotify_import_screen.dart';
import 'custom_playlist_screen.dart';
import 'artist_profile_screen.dart';
import '../services/dynamic_artist_service.dart';
import '../services/device_audio_service.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../widgets/animated_equalizer.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen>
    with AutomaticKeepAliveClientMixin {
  final MusicService _musicService = MusicService();
  final PreferencesService _prefs = PreferencesService();
  final DeviceAudioService _deviceAudio = DeviceAudioService();
  final TextEditingController _deviceSearchController = TextEditingController();
  String _deviceSearchFilter = '';

  @override
  bool get wantKeepAlive => true;

  final Map<String, int> _songFileSizes = {};
  int _lastDownloadedCount = -1;

  @override
  void initState() {
    super.initState();
    _musicService.addListener(_onStateChanged);
    _prefs.addListener(_onStateChanged);
    _deviceAudio.addListener(_onStateChanged);
    _lastDownloadedCount = _musicService.downloadedSongs.length;
    _calculateStorageUsage();
  }

  @override
  void dispose() {
    _musicService.removeListener(_onStateChanged);
    _prefs.removeListener(_onStateChanged);
    _deviceAudio.removeListener(_onStateChanged);
    _deviceSearchController.dispose();
    super.dispose();
  }

  void _onStateChanged() {
    if (mounted) {
      final currentCount = _musicService.downloadedSongs.length;
      if (currentCount != _lastDownloadedCount) {
        _lastDownloadedCount = currentCount;
        _calculateStorageUsage();
      }
      setState(() {});
    }
  }

  Future<void> _calculateStorageUsage() async {
    if (kIsWeb) return;
    final downloaded = _musicService.downloadedSongs;
    for (final s in downloaded) {
      final path = s['localPath'];
      final id = s['id'] ?? '';
      if (path != null && id.isNotEmpty) {
        try {
          final f = File(path);
          if (await f.exists()) {
            final len = await f.length();
            _songFileSizes[id] = len;
          }
        } catch (_) {}
      }
    }
    if (mounted) {
      setState(() {});
    }
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 MB';
    final mb = bytes / (1024 * 1024);
    if (mb < 1.0) {
      final kb = bytes / 1024;
      return '${kb.toStringAsFixed(0)} KB';
    }
    return '${mb.toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final downloaded = _musicService.downloadedSongs;
    final deviceSongs = _deviceAudio.deviceSongs;
    final liked = _musicService.likedSongs;
    final history = _prefs.listeningHistory;
    final followedArtists = _prefs.followedArtists;

    return DefaultTabController(
      length: 6,
      child: Scaffold(
        backgroundColor: const Color(0xFF0B0B0F),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0B0B0F),
          elevation: 0,
          title: const Text(
            'Your Library',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 30,
              color: Colors.white,
              letterSpacing: -0.8,
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 14, top: 8, bottom: 8),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.download_rounded, size: 17),
                label: const Text(
                  'Import / Exportify',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1DB954),
                  foregroundColor: Colors.black,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SpotifyImportScreen(),
                    ),
                  );
                },
              ),
            ),
          ],

          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: Container(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.only(bottom: 6),
              child: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.22),
                    width: 1,
                  ),
                ),
                dividerColor: Colors.transparent,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white54,
                labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                tabs: [
                  _buildPillTab('Downloaded', downloaded.length),
                  _buildPillTab('Device Audio', deviceSongs.length),
                  _buildPillTab('Liked', liked.length),
                  _buildPillTab(
                    'Playlists',
                    _musicService.customPlaylists.length,
                  ),
                  _buildPillTab('Artists', followedArtists.length),
                  _buildPillTab('History', history.length),
                ],
              ),
            ),
          ),
        ),
        body: TabBarView(
          children: [
            // TAB 1: DOWNLOADED SONGS
            downloaded.isEmpty
                ? _buildEmptyState(
                    icon: Icons.download_for_offline_outlined,
                    title: 'No downloaded songs yet',
                    subtitle:
                        'Tap the download icon while playing any song to listen offline without internet.',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 160, top: 12),
                    itemCount: downloaded.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return _buildActionHeader(
                          count: downloaded.length,
                          onPlayAll: () {
                            HapticFeedback.lightImpact();
                            _musicService.playDownloadedSong(downloaded.first);
                          },
                          onShuffle: () {
                            HapticFeedback.lightImpact();
                            _musicService.toggleShuffle();
                            _musicService.playDownloadedSong(downloaded.first);
                          },
                        );
                      }

                      final song = downloaded[index - 1];
                      final songId = song['id'] ?? '';
                      final sizeBytes = _songFileSizes[songId] ?? 0;
                      final sizeFormatted = _formatBytes(sizeBytes);
                      final isCurrent =
                          _musicService.currentSong?.id.value == songId;

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                            width: 52,
                            height: 52,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.network(
                                  song['thumbnail'] ?? '',
                                  cacheWidth: 120,
                                  cacheHeight: 120,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Container(
                                    color: const Color(0xFF1E1E28),
                                    child: const Icon(
                                      Icons.music_note,
                                      color: Colors.white54,
                                    ),
                                  ),
                                ),
                                if (isCurrent)
                                  Container(
                                    color: Colors.black54,
                                    child: Center(
                                      child: AnimatedEqualizer(
                                        isPlaying: _musicService.isPlaying,
                                        size: 22,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        title: Text(
                          song['title'] ?? 'Unknown',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            fontSize: 14.5,
                            letterSpacing: -0.2,
                          ),
                        ),
                        subtitle: Row(
                          children: [
                            Flexible(
                              child: Text(
                                song['author'] ?? 'Unknown Artist',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                            if (sizeBytes > 0) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 1.5,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white12,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  sizeFormatted,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.offline_pin_rounded,
                              color: Color(0xFF1DB954),
                              size: 20,
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                color: Colors.white38,
                                size: 20,
                              ),
                              onPressed: () async {
                                HapticFeedback.mediumImpact();
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    backgroundColor: const Color(0xFF1E1E28),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    title: const Text(
                                      'Delete Download?',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    content: Text(
                                      'Remove "${song['title']}" from offline storage?',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        child: const Text(
                                          'Delete',
                                          style: TextStyle(
                                            color: Colors.redAccent,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  await _musicService.deleteDownloadedSong(
                                    song['id']!,
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _musicService.playDownloadedSong(song);
                        },
                      );
                    },
                  ),

            // TAB 2: DEVICE AUDIO
            _buildDeviceAudioTab(deviceSongs),

            // TAB 3: LIKED SONGS
            liked.isEmpty
                ? _buildEmptyState(
                    icon: Icons.favorite_border_rounded,
                    title: 'No liked songs yet',
                    subtitle:
                        'Tap the heart icon while playing any song to save it in your favorites collection.',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 160, top: 12),
                    itemCount: liked.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return _buildActionHeader(
                          count: liked.length,
                          onPlayAll: () {
                            HapticFeedback.lightImpact();
                            _musicService.playLikedSong(liked.first);
                          },
                          onShuffle: () {
                            HapticFeedback.lightImpact();
                            _musicService.toggleShuffle();
                            _musicService.playLikedSong(liked.first);
                          },
                        );
                      }

                      final song = liked[index - 1];
                      final songId = song['id'] ?? '';
                      final isCurrent =
                          _musicService.currentSong?.id.value == songId;

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                            width: 52,
                            height: 52,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.network(
                                  song['thumbnail'] ?? '',
                                  fit: BoxFit.cover,
                                  cacheWidth: 120,
                                  cacheHeight: 120,
                                  errorBuilder: (_, _, _) => Container(
                                    color: const Color(0xFF1E1E28),
                                    child: const Icon(
                                      Icons.music_note,
                                      color: Colors.white54,
                                    ),
                                  ),
                                ),
                                if (isCurrent)
                                  Container(
                                    color: Colors.black54,
                                    child: Center(
                                      child: AnimatedEqualizer(
                                        isPlaying: _musicService.isPlaying,
                                        size: 22,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        title: Text(
                          song['title'] ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            fontSize: 14.5,
                            letterSpacing: -0.2,
                          ),
                        ),
                        subtitle: Text(
                          song['author'] ?? '',
                          maxLines: 1,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 12.5,
                          ),
                        ),
                        trailing: IconButton(
                          icon: const Icon(
                            Icons.favorite_rounded,
                            color: Color(0xFFFA2D48),
                            size: 22,
                          ),
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            _musicService.removeLikedSong(song['id'] ?? '');
                          },
                        ),
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _musicService.playLikedSong(song);
                        },
                      );
                    },
                  ),

            // TAB 3: PLAYLISTS
            _musicService.customPlaylists.isEmpty
                ? _buildEmptyState(
                    icon: Icons.featured_play_list_outlined,
                    title: 'No custom playlists yet',
                    subtitle:
                        'Import any public playlist from Spotify or create your own custom playlist.',
                    action: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElevatedButton.icon(
                          icon: const Icon(Icons.download_rounded, size: 18),
                          label: const Text('Import Spotify / Exportify'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1DB954),
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const SpotifyImportScreen(),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('New Playlist'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.2),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            _showCreatePlaylistDialog();
                          },
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 160, top: 12),
                    itemCount: _musicService.customPlaylists.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${_musicService.customPlaylists.length} Playlists',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.add_circle_outline_rounded,
                                      color: Colors.white70,
                                      size: 20,
                                    ),
                                    tooltip: 'New Playlist',
                                    onPressed: _showCreatePlaylistDialog,
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.queue_music_rounded,
                                      color: Color(0xFF1DB954),
                                      size: 20,
                                    ),
                                    tooltip: 'Import from Spotify',
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const SpotifyImportScreen(),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }

                      final playlist = _musicService.customPlaylists[index - 1];
                      final name =
                          (playlist['name'] as String?) ?? 'Unknown Playlist';
                      final songs = List<Map<String, dynamic>>.from(
                        playlist['songs'] ?? [],
                      );
                      final id = (playlist['id'] as String?) ?? '';
                      final firstThumbnail = songs.isNotEmpty
                          ? songs.first['thumbnail'] as String?
                          : null;

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: _prefs.themeColor.withValues(alpha: 0.16),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.08),
                                width: 1,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child:
                                firstThumbnail != null &&
                                    firstThumbnail.isNotEmpty
                                ? Image.network(
                                    firstThumbnail,
                                    fit: BoxFit.cover,
                                    cacheWidth: 120,
                                    cacheHeight: 120,
                                    errorBuilder: (_, _, _) => Icon(
                                      Icons.queue_music_rounded,
                                      color: _prefs.themeColor.withValues(
                                        alpha: 0.85,
                                      ),
                                      size: 26,
                                    ),
                                  )
                                : Icon(
                                    Icons.queue_music_rounded,
                                    color: _prefs.themeColor.withValues(
                                      alpha: 0.85,
                                    ),
                                    size: 26,
                                  ),
                          ),
                        ),
                        title: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            fontSize: 15,
                            letterSpacing: -0.2,
                          ),
                        ),
                        subtitle: Text(
                          '${songs.length} tracks',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 13,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.edit_outlined,
                                color: Colors.white54,
                                size: 20,
                              ),
                              tooltip: 'Rename playlist',
                              onPressed: () {
                                HapticFeedback.lightImpact();
                                _showRenamePlaylistDialog(id, name);
                              },
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.white54,
                                size: 22,
                              ),
                              tooltip: 'Delete playlist',
                              onPressed: () {
                                HapticFeedback.lightImpact();
                                _showDeletePlaylistDialog(id, name);
                              },
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(
                                Icons.play_circle_fill_rounded,
                                color: Colors.white,
                                size: 36,
                              ),

                              onPressed: songs.isEmpty
                                  ? null
                                  : () {
                                      HapticFeedback.lightImpact();
                                      _musicService.playCustomPlaylist(id, 0);
                                    },
                            ),
                          ],
                        ),
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  CustomPlaylistScreen(playlistId: id),
                            ),
                          );
                        },
                      );
                    },
                  ),

            // TAB 4: FOLLOWED ARTISTS
            followedArtists.isEmpty
                ? _buildEmptyState(
                    icon: Icons.person_add_alt_1_rounded,
                    title: 'No followed artists yet',
                    subtitle:
                        'Tap the Follow button on any artist profile to keep track of their releases and albums here.',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 160, top: 12),
                    itemCount: followedArtists.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${followedArtists.length} ${followedArtists.length == 1 ? 'Followed Artist' : 'Followed Artists'}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      final artistName = followedArtists[index - 1];
                      final artistItem = DynamicArtistService().findArtist(
                        artistName,
                      );

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        leading: Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.18),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.35),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child:
                                artistItem != null &&
                                    artistItem.imageUrl.isNotEmpty
                                ? Image.network(
                                    artistItem.imageUrl,
                                    fit: BoxFit.cover,
                                    cacheWidth: 120,
                                    cacheHeight: 120,
                                    errorBuilder: (_, _, _) =>
                                        _buildArtistAvatarFallback(artistName),
                                  )
                                : _buildArtistAvatarFallback(artistName),
                          ),
                        ),
                        title: Text(
                          artistItem?.name ?? artistName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            fontSize: 15,
                            letterSpacing: -0.2,
                          ),
                        ),
                        subtitle: Row(
                          children: [
                            if (artistItem != null &&
                                artistItem.badge.isNotEmpty) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 1.5,
                                ),
                                margin: const EdgeInsets.only(right: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  artistItem.badge,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                            Flexible(
                              child: Text(
                                artistItem?.genre ?? 'Followed Artist',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.55),
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.15),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(
                                Icons.check_rounded,
                                size: 12,
                                color: Colors.white70,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Following',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ArtistProfileScreen(
                                artist: artistItem,
                                artistName: artistItem?.name ?? artistName,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),

            // TAB 5: LISTENING HISTORY
            history.isEmpty
                ? _buildEmptyState(
                    icon: Icons.history_toggle_off_rounded,
                    title: 'No listening history yet',
                    subtitle:
                        'Songs you stream will automatically appear here for quick replay.',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 160, top: 12),
                    itemCount: history.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${history.length} Recently Played',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              TextButton.icon(
                                icon: const Icon(
                                  Icons.delete_sweep_rounded,
                                  size: 16,
                                  color: Colors.white54,
                                ),
                                label: const Text(
                                  'Clear',
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 13,
                                  ),
                                ),
                                onPressed: () {
                                  HapticFeedback.lightImpact();
                                  _prefs.clearListeningHistory();
                                },
                              ),
                            ],
                          ),
                        );
                      }

                      final song = history[index - 1];
                      final songId = song['id'] ?? '';
                      final isCurrent =
                          _musicService.currentSong?.id.value == songId;

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                            width: 52,
                            height: 52,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.network(
                                  song['thumbnail'] ?? '',
                                  fit: BoxFit.cover,
                                  cacheWidth: 120,
                                  cacheHeight: 120,
                                  errorBuilder: (_, _, _) => Container(
                                    color: const Color(0xFF1E1E28),
                                    child: const Icon(
                                      Icons.music_note,
                                      color: Colors.white54,
                                    ),
                                  ),
                                ),
                                if (isCurrent)
                                  Container(
                                    color: Colors.black54,
                                    child: Center(
                                      child: AnimatedEqualizer(
                                        isPlaying: _musicService.isPlaying,
                                        size: 22,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        title: Text(
                          song['title'] ?? 'Unknown Track',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            fontSize: 14.5,
                            letterSpacing: -0.2,
                          ),
                        ),
                        subtitle: Text(
                          song['author'] ?? 'Unknown Artist',
                          maxLines: 1,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 12.5,
                          ),
                        ),
                        trailing: const Icon(
                          Icons.play_circle_fill_rounded,
                          color: Colors.white38,
                          size: 24,
                        ),
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _musicService.playHistorySong(song);
                        },
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceAudioTab(List<Map<String, String>> deviceSongs) {
    if (_deviceAudio.isScanning) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 42,
                height: 42,
                child: CircularProgressIndicator(
                  color: Color(0xFF1DB954),
                  strokeWidth: 3,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Scanning Storage...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _deviceAudio.scanStatusMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (deviceSongs.isEmpty) {
      return _buildEmptyState(
        icon: Icons.audio_file_rounded,
        title: 'No device songs indexed',
        subtitle:
            'Scan device storage or pick audio files (MP3, FLAC, M4A, WAV, AAC, OPUS) from your phone to listen offline with lossless quality.',
        action: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.manage_search_rounded, size: 18),
              label: const Text(
                'Scan Device Storage',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1DB954),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              onPressed: () async {
                HapticFeedback.mediumImpact();
                final messenger = ScaffoldMessenger.of(context);
                final count = await _deviceAudio.scanDeviceStorage();
                if (!mounted) return;
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      count > 0
                          ? 'Found $count device tracks!'
                          : _deviceAudio.scanStatusMessage,
                    ),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              icon: const Icon(
                Icons.folder_open_rounded,
                size: 18,
                color: Colors.white70,
              ),
              label: const Text(
                'Pick Audio Files / Folders',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              onPressed: () {
                HapticFeedback.lightImpact();
                _showPickOptionsSheet();
              },
            ),
          ],
        ),
      );
    }

    final query = _deviceSearchFilter.trim().toLowerCase();
    final filteredSongs = query.isEmpty
        ? deviceSongs
        : deviceSongs.where((s) {
            final t = (s['title'] ?? '').toLowerCase();
            final a = (s['author'] ?? '').toLowerCase();
            final al = (s['album'] ?? '').toLowerCase();
            return t.contains(query) || a.contains(query) || al.contains(query);
          }).toList();

    int totalBytes = 0;
    for (final s in deviceSongs) {
      totalBytes += int.tryParse(s['fileSize'] ?? '0') ?? 0;
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 160, top: 12),
      itemCount: filteredSongs.length + 2,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildActionHeader(
                count: filteredSongs.length,
                onPlayAll: () {
                  HapticFeedback.lightImpact();
                  if (filteredSongs.isNotEmpty) {
                    _musicService.playDeviceSong(
                      filteredSongs.first,
                      queue: filteredSongs,
                      startIndex: 0,
                    );
                  }
                },
                onShuffle: () {
                  HapticFeedback.lightImpact();
                  if (filteredSongs.isNotEmpty) {
                    _musicService.toggleShuffle();
                    _musicService.playDeviceSong(
                      filteredSongs.first,
                      queue: filteredSongs,
                      startIndex: 0,
                    );
                  }
                },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.12),
                            width: 0.8,
                          ),
                        ),
                        child: TextField(
                          controller: _deviceSearchController,
                          onChanged: (val) {
                            setState(() {
                              _deviceSearchFilter = val;
                            });
                          },
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                          decoration: InputDecoration(
                            hintText:
                                'Filter ${deviceSongs.length} local tracks...',
                            hintStyle: TextStyle(
                              color: Colors.white.withValues(alpha: 0.35),
                              fontSize: 13,
                            ),
                            prefixIcon: const Icon(
                              Icons.search_rounded,
                              color: Colors.white54,
                              size: 18,
                            ),
                            suffixIcon: _deviceSearchFilter.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(
                                      Icons.close_rounded,
                                      color: Colors.white54,
                                      size: 16,
                                    ),
                                    onPressed: () {
                                      _deviceSearchController.clear();
                                      setState(() {
                                        _deviceSearchFilter = '';
                                      });
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 10,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(
                        Icons.refresh_rounded,
                        color: Colors.white70,
                        size: 20,
                      ),
                      tooltip: 'Rescan Device',
                      onPressed: () async {
                        HapticFeedback.mediumImpact();
                        final messenger = ScaffoldMessenger.of(context);
                        final count = await _deviceAudio.scanDeviceStorage();
                        if (!mounted) return;
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              count > 0
                                  ? 'Found $count new tracks!'
                                  : _deviceAudio.scanStatusMessage,
                            ),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.add_rounded,
                        color: Colors.white70,
                        size: 22,
                      ),
                      tooltip: 'Add Audio Files',
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        _showPickOptionsSheet();
                      },
                    ),
                  ],
                ),
              ),
              if (totalBytes > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 4,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Storage Used: ${_formatBytes(totalBytes)} • ${deviceSongs.length} local files',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
            ],
          );
        }

        if (index == 1 && filteredSongs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(40),
            child: Center(
              child: Text(
                'No local tracks matching "$_deviceSearchFilter"',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 14,
                ),
              ),
            ),
          );
        }

        if (filteredSongs.isEmpty) {
          return const SizedBox.shrink();
        }

        final song = filteredSongs[index - 1];
        final songId = song['id'] ?? '';
        final isCurrent = _musicService.currentSong?.id.value == songId;
        final fileSize = int.tryParse(song['fileSize'] ?? '0') ?? 0;
        final format = song['format'] ?? 'AUDIO';

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          leading: _buildDeviceArtwork(song['thumbnail'], isCurrent),
          title: Text(
            song['title'] ?? 'Unknown Track',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Colors.white,
              fontSize: 14.5,
              letterSpacing: -0.2,
            ),
          ),
          subtitle: Row(
            children: [
              Flexible(
                child: Text(
                  song['author'] ?? 'Device Audio',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 12.5,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 5,
                  vertical: 1.5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF1DB954).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  format,
                  style: const TextStyle(
                    color: Color(0xFF1DB954),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (fileSize > 0) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1.5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    _formatBytes(fileSize),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
          trailing: IconButton(
            icon: const Icon(
              Icons.more_vert_rounded,
              color: Colors.white54,
              size: 20,
            ),
            onPressed: () {
              HapticFeedback.lightImpact();
              _showDeviceSongOptions(song);
            },
          ),
          onTap: () {
            HapticFeedback.lightImpact();
            _musicService.playDeviceSong(
              song,
              queue: filteredSongs,
              startIndex: index - 1,
            );
          },
        );
      },
    );
  }

  Widget _buildDeviceArtwork(String? thumbUrl, bool isCurrent) {
    Widget image;
    if (thumbUrl != null && thumbUrl.startsWith('file://')) {
      final filePath = thumbUrl.replaceFirst('file://', '');
      final file = File(filePath);
      if (file.existsSync()) {
        image = Image.file(
          file,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _defaultDeviceArt(),
        );
      } else {
        image = _defaultDeviceArt();
      }
    } else if (thumbUrl != null && thumbUrl.startsWith('http')) {
      image = Image.network(
        thumbUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _defaultDeviceArt(),
      );
    } else {
      image = _defaultDeviceArt();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 52,
        height: 52,
        child: Stack(
          fit: StackFit.expand,
          children: [
            image,
            if (isCurrent)
              Container(
                color: Colors.black54,
                child: Center(
                  child: AnimatedEqualizer(
                    isPlaying: _musicService.isPlaying,
                    size: 22,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _defaultDeviceArt() {
    return Container(
      color: const Color(0xFF1E1E28),
      child: const Icon(
        Icons.audio_file_rounded,
        color: Colors.white54,
        size: 26,
      ),
    );
  }

  void _showPickOptionsSheet() {
    final messenger = ScaffoldMessenger.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A24),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Import Device Music',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                ),
              ),
              const SizedBox(height: 14),
              ListTile(
                leading: const Icon(
                  Icons.file_copy_rounded,
                  color: Color(0xFF1DB954),
                ),
                title: const Text(
                  'Pick Audio Files',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  'Select MP3, FLAC, M4A, WAV, AAC from device storage',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  final count = await _deviceAudio.pickAudioFiles();
                  if (!mounted || count <= 0) return;
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Added $count audio tracks!'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.folder_open_rounded,
                  color: Colors.amberAccent,
                ),
                title: const Text(
                  'Select Music Folder',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  'Recursively index all songs in a selected directory',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  final count = await _deviceAudio.pickDirectory();
                  if (!mounted || count <= 0) return;
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Imported $count songs from folder!'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.phone_android_rounded,
                  color: Colors.lightBlueAccent,
                ),
                title: const Text(
                  'Auto-Scan Device Storage',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  'Scans standard Music and Download directories',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  final count = await _deviceAudio.scanDeviceStorage();
                  if (!mounted) return;
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        count > 0
                            ? 'Found $count device tracks!'
                            : _deviceAudio.scanStatusMessage,
                      ),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeviceSongOptions(Map<String, String> song) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A24),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: _buildDeviceArtwork(song['thumbnail'], false),
                title: Text(
                  song['title'] ?? 'Unknown Track',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  song['author'] ?? 'Device Audio',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                ),
              ),
              const Divider(color: Colors.white12),
              ListTile(
                leading: const Icon(
                  Icons.playlist_add_rounded,
                  color: Colors.white70,
                ),
                title: const Text(
                  'Add to Custom Playlist',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _showAddToPlaylistSheet(song);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.info_outline_rounded,
                  color: Colors.white70,
                ),
                title: const Text(
                  'File Information',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _showFileInfoDialog(song);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.redAccent,
                ),
                title: const Text(
                  'Remove from Library',
                  style: TextStyle(color: Colors.redAccent),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _deviceAudio.removeSong(song['id'] ?? '');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFileInfoDialog(Map<String, String> song) {
    final size = int.tryParse(song['fileSize'] ?? '0') ?? 0;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E28),
        title: const Text(
          'Track Details',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('Title', song['title'] ?? ''),
            _buildInfoRow('Artist', song['author'] ?? ''),
            _buildInfoRow('Album', song['album'] ?? ''),
            _buildInfoRow('Format', song['format'] ?? ''),
            _buildInfoRow('File Size', _formatBytes(size)),
            _buildInfoRow('Path', song['localPath'] ?? ''),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  void _showAddToPlaylistSheet(Map<String, String> song) {
    final playlists = _musicService.customPlaylists;
    if (playlists.isEmpty) {
      _showCreatePlaylistDialog();
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E28),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Add to Playlist',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            ...playlists.map(
              (p) => ListTile(
                leading: const Icon(
                  Icons.playlist_play_rounded,
                  color: Colors.white70,
                ),
                title: Text(
                  (p['name'] as String?) ?? 'Playlist',
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () {
                  final video = Video(
                    VideoId(
                      song['id'] ??
                          DeviceAudioService.generateLocalId(
                            song['localPath'] ?? '',
                          ),
                    ),
                    song['title'] ?? 'Unknown',
                    song['author'] ?? 'Device Audio',
                    ChannelId('UC0WP5P-fwGlLyO4yOE76T8g'),
                    DateTime.now(),
                    '',
                    null,
                    '',
                    null,
                    ThumbnailSet(song['id'] ?? ''),
                    null,
                    Engagement(0, null, null),
                    false,
                  );
                  final pId = (p['id'] as String?) ?? '';
                  if (pId.isNotEmpty) {
                    _musicService.addSongToPlaylist(pId, video);
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Added to ${p['name']}'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionHeader({
    required int count,
    required VoidCallback onPlayAll,
    required VoidCallback onShuffle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.black,
                size: 20,
              ),
              label: Text(
                'Play All ($count)',
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: onPlayAll,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(
                Icons.shuffle_rounded,
                color: Colors.white70,
                size: 18,
              ),
              label: const Text(
                'Shuffle',
                style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: onShuffle,
            ),
          ),
        ],
      ),
    );
  }

  void _showCreatePlaylistDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E28),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Create New Playlist',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Playlist name',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.2),
              ),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white70),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                _musicService.createPlaylist(name);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showRenamePlaylistDialog(String id, String currentName) {
    final controller = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E28),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Rename Playlist',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'New playlist name',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.2),
              ),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white70),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty && newName != currentName) {
                _musicService.renamePlaylist(id, newName);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeletePlaylistDialog(String id, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E28),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete Playlist',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to delete "$name"?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              _musicService.deletePlaylist(id);
              Navigator.pop(ctx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildPillTab(String title, int count) {
    return Tab(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.white.withValues(alpha: 0.04),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.06),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(width: 7),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? action,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: const Color(0xFF161622),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white12, width: 1),
              ),
              child: Icon(icon, size: 48, color: Colors.white54),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 13,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[const SizedBox(height: 18), action],
          ],
        ),
      ),
    );
  }

  Widget _buildArtistAvatarFallback(String name) {
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'A';
    return Container(
      color: const Color(0xFF1E1E28),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

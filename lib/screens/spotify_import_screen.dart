import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:app_links/app_links.dart';
import 'package:http/http.dart' as http;
import '../services/music_service.dart';
import '../services/api_config.dart';

class SpotifyImportScreen extends StatefulWidget {
  const SpotifyImportScreen({super.key});

  @override
  State<SpotifyImportScreen> createState() => _SpotifyImportScreenState();
}

class _SpotifyImportScreenState extends State<SpotifyImportScreen> {
  final _appLinks = AppLinks();
  final _urlController = TextEditingController();
  
  String? _accessToken;
  bool _isLoading = false;
  double _progress = 0.0;
  String _statusMessage = '';
  String? _importedPlaylistId;
  String? _importedPlaylistName;
  int _importedSuccessCount = 0;
  int _importedTotalCount = 0;

  List<dynamic> _userPlaylists = [];
  bool _showAdvancedOAuth = false;

  @override
  void initState() {
    super.initState();
    _initDeepLinkListener();
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  void _initDeepLinkListener() {
    _appLinks.uriLinkStream.listen((uri) {
      if (uri.scheme == 'dilsemusic' && uri.host == 'spotify-auth') {
        final token = uri.queryParameters['token'];
        final error = uri.queryParameters['error'];

        if (token != null) {
          setState(() {
            _accessToken = token;
            _statusMessage = 'Authenticated! Fetching playlists...';
          });
          _fetchUserPlaylists();
        } else if (error != null) {
          setState(() {
            _statusMessage = 'Authentication failed: $error';
          });
        }
      }
    });
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.trim().isNotEmpty) {
      setState(() {
        _urlController.text = data.text!.trim();
      });
      HapticFeedback.selectionClick();
    }
  }

  String _extractPlaylistId(String input) {
    final clean = input.trim();
    final regex = RegExp(r'(?:playlist[/:])?([a-zA-Z0-9]{22})');
    final match = regex.firstMatch(clean);
    if (match != null && match.groupCount >= 1) {
      return match.group(1)!;
    }
    return clean;
  }

  Future<void> _importFromInputUrl() async {
    final rawText = _urlController.text.trim();
    if (rawText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please paste a Spotify playlist link first.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final playlistId = _extractPlaylistId(rawText);
    await _startImport(playlistId: playlistId, playlistName: 'Spotify Playlist', isPublic: true);
  }

  Future<void> _startImport({
    required String playlistId,
    required String playlistName,
    required bool isPublic,
  }) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _progress = 0.05;
      _statusMessage = 'Contacting server to extract tracks...';
      _importedPlaylistId = null;
    });

    try {
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/spotify/import'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'access_token': _accessToken,
          'playlist_id': playlistId,
          'is_public': isPublic,
        }),
      ).timeout(const Duration(seconds: 25));

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final tracks = List<String>.from(data['tracks'] ?? []);
        final fetchedName = (data['name'] as String?) ?? playlistName;

        if (tracks.isEmpty) {
          setState(() {
            _statusMessage = 'No tracks found. Please make sure the playlist is Public.';
          });
          return;
        }

        setState(() {
          _statusMessage = 'Found ${tracks.length} tracks in "$fetchedName". Matching audio...';
          _progress = 0.1;
        });

        // Create local custom playlist
        final newPlaylistId = MusicService().createPlaylist(fetchedName);

        int successCount = 0;
        final totalTracks = tracks.length;

        for (int i = 0; i < totalTracks; i++) {
          final query = tracks[i];
          final currentNum = i + 1;

          setState(() {
            _progress = 0.1 + (0.9 * (currentNum / totalTracks));
            _statusMessage = 'Matching $currentNum of $totalTracks:\n"$query"';
          });

          try {
            final results = await MusicService().searchSongs(query, page: 1);
            if (results.isNotEmpty) {
              MusicService().addSongToPlaylist(newPlaylistId, results.first);
              successCount++;
            }
          } catch (_) {
            // Keep going if an individual search fails
          }
        }

        HapticFeedback.mediumImpact();
        setState(() {
          _importedPlaylistId = newPlaylistId;
          _importedPlaylistName = fetchedName;
          _importedSuccessCount = successCount;
          _importedTotalCount = totalTracks;
          _statusMessage = 'Successfully imported $successCount of $totalTracks tracks!';
          _progress = 1.0;
        });
      } else {
        final err = json.decode(res.body);
        setState(() {
          _statusMessage = 'Import error: ${err['detail'] ?? 'Could not fetch playlist'}';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error connecting to server: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // --- Optional / Advanced OAuth Flows ---

  Future<void> _loginWithSpotify() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Opening Spotify login...';
    });

    try {
      final res = await http.get(Uri.parse('${ApiConfig.baseUrl}/spotify/login'));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final url = Uri.parse(data['url']);
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        } else {
          setState(() => _statusMessage = 'Could not launch browser.');
        }
      } else {
        setState(() => _statusMessage = 'Server requires Spotify developer keys for login.');
      }
    } catch (e) {
      setState(() => _statusMessage = 'Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchUserPlaylists() async {
    if (_accessToken == null) return;
    setState(() => _isLoading = true);

    try {
      final res = await http.get(Uri.parse('${ApiConfig.baseUrl}/spotify/playlists?access_token=$_accessToken'));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        setState(() {
          _userPlaylists = data['playlists'] ?? [];
          _statusMessage = 'Found ${_userPlaylists.length} playlists in your account.';
        });
      } else {
        setState(() => _statusMessage = 'Failed to fetch playlists.');
      }
    } catch (e) {
      setState(() => _statusMessage = 'Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const spotifyGreen = Color(0xFF1DB954);

    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0B0F),
        elevation: 0,
        title: const Text(
          'Import from Spotify',
          style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 18),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    spotifyGreen.withValues(alpha: 0.15),
                    const Color(0xFF14141E),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: spotifyGreen.withValues(alpha: 0.25)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: spotifyGreen.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.playlist_add_check_rounded, color: spotifyGreen, size: 34),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Instant Spotify Importer',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Paste any public Spotify playlist link to save and stream it on DilSe instantly.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.65),
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // URL Input Field & Paste Button
            const Text(
              'Spotify Playlist Link',
              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF181824),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: TextField(
                controller: _urlController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                enabled: !_isLoading,
                decoration: InputDecoration(
                  hintText: 'https://open.spotify.com/playlist/...',
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 13),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  border: InputBorder.none,
                  prefixIcon: const Icon(Icons.link_rounded, color: spotifyGreen, size: 22),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_urlController.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.clear, color: Colors.white54, size: 18),
                          onPressed: () => setState(() => _urlController.clear()),
                        ),
                      IconButton(
                        icon: const Icon(Icons.content_paste_rounded, color: spotifyGreen, size: 20),
                        tooltip: 'Paste from clipboard',
                        onPressed: _isLoading ? null : _pasteFromClipboard,
                      ),
                      const SizedBox(width: 4),
                    ],
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),

            const SizedBox(height: 16),

            // Import Button
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.black),
                      )
                    : const Icon(Icons.download_rounded, size: 22),
                label: Text(
                  _isLoading ? 'Importing Playlist...' : 'Import Playlist',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: spotifyGreen,
                  foregroundColor: Colors.black,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _isLoading ? null : _importFromInputUrl,
              ),
            ),

            const SizedBox(height: 20),

            // Progress & Status Card
            if (_isLoading || _statusMessage.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF14141E),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _importedPlaylistId != null
                        ? spotifyGreen.withValues(alpha: 0.4)
                        : Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Column(
                  children: [
                    if (_isLoading) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: _progress > 0 ? _progress : null,
                          backgroundColor: Colors.white10,
                          color: spotifyGreen,
                          minHeight: 6,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Text(
                      _statusMessage,
                      style: TextStyle(
                        color: _importedPlaylistId != null ? Colors.white : Colors.white70,
                        fontSize: 13,
                        fontWeight: _importedPlaylistId != null ? FontWeight.w600 : FontWeight.normal,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    // Success Action Buttons
                    if (_importedPlaylistId != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: spotifyGreen.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Saved "$_importedPlaylistName" ($_importedSuccessCount / $_importedTotalCount resolved)',
                          style: const TextStyle(color: spotifyGreen, fontWeight: FontWeight.w600, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Go to Library'),
                            ),
                          ),

                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.play_arrow_rounded, size: 20),
                              label: const Text('Play Now'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: spotifyGreen,
                                foregroundColor: Colors.black,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () {
                                MusicService().playCustomPlaylist(_importedPlaylistId!, 0);
                                Navigator.pop(context);
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

            const SizedBox(height: 24),

            // How to Make Playlist Public Tip
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF12121A),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded, color: Colors.white54, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'How to get your Spotify playlist link:',
                          style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '1. In Spotify, open your playlist and tap "..." (Options).\n'
                          '2. Tap "Share" → "Copy Link".\n'
                          '3. Ensure the playlist is Public (or "Add to profile").',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 12,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Optional Advanced OAuth Accordion
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                initiallyExpanded: _showAdvancedOAuth,
                onExpansionChanged: (val) => setState(() => _showAdvancedOAuth = val),
                title: Text(
                  'Developer Options (Spotify Account Login)',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Text(
                      'Requires Spotify Developer Client credentials configured on your backend server.',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12),
                    ),
                  ),
                  if (_accessToken == null)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.login_rounded, size: 18),
                      label: const Text('Log In With Spotify Account'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: spotifyGreen,
                        side: BorderSide(color: spotifyGreen.withValues(alpha: 0.4)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _isLoading ? null : _loginWithSpotify,
                    )
                  else ...[
                    Text(
                      'Your Spotify Playlists (${_userPlaylists.length})',
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _userPlaylists.length,
                      itemBuilder: (context, index) {
                        final pl = _userPlaylists[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(pl['name'] ?? 'Unknown', style: const TextStyle(color: Colors.white, fontSize: 14)),
                          subtitle: Text('${pl['total_tracks']} tracks', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                          trailing: IconButton(
                            icon: const Icon(Icons.download_rounded, color: spotifyGreen),
                            onPressed: _isLoading
                                ? null
                                : () => _startImport(
                                      playlistId: pl['id'] ?? '',
                                      playlistName: pl['name'] ?? 'Playlist',
                                      isPublic: false,
                                    ),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

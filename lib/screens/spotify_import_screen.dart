import 'dart:convert';
import 'package:flutter/material.dart';
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
  String? _accessToken;
  bool _isLoading = false;
  List<dynamic> _playlists = [];
  String _statusMessage = '';

  @override
  void initState() {
    super.initState();
    _initDeepLinkListener();
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
          _fetchPlaylists();
        } else if (error != null) {
          setState(() {
            _statusMessage = 'Authentication failed: $error';
          });
        }
      }
    });
  }

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
        setState(() => _statusMessage = 'Failed to get login URL.');
      }
    } catch (e) {
      setState(() => _statusMessage = 'Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchPlaylists() async {
    if (_accessToken == null) return;
    setState(() => _isLoading = true);

    try {
      final res = await http.get(Uri.parse('${ApiConfig.baseUrl}/spotify/playlists?access_token=$_accessToken'));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        setState(() {
          _playlists = data['playlists'] ?? [];
          _statusMessage = 'Found ${_playlists.length} playlists.';
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

  Future<void> _importPlaylist(String playlistId, String playlistName, bool isPublic) async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Importing tracks from $playlistName...';
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
      );

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final tracks = List<String>.from(data['tracks'] ?? []);
        
        setState(() => _statusMessage = 'Resolving ${tracks.length} tracks on YouTube...');
        
        final playlistId = MusicService().createPlaylist(playlistName);
        
        int successCount = 0;
        for (final query in tracks) {
          final results = await MusicService().searchSongs(query, page: 1);
          if (results.isNotEmpty) {
            MusicService().addSongToPlaylist(playlistId, results.first);
            successCount++;
          }
        }
        
        setState(() {
          _statusMessage = 'Successfully imported $successCount out of ${tracks.length} tracks to $playlistName!';
        });
      } else {
        setState(() => _statusMessage = 'Failed to import playlist.');
      }
    } catch (e) {
      setState(() => _statusMessage = 'Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _importPublicPlaylistFromUrl() async {
    final controller = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E28),
        title: const Text('Import Public Playlist', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Paste Spotify Playlist URL',
            hintStyle: TextStyle(color: Colors.white54),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Import', style: TextStyle(color: Color(0xFF1DB954))),
          ),
        ],
      ),
    );

    if (url != null && url.isNotEmpty) {
      // Extract playlist ID from URL
      final regex = RegExp(r'playlist/([a-zA-Z0-9]+)');
      final match = regex.firstMatch(url);
      if (match != null && match.groupCount >= 1) {
        final playlistId = match.group(1)!;
        await _importPlaylist(playlistId, 'Public Playlist', true);
      } else {
        setState(() => _statusMessage = 'Invalid Spotify playlist URL.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0B0F),
        title: const Text('Import from Spotify', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_statusMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text(
                  _statusMessage,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ),
            
            if (_accessToken == null) ...[
              const Icon(Icons.music_note_rounded, size: 80, color: Color(0xFF1DB954)),
              const SizedBox(height: 20),
              const Text(
                'Seamlessly import your Spotify playlists to DilSe.',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                icon: const Icon(Icons.login),
                label: const Text('Login with Spotify (Private & Public)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1DB954),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isLoading ? null : _loginWithSpotify,
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                icon: const Icon(Icons.link),
                label: const Text('Import Public Playlist via URL'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white30),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isLoading ? null : _importPublicPlaylistFromUrl,
              ),
            ] else ...[
              const Text(
                'Your Playlists',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _playlists.isEmpty
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF1DB954)))
                    : ListView.builder(
                        itemCount: _playlists.length,
                        itemBuilder: (context, index) {
                          final pl = _playlists[index];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(vertical: 8),
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: pl['image'] != ''
                                  ? Image.network(pl['image'], width: 50, height: 50, fit: BoxFit.cover)
                                  : Container(
                                      width: 50,
                                      height: 50,
                                      color: Colors.white12,
                                      child: const Icon(Icons.music_note, color: Colors.white54),
                                    ),
                            ),
                            title: Text((pl['name'] as String?) ?? 'Unknown', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            subtitle: Text('${pl['total_tracks']} tracks • ${pl['owner']}', style: const TextStyle(color: Colors.white54)),
                            trailing: IconButton(
                              icon: const Icon(Icons.download_rounded, color: Color(0xFF1DB954)),
                              onPressed: _isLoading ? null : () => _importPlaylist((pl['id'] as String?) ?? '', (pl['name'] as String?) ?? 'Playlist', false),
                            ),
                          );
                        },
                      ),
              ),
            ],
            
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 16.0),
                child: Center(child: CircularProgressIndicator(color: Color(0xFF1DB954))),
              ),
          ],
        ),
      ),
    );
  }
}

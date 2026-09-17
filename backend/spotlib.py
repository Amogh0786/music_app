import os
import re
import json
import urllib.request
import html

# Optional Spotify Developer Credentials (only needed for OAuth user login)
# For public playlists, zero credentials or third-party packages are required!
SPOTIPY_CLIENT_ID = os.environ.get("SPOTIPY_CLIENT_ID")
SPOTIPY_CLIENT_SECRET = os.environ.get("SPOTIPY_CLIENT_SECRET")
SPOTIPY_REDIRECT_URI = os.environ.get("SPOTIPY_REDIRECT_URI")



def extract_spotify_playlist_id(url_or_id: str) -> str:
    """Extracts a 22-character Spotify playlist ID from any URL or string."""
    clean = url_or_id.strip()
    match = re.search(r'(?:playlist[/:]|^)([a-zA-Z0-9]{22})', clean)
    if match:
        return match.group(1)
    return clean


def get_public_playlist_info(playlist_url_or_id: str) -> dict:
    """
    Fetches public Spotify playlist details (name & track queries) directly
    without requiring any Spotify Developer accounts, API keys, or Spotify Premium.
    """
    playlist_id = extract_spotify_playlist_id(playlist_url_or_id)
    embed_url = f"https://open.spotify.com/embed/playlist/{playlist_id}"
    
    headers = {
        "User-Agent": (
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
            "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        ),
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
        "Accept-Language": "en-US,en;q=0.9",
    }
    
    try:
        req = urllib.request.Request(embed_url, headers=headers)
        with urllib.request.urlopen(req, timeout=12) as response:
            html_content = response.read().decode("utf-8")
            
        match = re.search(r'<script id="__NEXT_DATA__" type="application/json">(.*?)</script>', html_content)
        if match:
            data = json.loads(match.group(1))
            entity = (
                data.get("props", {})
                .get("pageProps", {})
                .get("state", {})
                .get("data", {})
                .get("entity", {})
            )
            playlist_name = html.unescape(entity.get("name") or "Spotify Playlist")
            raw_track_list = entity.get("trackList", [])
            
            tracks = []
            for item in raw_track_list:
                title = html.unescape(item.get("title") or "").strip()
                # Replace non-breaking space \xa0 with a regular space
                subtitle = html.unescape(item.get("subtitle") or "").replace("\xa0", " ").strip()
                if title:
                    query = f"{title} {subtitle}".strip()
                    tracks.append(query)
                    
            if tracks:
                return {
                    "id": playlist_id,
                    "name": playlist_name,
                    "tracks": tracks,
                    "total": len(tracks)
                }
    except Exception as e:
        print(f"[Spotlib] Zero-key embed scraper notice: {e}")

    # Fallback to official SpotifyClientCredentials if credentials are set in environment
    if SPOTIPY_CLIENT_ID and SPOTIPY_CLIENT_SECRET:
        try:
            import spotipy
            from spotipy.oauth2 import SpotifyClientCredentials
            client_credentials_manager = SpotifyClientCredentials(
                client_id=SPOTIPY_CLIENT_ID,
                client_secret=SPOTIPY_CLIENT_SECRET
            )
            sp = spotipy.Spotify(client_credentials_manager=client_credentials_manager)
            playlist_data = sp.playlist(playlist_id, fields="name,tracks.items(track(name,artists(name)))")
            playlist_name = playlist_data.get("name", "Spotify Playlist")
            tracks = extract_tracks_from_playlist(sp, playlist_id)
            return {
                "id": playlist_id,
                "name": playlist_name,
                "tracks": tracks,
                "total": len(tracks)
            }
        except Exception as e:
            print(f"[Spotlib] Official API fallback error: {e}")
            
    raise ValueError("Could not extract playlist. Please ensure the Spotify playlist is set to Public.")


def get_public_playlist_tracks(playlist_url_or_id: str) -> list:
    """Returns a list of clean '{track} {artist}' strings for public playlists."""
    info = get_public_playlist_info(playlist_url_or_id)
    return info.get("tracks", [])


# --- Spotify OAuth Methods (Optional: for private user libraries if keys are provided) ---

def get_spotify_oauth():
    """Returns a SpotifyOAuth object for handling user login and token generation."""
    if not SPOTIPY_CLIENT_ID or not SPOTIPY_CLIENT_SECRET:
        raise ValueError("Spotify Developer keys are not configured on this server. Use Public Playlist URL import instead.")
        
    import spotipy
    from spotipy.oauth2 import SpotifyOAuth
    return SpotifyOAuth(
        client_id=SPOTIPY_CLIENT_ID,
        client_secret=SPOTIPY_CLIENT_SECRET,
        redirect_uri=SPOTIPY_REDIRECT_URI,
        scope="playlist-read-private playlist-read-collaborative",
        cache_handler=spotipy.cache_handler.MemoryCacheHandler()
    )


def get_auth_url():
    """Generates the Spotify OAuth login URL."""
    sp_oauth = get_spotify_oauth()
    return sp_oauth.get_authorize_url()


def get_token_from_code(code: str):
    """Exchanges an authorization code for an access token."""
    sp_oauth = get_spotify_oauth()
    token_info = sp_oauth.get_access_token(code, as_dict=True)
    return token_info


def get_user_playlists(access_token: str):
    """Fetches the current user's playlists (public and private)."""
    import spotipy
    sp = spotipy.Spotify(auth=access_token)
    playlists = []

    
    try:
        results = sp.current_user_playlists(limit=50)
        while results:
            for item in results['items']:
                if item:
                    playlists.append({
                        "id": item["id"],
                        "name": item["name"],
                        "image": item["images"][0]["url"] if item.get("images") else "",
                        "owner": item["owner"]["display_name"] if item.get("owner") else "Unknown",
                        "total_tracks": item["tracks"]["total"] if item.get("tracks") else 0
                    })
            if results['next']:
                results = sp.next(results)
            else:
                results = None
    except Exception as e:
        print(f"Error fetching playlists: {e}")
        
    return playlists


def extract_tracks_from_playlist(sp, playlist_id):
    """Helper to extract clean track names and artists from a playlist."""
    tracks = []
    try:
        results = sp.playlist_items(playlist_id, fields="items(track(name,artists(name))),next")
        while results:
            for item in results['items']:
                track = item.get("track")
                if track:
                    name = track.get("name")
                    artists = ", ".join([a["name"] for a in track.get("artists", [])])
                    tracks.append(f"{name} {artists}".strip())
            if results['next']:
                results = sp.next(results)
            else:
                results = None
    except Exception as e:
        print(f"Error extracting tracks: {e}")
    return tracks


def get_private_playlist_tracks(access_token: str, playlist_id: str):
    """Fetches tracks from a private playlist using user access token."""
    sp = spotipy.Spotify(auth=access_token)
    return extract_tracks_from_playlist(sp, playlist_id)


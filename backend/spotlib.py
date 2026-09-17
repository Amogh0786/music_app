import os
import spotipy
from spotipy.oauth2 import SpotifyOAuth, SpotifyClientCredentials

# Make sure to set these environment variables in your deployment / .env
# SPOTIPY_CLIENT_ID
# SPOTIPY_CLIENT_SECRET
# SPOTIPY_REDIRECT_URI

def get_spotify_oauth():
    """Returns a SpotifyOAuth object for handling user login and token generation."""
    return SpotifyOAuth(
        client_id=os.environ.get("SPOTIPY_CLIENT_ID"),
        client_secret=os.environ.get("SPOTIPY_CLIENT_SECRET"),
        redirect_uri=os.environ.get("SPOTIPY_REDIRECT_URI"),
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

def get_public_playlist_tracks(playlist_url_or_id: str):
    """Fetches tracks from a public playlist using app credentials."""
    client_credentials_manager = SpotifyClientCredentials(
        client_id=os.environ.get("SPOTIPY_CLIENT_ID"),
        client_secret=os.environ.get("SPOTIPY_CLIENT_SECRET")
    )
    sp = spotipy.Spotify(client_credentials_manager=client_credentials_manager)
    return extract_tracks_from_playlist(sp, playlist_url_or_id)

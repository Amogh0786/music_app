from fastapi import FastAPI, HTTPException, Request, Response, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse, FileResponse, RedirectResponse
import yt_dlp
import urllib.request
import time
import json
import os
import shutil
import asyncio
from collections import Counter
from pathlib import Path
from typing import Dict, List, Optional
from pydantic import BaseModel
import re
import spotlib

# Co-occurrence storage: maps video_id -> Counter of next video_ids
co_occurrence: dict[str, Counter[str]] = {}
CO_OCCURRENCE_FILE = Path(__file__).with_name('co_occurrence.json')
_last_co_occurrence_save = 0.0

# Local disk audio cache for instant playback, seeking, and stutter-free streaming
CACHE_DIR = Path(__file__).with_name("audio_cache")
CACHE_DIR.mkdir(exist_ok=True)
_stream_locks: dict[str, asyncio.Lock] = {}

def _load_co_occurrence():
    global co_occurrence
    if CO_OCCURRENCE_FILE.exists():
        try:
            data = json.load(CO_OCCURRENCE_FILE.open())
            # Convert nested dicts to Counter
            co_occurrence = {k: Counter(v) for k, v in data.items()}
        except Exception:
            co_occurrence = {}
    else:
        co_occurrence = {}

def _save_co_occurrence():
    try:
        # Convert Counter to dict for JSON serialization
        serializable = {k: dict(v) for k, v in co_occurrence.items()}
        CO_OCCURRENCE_FILE.write_text(json.dumps(serializable))
    except Exception:
        pass

# Load on startup
_load_co_occurrence()

# Duration filter constants
MAX_DURATION_SECONDS = 600  # 10 minutes
ALLOWED_LONG_TITLES = ['mix', 'full album']

# Streaming resilience
MAX_STREAM_RETRIES = 3
STREAM_CHUNK_SIZE = 256 * 1024  # 256KB buffer for smooth playback without starvation

def _record_co_occurrence(current_id: str, next_id: str):
    """Update co-occurrence counters and persist to disk (throttled)."""
    global _last_co_occurrence_save
    if not current_id or not next_id:
        return
    counter = co_occurrence.setdefault(current_id, Counter())
    counter[next_id] += 1
    now = time.time()
    if now - _last_co_occurrence_save > 10:
        _save_co_occurrence()
        _last_co_occurrence_save = now

def _get_top_cooccurring(v_id: str, limit: int) -> List[str]:
    """Return up to `limit` video IDs that most frequently follow `v_id`.
    If fewer than `limit` entries exist, returns whatever is available.
    """
    counter = co_occurrence.get(v_id, Counter())
    return [vid for vid, _ in counter.most_common(limit)]




app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/")
def health_check():
    return {"status": "online", "service": "music-backend"}


@app.get("/version")
def version_check():
    return {
        "yt_dlp": yt_dlp.version.__version__,
        "node": shutil.which("node"),
        "commit": "v5-client-logging",
    }


@app.post("/client_log")
async def receive_client_log(request: Request):
    try:
        data = await request.json()
        print(f"📱 [CLIENT_LOG] {json.dumps(data)}")
    except Exception as e:
        print(f"📱 [CLIENT_LOG ERROR] {e}")
    return {"status": "ok"}


# In-memory URL & Search caches
_url_cache: dict[str, tuple[str, float]] = {}
_search_cache: dict[str, tuple[list[dict], float]] = {}
CACHE_TTL_SECONDS = 4 * 60 * 60  # 4 hours


PIPED_INSTANCES = [
    "https://pipedapi.kavin.rocks",
    "https://pipedapi.tokhmi.xyz",
    "https://pipedapi.adminforge.de",
    "https://api.piped.projectsegfau.lt"
]

def _get_youtube_url(video_id: str) -> str:
    now = time.time()
    if video_id in _url_cache:
        url, expires_at = _url_cache[video_id]
        if now < expires_at:
            return url
        else:
            del _url_cache[video_id]

    import random
    instances = PIPED_INSTANCES.copy()
    random.shuffle(instances)
    
    # 1. Try Piped API to bypass AWS IP blocks
    for base_url in instances:
        try:
            req = urllib.request.Request(f"{base_url}/streams/{video_id}", headers={"User-Agent": "Mozilla/5.0"})
            with urllib.request.urlopen(req, timeout=4) as resp:
                data = json.loads(resp.read().decode("utf-8"))
                audio_streams = data.get("audioStreams", [])
                if audio_streams:
                    # Prefer m4a format
                    m4a_streams = [s for s in audio_streams if "mp4a" in s.get("mimeType", "") or "m4a" in s.get("format", "")]
                    best_url = m4a_streams[0]["url"] if m4a_streams else audio_streams[0]["url"]
                    _url_cache[video_id] = (best_url, now + CACHE_TTL_SECONDS)
                    return best_url
        except Exception:
            continue

    # 2. Fallback to yt-dlp if Piped instances fail
    ydl_opts = {
        "format": "18/bestaudio/best",
        "quiet": True,
        "no_warnings": True,
        "skip_download": True,
        "extractor_args": {
            "youtube": {
                "player_client": ["android", "ios"],
            }
        },
    }

    with yt_dlp.YoutubeDL(ydl_opts) as ydl:
        info = ydl.extract_info(
            f"https://www.youtube.com/watch?v={video_id}", download=False
        )
        url = info.get("url")

        if not url:
            raise Exception("Failed to extract direct stream URL")

        _url_cache[video_id] = (url, now + CACHE_TTL_SECONDS)
        return url


EXCLUDE_KEYWORDS = {
    "news", "tv", "live news", "headline", "podcast", "trailer", 
    "review", "reaction", "episode", "interview", "gameplay", "vlog", 
    "unboxing", "breaking", "press conference"
}

def _is_same_song(cand_title: str, curr_title: str) -> bool:
    """Check if two song titles represent the exact same track."""
    if not cand_title or not curr_title:
        return False
    t1 = re.sub(r"[^a-zA-Z0-9\s]", "", cand_title.lower())
    t2 = re.sub(r"[^a-zA-Z0-9\s]", "", curr_title.lower())
    stopwords = {"official", "video", "audio", "lyric", "lyrics", "song", "full", "hd", "4k", "from", "the", "movie", "album"}
    tokens1 = {w for w in t1.split() if w not in stopwords}
    tokens2 = {w for w in t2.split() if w not in stopwords}
    if not tokens1 or not tokens2:
        return False
    # If the smaller set of tokens is a subset of the larger, or high Jaccard overlap
    intersection = tokens1.intersection(tokens2)
    smaller_len = min(len(tokens1), len(tokens2))
    return len(intersection) >= max(1, int(smaller_len * 0.75))


def _calculate_search_relevance(entry: dict, clean_query: str, native_rank: int) -> float:
    """Calculates true search relevance preserving YouTube's native ranking algorithm.
    - Exact and prefix title matches get top priority.
    - Official channels and Music labels get tie-breaker bonuses.
    - Demotes random fan edits (8D, slowed, reverb, karaoke, ringtone) below the official hit song.
    """
    title = (entry.get("title") or "").lower()
    author = (entry.get("uploader") or entry.get("channel") or "").lower()
    query_lower = clean_query.lower()
    query_tokens = [t for t in re.findall(r"\w+", query_lower) if t not in {"song", "audio", "video", "full", "music"}]

    for kw in EXCLUDE_KEYWORDS:
        if kw in title or kw in author:
            return -1.0

    # Base score decays smoothly with YouTube's native ranking (preserving Google's relevance engine)
    score = max(0.0, 100.0 - (native_rank * 2.5))

    # Exact query phrase bonus
    if query_lower in title:
        score += 80.0
    elif query_tokens:
        matched_tokens = sum(1 for t in query_tokens if t in title)
        ratio = matched_tokens / len(query_tokens)
        score += ratio * 60.0

    # Official artists / YouTube Music / VEVO channel bonuses
    if author.endswith("- topic"):
        score += 18.0
    elif "vevo" in author or "records" in author or "music" in author or "official" in author:
        score += 15.0

    # Clean official release bonus
    if "official video" in title or "official music video" in title or "official audio" in title:
        score += 12.0

    # Penalize low-effort fan edits, karaoke, ringtones and covers so the authentic song always leads
    if any(m in title for m in ["8d audio", "slowed", "reverb", "bass boosted", "nightcore", "remake"]):
        score -= 30.0
    if any(m in title for m in ["cover", "karaoke", "ringtone", "instrumental status", "status video"]):
        score -= 40.0

    return score


@app.get("/search")
def search_videos(q: str, page: int = 1, limit: int = 20):
    if not q or not q.strip():
        return []

    clean_query = q.strip()
    query_key = f"{clean_query.lower()}_p{page}_l{limit}"
    now = time.time()

    if query_key in _search_cache:
        results, expires_at = _search_cache[query_key]
        if now < expires_at:
            return results

    ydl_opts = {
        "quiet": True,
        "no_warnings": True,
        "extract_flat": True,
        "skip_download": True,
        "http_headers": {
            "User-Agent": (
                "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
                "AppleWebKit/537.36 (KHTML, like Gecko) "
                "Chrome/125.0.0.0 Safari/537.36"
            ),
        },
    }

    try:
        raw_entries = []
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            # First pass: search clean query directly to match official hits
            info = ydl.extract_info(f"ytsearch50:{clean_query}", download=False)
            raw_entries = info.get("entries", [])
            if not raw_entries:
                info = ydl.extract_info(f"ytsearch50:{clean_query} song", download=False)
                raw_entries = info.get("entries", [])

        scored_results = []
        for native_rank, entry in enumerate(raw_entries):
            if entry and entry.get("id"):
                duration = entry.get("duration") or 0
                title_lower = (entry.get("title") or "").lower()
                if duration > MAX_DURATION_SECONDS and not any(kw in title_lower for kw in ALLOWED_LONG_TITLES):
                    continue
                score = _calculate_search_relevance(entry, clean_query, native_rank)
                if score > 0:
                    scored_results.append((
                        score,
                        {
                            "id": entry.get("id"),
                            "title": entry.get("title", "Unknown Title"),
                            "author": entry.get("uploader") or entry.get("channel") or "Unknown Artist",
                            "duration": duration,
                        }
                    ))

        # Sort by intelligent composite score descending
        scored_results.sort(key=lambda x: x[0], reverse=True)
        all_results = [item[1] for item in scored_results]

        start_idx = (page - 1) * limit
        end_idx = start_idx + limit
        paginated_results = all_results[start_idx:end_idx]

        _search_cache[query_key] = (paginated_results, now + 1800)  # 30-min cache
        return paginated_results
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))


@app.get("/suggestions")
def get_suggestions(q: str, limit: int = 8):
    """Live search suggestions (up to `limit` results).
    Uses YouTube autocomplete API for instant (<50ms) query recommendations.
    """
    if not q or not q.strip():
        return []
    clean_query = q.strip()
    try:
        url = f"http://suggestqueries.google.com/complete/search?client=firefox&ds=yt&q={urllib.parse.quote(clean_query)}"
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req, timeout=3) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            if len(data) > 1 and isinstance(data[1], list):
                return data[1][:limit]
    except Exception:
        pass
    return []


@app.get("/radio")
def get_radio(v: str, title: str = None, artist: str = None):
    if not v or not v.strip():
        return []

    video_id = v.strip()
    cache_key = f"radio_{video_id}"
    now = time.time()

    if cache_key in _search_cache:
        results, expires_at = _search_cache[cache_key]
        if now < expires_at:
            return results

    ydl_opts = {
        "quiet": True,
        "no_warnings": True,
        "extract_flat": True,
        "skip_download": True,
        "playlistend": 25,
        "http_headers": {
            "User-Agent": (
                "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
                "AppleWebKit/537.36 (KHTML, like Gecko) "
                "Chrome/125.0.0.0 Safari/537.36"
            ),
        },
    }

    try:
        clean_artist = (artist or "").split(",")[0].strip()
        search_query = f"ytsearch30:{clean_artist} top hit songs" if clean_artist else f"ytsearch30:{title or 'popular'} hit songs"

        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(search_query, download=False)
            entries = info.get("entries", [])

            results = []
            for entry in entries:
                if not entry or not entry.get("id"):
                    continue
                cand_id = entry.get("id")
                cand_title = entry.get("title", "")
                if cand_id == video_id:
                    continue
                # Skip duplicate uploads/versions of the same current track
                if title and _is_same_song(cand_title, title):
                    continue

                duration = entry.get("duration") or 0
                if duration > MAX_DURATION_SECONDS:
                    continue

                results.append({
                    "id": cand_id,
                    "title": cand_title,
                    "author": entry.get("uploader") or entry.get("channel") or "Unknown Artist",
                    "duration": duration,
                })
                if len(results) >= 20:
                    break

            _search_cache[cache_key] = (results, now + 3600)
            return results
    except Exception as e:
        return []


@app.post("/track_finished")
async def track_finished(request: Request):
    """Record co-occurrence when a user finishes playing current_id and transitions to next_id."""
    current_id = None
    next_id = None
    try:
        body = await request.json()
        current_id = body.get("current_id")
        next_id = body.get("next_id")
    except Exception:
        pass

    if not current_id or not next_id:
        current_id = request.query_params.get("current_id")
        next_id = request.query_params.get("next_id")

    if current_id and next_id:
        _record_co_occurrence(current_id, next_id)

    return {"status": "ok"}


@app.get("/next_candidates")
def get_next_candidates(v: str, limit: int = 20, title: str = None, artist: str = None):
    """Return next 20 songs using:
    1. Collaborative co-occurrence (what other users played next after v)
    2. Artist and style recommendations (excluding duplicate titles of currently playing song)
    3. Fallback search
    """
    if not v or not v.strip():
        return []

    target_id = v.strip()
    candidates = []
    seen_ids = {target_id}

    # 1. Co-occurrence next songs
    top_cooccurring = _get_top_cooccurring(target_id, limit)
    for next_id in top_cooccurring:
        if next_id not in seen_ids:
            seen_ids.add(next_id)
            candidates.append({
                "id": next_id,
                "title": "Recommended Track",
                "author": "Suggested for you",
                "duration": 210,
            })
            if len(candidates) >= limit:
                return candidates

    # 2. Artist top tracks & radio songs (excluding current title copies)
    radio_songs = get_radio(target_id, title=title, artist=artist)
    for song in radio_songs:
        sid = song.get("id")
        if sid and sid not in seen_ids:
            seen_ids.add(sid)
            candidates.append(song)
            if len(candidates) >= limit:
                return candidates

    # 3. Fallback search if still fewer than limit
    if len(candidates) < limit:
        clean_fallback = (artist or title or "trending songs").strip()
        fallback_search = search_videos(f"{clean_fallback} music hits", page=1, limit=limit)
        for song in fallback_search:
            sid = song.get("id")
            if sid and sid not in seen_ids:
                if title and _is_same_song(song.get("title", ""), title):
                    continue
                seen_ids.add(sid)
                candidates.append(song)
                if len(candidates) >= limit:
                    break

    return candidates




def _get_stream_lock(video_id: str) -> asyncio.Lock:
    if video_id not in _stream_locks:
        _stream_locks[video_id] = asyncio.Lock()
    return _stream_locks[video_id]


def _sync_download_audio(video_id: str) -> Path:
    cache_file = CACHE_DIR / f"{video_id}.m4a"
    if cache_file.exists() and cache_file.stat().st_size > 100000:
        return cache_file

    temp_file = CACHE_DIR / f"{video_id}.download.m4a"
    
    # 1. Get the direct stream URL (uses Piped API first, fallback yt-dlp)
    stream_url = _get_youtube_url(video_id)
    
    # 2. Download directly via urllib (much faster, avoids AWS block)
    req = urllib.request.Request(stream_url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=15) as response, open(temp_file, 'wb') as out_file:
        shutil.copyfileobj(response, out_file)

    if temp_file.exists() and temp_file.stat().st_size > 100000:
        temp_file.replace(cache_file)
        return cache_file
        
    raise RuntimeError(f"Download produced invalid or missing file for {video_id}")


@app.api_route("/stream/{video_id}.m4a", methods=["GET", "HEAD"])
@app.api_route("/stream", methods=["GET", "HEAD"])
async def stream_audio(request: Request, video_id: str = None, v: str = None):
    target_id = video_id or v
    if not target_id:
        raise HTTPException(status_code=400, detail="Missing video ID")

    cache_file = CACHE_DIR / f"{target_id}.m4a"
    if not (cache_file.exists() and cache_file.stat().st_size > 100000):
        lock = _get_stream_lock(target_id)
        async with lock:
            if not (cache_file.exists() and cache_file.stat().st_size > 100000):
                try:
                    await asyncio.to_thread(_sync_download_audio, target_id)
                except Exception as e:
                    raise HTTPException(status_code=500, detail=f"Proxy download error: {e}")

    return FileResponse(
        path=str(cache_file),
        media_type="audio/mp4",
        filename=f"{target_id}.m4a",
    )


@app.api_route("/preload", methods=["GET", "POST"])
async def preload_audio(v: str, background_tasks: BackgroundTasks):
    if not v or not v.strip():
        return {"status": "error", "message": "Missing video id"}
    target_id = v.strip()
    cache_file = CACHE_DIR / f"{target_id}.m4a"
    if cache_file.exists() and cache_file.stat().st_size > 100000:
        return {"status": "cached", "id": target_id}

    async def _bg_download(vid: str):
        lock = _get_stream_lock(vid)
        async with lock:
            target = CACHE_DIR / f"{vid}.m4a"
            if not (target.exists() and target.stat().st_size > 100000):
                try:
                    await asyncio.to_thread(_sync_download_audio, vid)
                except Exception:
                    pass

    background_tasks.add_task(_bg_download, target_id)
    return {"status": "preloading", "id": target_id}


@app.get("/stream_url")
def get_stream_url(v: str):
    try:
        url = _get_youtube_url(v)
        return {"url": url}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))


@app.delete("/cache/{video_id}")
def invalidate_cache(video_id: str):
    if video_id in _url_cache:
        del _url_cache[video_id]
    return {"status": "ok"}


# --- Spotify Import Endpoints ---

class SpotifyCodeRequest(BaseModel):
    code: str

class SpotifyImportRequest(BaseModel):
    access_token: Optional[str] = None
    playlist_id: str
    is_public: bool = False

@app.get("/spotify/login")
def spotify_login():
    """Returns the Spotify OAuth login URL."""
    return {"url": spotlib.get_auth_url()}

@app.get("/spotify/callback")
def spotify_callback(code: str = None, error: str = None):
    """Exchanges an authorization code for an access token and redirects to app."""
    if error:
        return RedirectResponse(url=f"dilsemusic://spotify-auth?error={error}")
    if not code:
        return RedirectResponse(url="dilsemusic://spotify-auth?error=missing_code")
        
    try:
        token_info = spotlib.get_token_from_code(code)
        token = token_info.get("access_token")
        return RedirectResponse(url=f"dilsemusic://spotify-auth?token={token}")
    except Exception as e:
        return RedirectResponse(url=f"dilsemusic://spotify-auth?error={e}")

@app.get("/spotify/playlists")
def get_spotify_playlists(access_token: str):
    """Fetches user playlists."""
    try:
        playlists = spotlib.get_user_playlists(access_token)
        return {"playlists": playlists}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@app.post("/spotify/import")
def import_spotify_playlist(request: SpotifyImportRequest):
    """Returns a list of search queries (Track + Artist) and playlist name for the Flutter app to resolve."""
    try:
        if request.is_public:
            info = spotlib.get_public_playlist_info(request.playlist_id)
            return {
                "name": info.get("name", "Spotify Playlist"),
                "tracks": info.get("tracks", []),
                "total": info.get("total", len(info.get("tracks", [])))
            }
        else:
            if not request.access_token:
                raise HTTPException(status_code=400, detail="Missing access token for private playlist.")
            tracks = spotlib.get_private_playlist_tracks(request.access_token, request.playlist_id)
            return {
                "name": "Spotify Playlist",
                "tracks": tracks,
                "total": len(tracks)
            }
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))


if __name__ == "__main__":
    import uvicorn

    port = int(os.environ.get("PORT", 8000))
    uvicorn.run(app, host="0.0.0.0", port=port)

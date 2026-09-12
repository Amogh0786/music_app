from fastapi import FastAPI, HTTPException, Request, Response, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse, FileResponse
import yt_dlp
import urllib.request
import time
import json
import os
import shutil
import asyncio
from collections import Counter
from pathlib import Path
from typing import Dict, List

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


# In-memory URL & Search caches
_url_cache: dict[str, tuple[str, float]] = {}
_search_cache: dict[str, tuple[list[dict], float]] = {}
CACHE_TTL_SECONDS = 4 * 60 * 60  # 4 hours


def _get_youtube_url(video_id: str) -> str:
    now = time.time()
    if video_id in _url_cache:
        url, expires_at = _url_cache[video_id]
        if now < expires_at:
            return url
        else:
            del _url_cache[video_id]

    ydl_opts = {
        "format": "140/bestaudio[ext=m4a]/bestaudio/18/best",
        "quiet": True,
        "no_warnings": True,
        "skip_download": True,
        "extractor_args": {
            "youtube": {
                "player_client": ["android", "ios"],
                "player_skip": ["webpage", "configs"],
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


def _get_entry_score(entry: dict) -> int:
    title = (entry.get("title") or "").lower()
    author = (entry.get("uploader") or entry.get("channel") or "").lower()

    for kw in EXCLUDE_KEYWORDS:
        if kw in title or kw in author:
            return 0

    if author.endswith("- topic") or "official audio" in title or "audio" in title:
        return 3

    if "official music video" in title or "official video" in title or "lyric video" in title or "full song" in title or "music" in author or "vevo" in author:
        return 2

    return 1


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
            # Query YouTube search with song/audio focus
            info = ydl.extract_info(f"ytsearch50:{clean_query} song", download=False)
            raw_entries = info.get("entries", [])
            if not raw_entries:
                info = ydl.extract_info(f"ytsearch50:{clean_query} audio", download=False)
                raw_entries = info.get("entries", [])


        scored_results = []
        for entry in raw_entries:
            if entry and entry.get("id"):
                # Duration filter: skip overly long tracks unless title contains allowed keywords
                duration = entry.get("duration") or 0
                title_lower = (entry.get("title") or "").lower()
                if duration > MAX_DURATION_SECONDS and not any(kw in title_lower for kw in ALLOWED_LONG_TITLES):
                    continue
                score = _get_entry_score(entry)
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

        # Sort by score descending (Tier 1 official audio first)
        scored_results.sort(key=lambda x: x[0], reverse=True)
        all_results = [item[1] for item in scored_results]

        # Apply pagination slice
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
        "playlistend": 20,  # Fast 1.3s response instead of 25s infinite playlist crawl
        "http_headers": {
            "User-Agent": (
                "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
                "AppleWebKit/537.36 (KHTML, like Gecko) "
                "Chrome/125.0.0.0 Safari/537.36"
            ),
        },
    }

    try:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(f"https://music.youtube.com/watch?v={video_id}&list=RD{video_id}", download=False)
            entries = info.get("entries", [])
            if not entries:
                clean_term = f"{title or ''} {artist or ''}".strip()
                search_q = f"ytsearch20:{clean_term} song" if clean_term else f"ytsearch20:{video_id} song"
                info = ydl.extract_info(search_q, download=False)
                entries = info.get("entries", [])

            results = []
            for entry in entries:
                if entry and entry.get("id") and entry.get("id") != video_id:
                    score = _get_entry_score(entry)
                    if score > 0:
                        results.append({
                            "id": entry.get("id"),
                            "title": entry.get("title", "Unknown Title"),
                            "author": entry.get("uploader") or entry.get("channel") or "Unknown Artist",
                            "duration": entry.get("duration"),
                        })

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
    2. YouTube Music Radio (similar style/genre for v)
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

    # 2. YouTube Music Radio (same genre / style)
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
        clean_fallback = f"{title or ''} {artist or ''}".strip() or "trending songs"
        fallback_search = search_videos(f"{clean_fallback} music", page=1, limit=limit)
        for song in fallback_search:
            sid = song.get("id")
            if sid and sid not in seen_ids:
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
    node_path = shutil.which("node") or "/usr/bin/node" or "/opt/homebrew/bin/node"

    ydl_opts = {
        "format": "140/bestaudio[ext=m4a]/bestaudio/18/best",
        "outtmpl": str(temp_file),
        "quiet": True,
        "no_warnings": True,
        "overwrites": True,
        "extractor_args": {
            "youtube": {
                "player_client": ["android", "ios"],
                "player_skip": ["webpage", "configs"],
            }
        },
    }
    if os.path.exists(node_path):
        ydl_opts["js_runtimes"] = {"node": {"path": node_path}}

    with yt_dlp.YoutubeDL(ydl_opts) as ydl:
        ydl.download([f"https://www.youtube.com/watch?v={video_id}"])

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


if __name__ == "__main__":
    import uvicorn

    port = int(os.environ.get("PORT", 8000))
    uvicorn.run(app, host="0.0.0.0", port=port)

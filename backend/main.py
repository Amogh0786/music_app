from fastapi import FastAPI, HTTPException, Request, Response
from fastapi.responses import StreamingResponse
import yt_dlp
import urllib.request
import time
import json
import os
from collections import Counter
from pathlib import Path
from typing import Dict, List

# Co-occurrence storage: maps video_id -> Counter of next video_ids
co_occurrence: dict[str, Counter[str]] = {}
CO_OCCURRENCE_FILE = Path(__file__).with_name('co_occurrence.json')

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
STREAM_CHUNK_SIZE = 64 * 1024  # 64KB

def _record_co_occurrence(current_id: str, next_id: str):
    """Update co-occurrence counters and persist to disk."""
    if not current_id or not next_id:
        return
    counter = co_occurrence.setdefault(current_id, Counter())
    counter[next_id] += 1
    _save_co_occurrence()

def _get_top_cooccurring(v_id: str, limit: int) -> List[str]:
    """Return up to `limit` video IDs that most frequently follow `v_id`.
    If fewer than `limit` entries exist, returns whatever is available.
    """
    counter = co_occurrence.get(v_id, Counter())
    return [vid for vid, _ in counter.most_common(limit)]




app = FastAPI()

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
        "format": "140/bestaudio[ext=m4a]/bestaudio/best",
        "quiet": True,
        "no_warnings": True,
        "skip_download": True,
        "http_headers": {
            "User-Agent": (
                "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
                "AppleWebKit/537.36 (KHTML, like Gecko) "
                "Chrome/125.0.0.0 Safari/537.36"
            ),
            "Accept-Language": "en-US,en;q=0.9",
            "Accept": "*/*",
            "Referer": "https://www.youtube.com/",
            "Origin": "https://www.youtube.com",
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
def get_radio(v: str):
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
                info = ydl.extract_info(f"ytsearch30:{video_id} song", download=False)
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
def get_next_candidates(v: str, limit: int = 20):
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
    radio_songs = get_radio(target_id)
    for song in radio_songs:
        sid = song.get("id")
        if sid and sid not in seen_ids:
            seen_ids.add(sid)
            candidates.append(song)
            if len(candidates) >= limit:
                return candidates

    # 3. Fallback search if still fewer than limit
    if len(candidates) < limit:
        fallback_search = search_videos(f"{target_id} trending songs", page=1, limit=limit)
        for song in fallback_search:
            sid = song.get("id")
            if sid and sid not in seen_ids:
                seen_ids.add(sid)
                candidates.append(song)
                if len(candidates) >= limit:
                    break

    return candidates




@app.get("/stream/{video_id}.m4a")
@app.get("/stream")
def stream_audio(request: Request, video_id: str = None, v: str = None):
    target_id = video_id or v
    if not target_id:
        raise HTTPException(status_code=400, detail="Missing video ID")

    try:
        target_url = _get_youtube_url(target_id)
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

    headers = {
        "User-Agent": (
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
            "AppleWebKit/537.36 (KHTML, like Gecko) "
            "Chrome/125.0.0.0 Safari/537.36"
        ),
        "Accept": "*/*",
        "Referer": "https://www.youtube.com/",
        "Origin": "https://www.youtube.com",
    }

    range_header = request.headers.get("range")
    if range_header:
        headers["Range"] = range_header

    req = urllib.request.Request(target_url, headers=headers)

    try:
        yt_resp = urllib.request.urlopen(req)
    except Exception as e:
        if target_id in _url_cache:
            del _url_cache[target_id]
        try:
            target_url = _get_youtube_url(target_id)
            req = urllib.request.Request(target_url, headers=headers)
            yt_resp = urllib.request.urlopen(req)
        except Exception as retry_err:
            raise HTTPException(
                status_code=500, detail=f"Proxy error: {retry_err}"
            )

    def iterfile():
        attempts = 0
        nonlocal yt_resp
        while attempts < MAX_STREAM_RETRIES:
            try:
                while True:
                    chunk = yt_resp.read(STREAM_CHUNK_SIZE)
                    if not chunk:
                        return
                    yield chunk
                break
            except ConnectionResetError:
                attempts += 1
                if attempts >= MAX_STREAM_RETRIES:
                    raise HTTPException(status_code=502, detail="Upstream stream reset")
                # retry: close and reopen connection
                try:
                    yt_resp.close()
                except Exception:
                    pass
                target_url = _get_youtube_url(target_id)
                req = urllib.request.Request(target_url, headers=headers)
                yt_resp = urllib.request.urlopen(req)
            finally:
                # Ensure the response is closed when exiting loop
                if attempts >= MAX_STREAM_RETRIES:
                    try:
                        yt_resp.close()
                    except Exception:
                        pass

    response_headers = {
        "Content-Type": "audio/mp4",
        "Accept-Ranges": "bytes",
    }
    content_range = yt_resp.headers.get("Content-Range")
    if content_range:
        response_headers["Content-Range"] = content_range
    content_length = yt_resp.headers.get("Content-Length")
    if content_length:
        response_headers["Content-Length"] = content_length

    return StreamingResponse(
        iterfile(),
        status_code=yt_resp.status,
        headers=response_headers,
        media_type="audio/mp4",
    )


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

    uvicorn.run(app, host="0.0.0.0", port=8000)

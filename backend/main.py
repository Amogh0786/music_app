from fastapi import FastAPI, HTTPException, Request, Response
from fastapi.responses import StreamingResponse
import yt_dlp
import urllib.request
import time

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


@app.get("/search")
def search_videos(q: str):
    if not q or not q.strip():
        return []

    query_key = q.strip().lower()
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
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(f"ytsearch15:{q}", download=False)
            results = []
            for entry in info.get("entries", []):
                if entry and entry.get("id"):
                    results.append(
                        {
                            "id": entry.get("id"),
                            "title": entry.get("title", "Unknown Title"),
                            "author": entry.get("uploader")
                            or entry.get("channel")
                            or "Unknown Artist",
                            "duration": entry.get("duration"),
                        }
                    )

            _search_cache[query_key] = (results, now + 1800)  # 30-min cache
            return results
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))


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
        try:
            while True:
                chunk = yt_resp.read(64 * 1024)
                if not chunk:
                    break
                yield chunk
        finally:
            yt_resp.close()

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

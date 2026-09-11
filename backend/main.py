from fastapi import FastAPI, HTTPException, Request, Response
from fastapi.responses import StreamingResponse
import yt_dlp
import urllib.request
import time

app = FastAPI()

# In-memory URL cache: { video_id: (url, expires_at_timestamp) }
_url_cache: dict[str, tuple[str, float]] = {}
CACHE_TTL_SECONDS = 4 * 60 * 60  # 4 hours


def _get_youtube_url(video_id: str) -> str:
    now = time.time()
    if video_id in _url_cache:
        url, expires_at = _url_cache[video_id]
        if now < expires_at:
            return url
        else:
            del _url_cache[video_id]

    # Format 140 is YouTube's standard AAC/m4a audio stream (~128kbps)
    # It is a single progressive file (never DASH/HLS) compatible with ExoPlayer
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
        # Cache might be stale -> invalidate & retry once
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

    data = yt_resp.read()

    response_headers = {
        "Content-Type": "audio/mp4",
        "Content-Length": str(len(data)),
        "Accept-Ranges": "bytes",
    }
    content_range = yt_resp.headers.get("Content-Range")
    if content_range:
        response_headers["Content-Range"] = content_range

    return Response(
        content=data,
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

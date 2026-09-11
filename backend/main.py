from fastapi import FastAPI, HTTPException
import yt_dlp

app = FastAPI()

@app.get("/stream_url")
def get_stream_url(v: str):
    # We ask yt-dlp for the best audio, preferring m4a (which Android ExoPlayer loves)
    ydl_opts = {
        'format': 'bestaudio[ext=m4a]/bestaudio/best',
        'quiet': True,
        'no_warnings': True,
        'skip_download': True
    }
    
    try:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(f"https://www.youtube.com/watch?v={v}", download=False)
            return {"url": info['url']}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)

FROM python:3.11-slim

# Install ffmpeg (for audio containers), nodejs (for yt-dlp JS challenges), and curl
RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg \
    nodejs \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user with UID 1000 for Hugging Face Spaces compatibility
RUN useradd -m -u 1000 user
USER user
ENV HOME=/home/user \
    PATH=/home/user/.local/bin:$PATH

WORKDIR $HOME/app

# Copy and install python dependencies
COPY --chown=user requirements.txt .
RUN pip install --no-cache-dir --user -r requirements.txt

# Copy backend application files
COPY --chown=user . .

# Create cache directory with user write permissions
RUN mkdir -p audio_cache

# Hugging Face Spaces expects port 7860 by default; Render will pass PORT environment variable
ENV PORT=7860
EXPOSE 7860

CMD exec uvicorn main:app --host 0.0.0.0 --port ${PORT}

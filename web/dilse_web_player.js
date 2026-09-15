/**
 * DilSe Web Audio Player Engine (Invisible YouTube IFrame Player)
 * Provides 100% reliable, zero-latency streaming on iOS Safari, PWA, and desktop browsers.
 * Integrates directly with Web MediaSession API and iOS Background Audio keeper.
 */

(function () {
  let player = null;
  let isReady = false;
  let pendingVideoId = null;
  let pendingStartSec = 0;
  let ticker = null;
  let currentVideoId = null;

  // Native HTML5 silent audio keeper to unlock iOS Safari background audio session
  let bgAudio = null;
  function ensureBgAudio() {
    if (!bgAudio) {
      bgAudio = document.createElement('audio');
      bgAudio.setAttribute('playsinline', 'true');
      bgAudio.setAttribute('webkit-playsinline', 'true');
      bgAudio.loop = true;
      // 1-second silent stereo WAV base64
      bgAudio.src =
        'data:audio/wav;base64,UklGRiQAAABXQVZFZm10IBAAAAABAAEARKwAAIhYAQACABAAZGF0YQAAAAA=';
      document.body.appendChild(bgAudio);
    }
    return bgAudio;
  }

  function startBgAudio() {
    try {
      const audio = ensureBgAudio();
      audio.play().catch(() => {});
    } catch (_) {}
  }

  function stopBgAudio() {
    if (bgAudio) {
      try {
        bgAudio.pause();
      } catch (_) {}
    }
  }

  // Create an invisible off-screen container for YouTube IFrame
  function ensureContainer() {
    let el = document.getElementById('dilse-yt-host');
    if (!el) {
      el = document.createElement('div');
      el.id = 'dilse-yt-host';
      el.style.cssText =
        'position:fixed;top:-9999px;left:-9999px;width:1px;height:1px;opacity:0.001;pointer-events:none;z-index:-9999;';
      document.body.appendChild(el);
    }
    return el;
  }

  // Called automatically when https://www.youtube.com/iframe_api finishes loading
  window.onYouTubeIframeAPIReady = function () {
    console.log('[DilSe Web Player] YouTube IFrame API Ready');
    ensureContainer();
    ensureBgAudio();
    try {
      player = new YT.Player('dilse-yt-host', {
        height: '1',
        width: '1',
        playerVars: {
          autoplay: 1,
          controls: 0,
          disablekb: 1,
          fs: 0,
          playsinline: 1,
          rel: 0,
          enablejsapi: 1,
          origin: window.location.origin,
        },
        events: {
          onReady: onPlayerReady,
          onStateChange: onPlayerStateChange,
          onError: onPlayerError,
        },
      });
    } catch (e) {
      console.error('[DilSe Web Player] Initialization error:', e);
    }
  };

  function onPlayerReady(event) {
    console.log('[DilSe Web Player] Player Instance Ready');
    isReady = true;
    if (pendingVideoId) {
      const vid = pendingVideoId;
      const start = pendingStartSec;
      pendingVideoId = null;
      pendingStartSec = 0;
      window.dilsePlay(vid, start);
    }
  }

  function startTicker() {
    stopTicker();
    ticker = setInterval(() => {
      if (player && typeof player.getCurrentTime === 'function') {
        const pos = player.getCurrentTime() || 0;
        const dur = player.getDuration() || 0;
        window.dispatchEvent(
          new CustomEvent('dilse_time_update', {
            detail: { position: pos, duration: dur },
          })
        );
        if (
          'mediaSession' in navigator &&
          dur > 0 &&
          typeof navigator.mediaSession.setPositionState === 'function'
        ) {
          try {
            navigator.mediaSession.setPositionState({
              duration: dur,
              playbackRate: 1,
              position: Math.min(pos, dur),
            });
          } catch (_) {}
        }
      }
    }, 250);
  }

  function stopTicker() {
    if (ticker) {
      clearInterval(ticker);
      ticker = null;
    }
  }

  function onPlayerStateChange(event) {
    // YT.PlayerState: ENDED = 0, PLAYING = 1, PAUSED = 2, BUFFERING = 3, CUED = 5
    let stateName = 'unknown';
    switch (event.data) {
      case 1:
        stateName = 'playing';
        startTicker();
        startBgAudio();
        if ('mediaSession' in navigator) navigator.mediaSession.playbackState = 'playing';
        break;
      case 2:
        stateName = 'paused';
        stopTicker();
        stopBgAudio();
        if ('mediaSession' in navigator) navigator.mediaSession.playbackState = 'paused';
        break;
      case 3:
        stateName = 'buffering';
        break;
      case 0:
        stateName = 'ended';
        stopTicker();
        stopBgAudio();
        window.dispatchEvent(new CustomEvent('dilse_ended'));
        break;
      default:
        stateName = 'idle';
        break;
    }

    window.dispatchEvent(
      new CustomEvent('dilse_state_change', {
        detail: { state: stateName, code: event.data },
      })
    );
  }

  function onPlayerError(event) {
    console.warn('[DilSe Web Player] Player Error code:', event.data);
    window.dispatchEvent(
      new CustomEvent('dilse_error', {
        detail: { code: event.data },
      })
    );
  }

  // Prevent iOS Safari from suspending playback when user locks screen or switches tab
  document.addEventListener('visibilitychange', function () {
    if (document.visibilityState === 'hidden') {
      if (player && typeof player.getPlayerState === 'function') {
        const state = player.getPlayerState();
        // If state was PLAYING (1) or BUFFERING (3)
        if (state === 1 || state === 3) {
          startBgAudio();
          setTimeout(() => {
            if (player && typeof player.playVideo === 'function') {
              player.playVideo();
            }
          }, 120);
        }
      }
    }
  });

  // --- Exposed Global APIs for Dart ---

  window.dilsePlay = function (videoId, startSeconds) {
    currentVideoId = videoId;
    startBgAudio();

    if (!isReady || !player || typeof player.loadVideoById !== 'function') {
      console.log('[DilSe Web Player] Player not ready yet. Queuing:', videoId);
      pendingVideoId = videoId;
      pendingStartSec = startSeconds || 0;
      return;
    }

    try {
      player.loadVideoById({
        videoId: videoId,
        startSeconds: startSeconds || 0,
      });
      player.playVideo();
    } catch (err) {
      console.error('[DilSe Web Player] play error:', err);
    }
  };

  window.dilsePause = function () {
    stopBgAudio();
    if (player && typeof player.pauseVideo === 'function') {
      try {
        player.pauseVideo();
      } catch (_) {}
    }
  };

  window.dilseResume = function () {
    startBgAudio();
    if (player && typeof player.playVideo === 'function') {
      try {
        player.playVideo();
      } catch (_) {}
    }
  };

  window.dilseSeek = function (seconds) {
    if (player && typeof player.seekTo === 'function') {
      try {
        player.seekTo(seconds, true);
      } catch (_) {}
    }
  };

  window.dilseSetVolume = function (volumePercent) {
    if (player && typeof player.setVolume === 'function') {
      try {
        player.setVolume(volumePercent);
      } catch (_) {}
    }
  };

  window.dilseSetMetadata = function (title, artist, artworkUrl) {
    if (!('mediaSession' in navigator)) return;

    try {
      navigator.mediaSession.metadata = new MediaMetadata({
        title: title || 'DilSe Song',
        artist: artist || 'DilSe Music',
        album: 'DilSe',
        artwork: artworkUrl
          ? [
              { src: artworkUrl, sizes: '96x96', type: 'image/jpeg' },
              { src: artworkUrl, sizes: '192x192', type: 'image/jpeg' },
              { src: artworkUrl, sizes: '512x512', type: 'image/jpeg' },
            ]
          : [],
      });

      navigator.mediaSession.setActionHandler('play', () => {
        window.dilseResume();
        window.dispatchEvent(new CustomEvent('dilse_remote_play'));
      });
      navigator.mediaSession.setActionHandler('pause', () => {
        window.dilsePause();
        window.dispatchEvent(new CustomEvent('dilse_remote_pause'));
      });
      navigator.mediaSession.setActionHandler('nexttrack', () => {
        window.dispatchEvent(new CustomEvent('dilse_remote_next'));
      });
      navigator.mediaSession.setActionHandler('previoustrack', () => {
        window.dispatchEvent(new CustomEvent('dilse_remote_prev'));
      });
      navigator.mediaSession.setActionHandler('seekto', (details) => {
        if (details.seekTime !== undefined) {
          window.dilseSeek(details.seekTime);
        }
      });
    } catch (e) {
      console.warn('[DilSe Web Player] MediaSession error:', e);
    }
  };

  console.log('[DilSe Web Player] Helper script loaded');
})();

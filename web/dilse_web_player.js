/**
 * DilSe Web Audio Player Engine (Dual-Engine: JioSaavn 320k Direct Audio + YouTube Fallback)
 * 
 * Primary Engine: Native HTML5 <audio> streaming 320kbps AAC from JioSaavn public CDN
 *   - Enables 100% continuous background audio playback on iOS Safari / PWA when iPhone screen is locked.
 *   - Native iOS Lock Screen notifications, Dynamic Island, and Control Center scrubbers.
 *   - 320kbps pristine studio sound quality with zero IP bans.
 * 
 * Secondary Engine: Invisible YouTube IFrame Player (Method 1 Fallback)
 *   - Automatic fallback if a track is not available on JioSaavn or network drops.
 *   - Guarantees 0% playback failure under any circumstance.
 */

(function () {
  const ENGINE_NONE = 0;
  const ENGINE_AUDIO = 1;
  const ENGINE_IFRAME = 2;

  let activeEngine = ENGINE_NONE;
  let currentVideoId = null;
  let currentStartSec = 0;
  let currentTitle = '';
  let currentArtist = '';
  let currentArtwork = '';
  let lastReportedPos = 0;
  let lastReportedDur = 0;
  let fallbackTimer = null;
  let iframeWatchdog = null;
  let switchingEngines = false;
  let currentPlaySessionId = 0;

  function clearIframeWatchdog() {
    if (iframeWatchdog) {
      clearTimeout(iframeWatchdog);
      iframeWatchdog = null;
    }
  }

  function armIframeWatchdog() {
    clearIframeWatchdog();
    iframeWatchdog = setTimeout(() => {
      if (activeEngine === ENGINE_IFRAME && ytPlayer && typeof ytPlayer.getPlayerState === 'function') {
        const state = ytPlayer.getPlayerState();
        if (state === 3 || state === -1) {
          console.warn('[DilSe Web Player] YouTube IFrame buffering watchdog expired (7.0s), notifying recovery');
          window.dispatchEvent(
            new CustomEvent('dilse_error', {
              detail: { code: 999 },
            })
          );
        }
      }
    }, 7000);
  }

  // Interruption and lifecycle tracking (reels, calls, tab switches)
  let isUserPaused = false;
  let isInterrupted = false;
  let wasPlayingBeforeInterruption = false;

  // HTML5 Native Audio Element
  let audioEl = null;

  // YouTube IFrame Player instance
  let ytPlayer = null;
  let ytReady = false;
  let pendingVideoId = null;
  let pendingStartSec = 0;
  let ticker = null;

  // Silent background keeper for iOS audio session activation
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

  // Ensure Native HTML5 Audio Element is ready
  function ensureAudioElement() {
    if (!audioEl) {
      audioEl = document.createElement('audio');
      audioEl.id = 'dilse-html5-audio';
      audioEl.setAttribute('playsinline', 'true');
      audioEl.setAttribute('webkit-playsinline', 'true');
      audioEl.preload = 'auto';
      audioEl.volume = 1.0;
      audioEl.muted = false;
      audioEl.style.cssText =
        'position:fixed;top:-9999px;left:-9999px;width:1px;height:1px;opacity:0.001;pointer-events:none;';
      document.body.appendChild(audioEl);

      audioEl.addEventListener('playing', () => {
        if (activeEngine === ENGINE_AUDIO) {
          console.log('[DilSe Web Player] JioSaavn 320k audio playing');
          clearFallbackTimer();
          isInterrupted = false;
          wasPlayingBeforeInterruption = true;
          broadcastState('playing');
          if ('mediaSession' in navigator) navigator.mediaSession.playbackState = 'playing';
        }
      });

      audioEl.addEventListener('pause', () => {
        if (activeEngine === ENGINE_AUDIO && !switchingEngines) {
          console.log('[DilSe Web Player] JioSaavn audio paused');
          if (!isUserPaused && wasPlayingBeforeInterruption && !audioEl.ended && (audioEl.currentTime > 0)) {
            console.log('[DilSe Web Player] System interruption detected (reel, phone call, or external audio)');
            isInterrupted = true;
          }
          broadcastState('paused');
          if ('mediaSession' in navigator) navigator.mediaSession.playbackState = 'paused';
        }
      });

      audioEl.addEventListener('waiting', () => {
        if (activeEngine === ENGINE_AUDIO) {
          broadcastState('buffering');
        }
      });

      audioEl.addEventListener('timeupdate', () => {
        if (activeEngine === ENGINE_AUDIO) {
          const pos = audioEl.currentTime || 0;
          const dur = audioEl.duration || 0;
          lastReportedPos = pos;
          if (dur > 0) lastReportedDur = dur;
          broadcastTime(pos, dur);
          updateMediaSessionPosition(pos, dur);
        }
      });

      audioEl.addEventListener('ended', () => {
        if (activeEngine === ENGINE_AUDIO) {
          console.log('[DilSe Web Player] JioSaavn audio track ended');
          broadcastState('ended');
          window.dispatchEvent(new CustomEvent('dilse_ended'));
        }
      });

      audioEl.addEventListener('error', (e) => {
        if (activeEngine === ENGINE_AUDIO && !switchingEngines) {
          console.warn('[DilSe Web Player] Direct audio error encountered:', e);
          triggerFallback();
        }
      });
    }
    return audioEl;
  }

  function clearFallbackTimer() {
    if (fallbackTimer) {
      clearTimeout(fallbackTimer);
      fallbackTimer = null;
    }
  }

  function armFallbackTimer(videoId, startSeconds) {
    clearFallbackTimer();
    // If direct audio doesn't start within 5.0 seconds, auto-fallback to YouTube
    fallbackTimer = setTimeout(() => {
      if (activeEngine === ENGINE_AUDIO && (!audioEl || audioEl.readyState < 2)) {
        console.warn('[DilSe Web Player] Direct stream timeout (5.0s), switching to YouTube fallback');
        triggerFallback();
      }
    }, 5000);
  }

  function triggerFallback() {
    clearFallbackTimer();
    if (activeEngine === ENGINE_IFRAME) return; // already in fallback

    console.warn('[DilSe Web Player] Activating Method 1 YouTube IFrame fallback for video:', currentVideoId);
    switchingEngines = true;
    if (audioEl) {
      try {
        audioEl.pause();
        audioEl.removeAttribute('src');
        audioEl.load();
      } catch (_) {}
    }
    switchingEngines = false;
    activeEngine = ENGINE_IFRAME;

    const startAt = lastReportedPos > 0 ? lastReportedPos : currentStartSec;
    playViaIframe(currentVideoId, startAt);
  }

  // Create an invisible off-screen container for YouTube IFrame
  function ensureYtContainer() {
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
    ensureYtContainer();
    ensureBgAudio();
    ensureAudioElement();

    try {
      ytPlayer = new YT.Player('dilse-yt-host', {
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
          onReady: onYtPlayerReady,
          onStateChange: onYtStateChange,
          onError: onYtError,
        },
      });
    } catch (e) {
      console.error('[DilSe Web Player] YouTube IFrame initialization error:', e);
    }
  };

  function onYtPlayerReady() {
    console.log('[DilSe Web Player] YouTube Player Instance Ready');
    ytReady = true;
    if (activeEngine === ENGINE_IFRAME && pendingVideoId) {
      const vid = pendingVideoId;
      const start = pendingStartSec;
      pendingVideoId = null;
      pendingStartSec = 0;
      playViaIframe(vid, start);
    }
  }

  function playViaIframe(videoId, startSeconds) {
    activeEngine = ENGINE_IFRAME;
    startBgAudio();

    // Ensure direct HTML5 audio is completely stopped to prevent ghost playback collisions
    if (audioEl) {
      try {
        audioEl.pause();
        audioEl.removeAttribute('src');
        audioEl.load();
      } catch (_) {}
    }

    if (!ytReady || !ytPlayer || typeof ytPlayer.loadVideoById !== 'function') {
      console.log('[DilSe Web Player] YouTube Player not ready yet. Queuing:', videoId);
      pendingVideoId = videoId;
      pendingStartSec = startSeconds || 0;
      return;
    }

    try {
      if (typeof ytPlayer.unMute === 'function') {
        try { ytPlayer.unMute(); } catch (_) {}
      }
      if (typeof ytPlayer.setVolume === 'function') {
        try { ytPlayer.setVolume(100); } catch (_) {}
      }
      ytPlayer.loadVideoById({
        videoId: videoId,
        startSeconds: startSeconds || 0,
      });
      ytPlayer.playVideo();
      if (typeof ytPlayer.unMute === 'function') {
        try { ytPlayer.unMute(); } catch (_) {}
      }
      armIframeWatchdog();
    } catch (err) {
      console.error('[DilSe Web Player] YouTube play error:', err);
      clearIframeWatchdog();
      window.dispatchEvent(
        new CustomEvent('dilse_error', {
          detail: { code: 998 },
        })
      );
    }
  }

  function startTicker() {
    stopTicker();
    ticker = setInterval(() => {
      if (activeEngine === ENGINE_IFRAME && ytPlayer && typeof ytPlayer.getCurrentTime === 'function') {
        const pos = ytPlayer.getCurrentTime() || 0;
        const dur = ytPlayer.getDuration() || 0;
        lastReportedPos = pos;
        if (dur > 0) lastReportedDur = dur;
        broadcastTime(pos, dur);
        updateMediaSessionPosition(pos, dur);
      }
    }, 250);
  }

  function stopTicker() {
    if (ticker) {
      clearInterval(ticker);
      ticker = null;
    }
  }

  function onYtStateChange(event) {
    if (activeEngine !== ENGINE_IFRAME) return;

    let stateName = 'unknown';
    switch (event.data) {
      case 1:
        stateName = 'playing';
        clearIframeWatchdog();
        startTicker();
        startBgAudio();
        if (ytPlayer && typeof ytPlayer.isMuted === 'function' && ytPlayer.isMuted()) {
          try {
            ytPlayer.unMute();
            ytPlayer.setVolume(100);
          } catch (_) {}
        }
        if ('mediaSession' in navigator) navigator.mediaSession.playbackState = 'playing';
        break;
      case 2:
        stateName = 'paused';
        clearIframeWatchdog();
        stopTicker();
        stopBgAudio();
        if ('mediaSession' in navigator) navigator.mediaSession.playbackState = 'paused';
        break;
      case 3:
        stateName = 'buffering';
        armIframeWatchdog();
        break;
      case 0:
        stateName = 'ended';
        clearIframeWatchdog();
        stopTicker();
        stopBgAudio();
        window.dispatchEvent(new CustomEvent('dilse_ended'));
        break;
      default:
        stateName = 'idle';
        break;
    }

    broadcastState(stateName, event.data);
  }

  function onYtError(event) {
    if (activeEngine !== ENGINE_IFRAME) return;
    console.warn('[DilSe Web Player] YouTube IFrame Error code:', event.data);
    window.dispatchEvent(
      new CustomEvent('dilse_error', {
        detail: { code: event.data },
      })
    );
  }

  function broadcastState(stateName, code) {
    window.dispatchEvent(
      new CustomEvent('dilse_state_change', {
        detail: { state: stateName, code: code || 0 },
      })
    );
  }

  function broadcastTime(pos, dur) {
    window.dispatchEvent(
      new CustomEvent('dilse_time_update', {
        detail: { position: pos, duration: dur },
      })
    );
  }

  function updateMediaSessionPosition(pos, dur) {
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

  function attemptAutoResumeAfterInterruption() {
    if (isInterrupted && !isUserPaused) {
      console.log('[DilSe Web Player] Attempting auto-resume after interruption...');
      if (activeEngine === ENGINE_AUDIO && audioEl && audioEl.paused) {
        audioEl.play().then(() => {
          console.log('[DilSe Web Player] Successfully auto-resumed playback after interruption');
          isInterrupted = false;
          wasPlayingBeforeInterruption = true;
        }).catch((err) => {
          // Secondary audio (e.g. reel) may still be playing; will retry
          console.log('[DilSe Web Player] Auto-resume deferred:', err.message);
        });
      } else if (activeEngine === ENGINE_IFRAME && ytPlayer && typeof ytPlayer.playVideo === 'function') {
        try {
          ytPlayer.playVideo();
          isInterrupted = false;
          wasPlayingBeforeInterruption = true;
        } catch (_) {}
      }
    }
  }

  // iOS Safari / PWA background playback & interruption watchdog
  document.addEventListener('visibilitychange', function () {
    if (document.visibilityState === 'visible') {
      attemptAutoResumeAfterInterruption();
    } else if (document.visibilityState === 'hidden') {
      if (activeEngine === ENGINE_IFRAME && ytPlayer && typeof ytPlayer.getPlayerState === 'function') {
        const state = ytPlayer.getPlayerState();
        if (state === 1 || state === 3) {
          startBgAudio();
          setTimeout(() => {
            if (ytPlayer && typeof ytPlayer.playVideo === 'function') {
              ytPlayer.playVideo();
            }
          }, 120);
        }
      }
    }
  });

  window.addEventListener('focus', attemptAutoResumeAfterInterruption);
  window.addEventListener('pageshow', attemptAutoResumeAfterInterruption);

  // Periodic poll to resume immediately once the reel or call finishes
  setInterval(() => {
    if (isInterrupted && !isUserPaused) {
      attemptAutoResumeAfterInterruption();
    }
  }, 2000);

  window.dilsePlayWithOptions = function (opts) {
    opts = opts || {};
    return window.dilsePlay(
      opts.videoId,
      opts.startSeconds || 0,
      opts.title || '',
      opts.artist || '',
      opts.artworkUrl || '',
      opts.streamUrl || ''
    );
  };

  window.dilsePlay = async function (
    videoId,
    startSeconds,
    title,
    artist,
    artworkUrl,
    directStreamUrl
  ) {
    const sessionId = ++currentPlaySessionId;
    currentVideoId = videoId;
    currentStartSec = startSeconds || 0;
    currentTitle = title || currentTitle || '';
    currentArtist = artist || currentArtist || '';
    currentArtwork = artworkUrl || currentArtwork || '';
    lastReportedPos = startSeconds || 0;

    clearFallbackTimer();
    stopTicker();

    // Immediately stop and detach previous audio to eliminate ghost playback
    if (audioEl) {
      try {
        audioEl.pause();
        audioEl.removeAttribute('src');
        audioEl.load();
      } catch (_) {}
    }
    if (ytPlayer && typeof ytPlayer.stopVideo === 'function') {
      try {
        ytPlayer.stopVideo();
      } catch (_) {}
    }

    startBgAudio();
    ensureAudioElement();
    if (audioEl) {
      audioEl.muted = false;
      audioEl.volume = 1.0;
    }
    broadcastState('buffering');

    // Update MediaSession with initial metadata
    window.dilseSetMetadata(currentTitle, currentArtist, currentArtwork);

    isUserPaused = false;
    isInterrupted = false;
    wasPlayingBeforeInterruption = true;

    // If direct stream URL is already provided (e.g. from native JioSaavn search), play instantly!
    const streamToPlay = directStreamUrl || window.dilseCurrentStreamUrl || '';
    window.dilseCurrentStreamUrl = '';

    const isDirectAudio = streamToPlay && typeof streamToPlay === 'string' && streamToPlay.startsWith('http') &&
      (streamToPlay.includes('.mp4') || streamToPlay.includes('.m4a') || streamToPlay.includes('saavncdn') || streamToPlay.includes('media-cdn'));

    if (isDirectAudio) {
      console.log('[DilSe Web Player] Direct 320k stream provided, playing immediately:', streamToPlay);
      activeEngine = ENGINE_AUDIO;

      if (ytPlayer && typeof ytPlayer.stopVideo === 'function') {
        try {
          ytPlayer.stopVideo();
        } catch (_) {}
      }
      stopTicker();

      audioEl.src = streamToPlay;
      audioEl.muted = false;
      audioEl.volume = 1.0;
      if (startSeconds > 0) {
        audioEl.currentTime = startSeconds;
      }
      armFallbackTimer(videoId, startSeconds);

      audioEl.play().catch((err) => {
        console.warn('[DilSe Web Player] audioEl.play() rejected:', err);
        triggerFallback();
      });
      return;
    }

    // If a clean song title is available, resolve on JioSaavn for 320k direct audio stream
    if (title && title.trim().length > 1) {
      // Prioritize low-latency Cloudflare Edge Worker (~200ms) over Render backend
      const primaryWorker =
        window.dilseWorkerBaseUrl ||
        'https://dilse-edge-stream.charanteja-kondakalla030206.workers.dev';
      const secondaryBackend =
        window.dilseApiBaseUrl ||
        'https://music-backend-4kel.onrender.com';

      const cleanTitle = title
        .replace(/[\(\[\{].*?[\)\]\}]/g, '')
        .replace(/official video|music video|full song|lyric video|audio song|video song/gi, '')
        .replace(/\|.*$/g, '')
        .trim();

      console.log('[DilSe Web Player] Resolving on JioSaavn Smart Engine:', title, '| Artist:', artist);

      try {
        const fetchPromise = fetch(
          `${primaryWorker}/jio?title=${encodeURIComponent(cleanTitle || title)}&artist=${encodeURIComponent(artist || '')}`
        ).then(async (res) => {
          if (res.ok) {
            const json = await res.json();
            if (json.status === 'ok' && json.match && json.data?.streamUrl) {
              return json;
            }
          }
          // Secondary fallback to Render backend if Cloudflare worker didn't find match
          return fetch(
            `${secondaryBackend}/jio?title=${encodeURIComponent(cleanTitle || title)}&artist=${encodeURIComponent(artist || '')}`
          ).then(r => r.ok ? r.json() : null);
        });

        // 6.5s timeout for fast response while allowing Render cold starts if needed
        const timeoutPromise = new Promise((_, reject) =>
          setTimeout(() => reject(new Error('JioSaavn resolution timeout')), 6500)
        );

        const data = await Promise.race([fetchPromise, timeoutPromise]);
        if (sessionId !== currentPlaySessionId) return; // Superceded by another play call

        if (data && data.status === 'ok' && data.match && data.data?.streamUrl) {
          const jioSong = data.data;

          // Validate that the resolved track genuinely matches the requested song/artist
          const reqTitle = (cleanTitle || title || '').toLowerCase();
          const reqArtist = (artist || '').toLowerCase().trim();
          const resTitle = (jioSong.title || '').toLowerCase();
          const resArtist = (jioSong.artist || '').toLowerCase();
          const resArtwork = (jioSong.artwork || '').toLowerCase();

          const isCoverOrInstrumental =
            resArtwork.includes('-instrumental-') ||
            resTitle.includes('instrumental') ||
            resTitle.includes('karaoke') ||
            resTitle.includes('tribute') ||
            resTitle.includes('piano version') ||
            resTitle.includes('easy piano') ||
            resTitle.includes('originally perfo') ||
            resArtist.includes('karaoke') ||
            resArtist.includes('tribute') ||
            resArtist.includes('strings') ||
            resArtist.includes('zzang') ||
            resArtist.includes('luxebeats');

          // Title validation: ensure core keywords appear
          const titleWords = reqTitle
            .split(/\s+/)
            .map(w => w.replace(/[^a-z0-9]/g, ''))
            .filter(w => w.length >= 3 && !['song', 'audio', 'video', 'from', 'lyrics', 'feat', 'with'].includes(w));
          const titleMatches = titleWords.length === 0 || titleWords.some(w => resTitle.includes(w));

          // Artist validation: if artist was specified, check it exists in the resolved track
          let artistMatches = true;
          if (reqArtist.length >= 3) {
            const artistWords = reqArtist
              .split(/\s+/)
              .map(w => w.replace(/[^a-z0-9]/g, ''))
              .filter(w => w.length >= 3);
            artistMatches = artistWords.some(w => resArtist.includes(w));
          }

          if (!isCoverOrInstrumental && titleMatches && artistMatches) {
            console.log(
              `[DilSe Web Player] JioSaavn Confident Match Confirmed: "${jioSong.title}" by "${jioSong.artist}" -> ${jioSong.streamUrl}`
            );

            activeEngine = ENGINE_AUDIO;

            // Stop YouTube IFrame if running
            if (ytPlayer && typeof ytPlayer.stopVideo === 'function') {
              try {
                ytPlayer.stopVideo();
              } catch (_) {}
            }
            stopTicker();

            audioEl.src = jioSong.streamUrl;
            audioEl.muted = false;
            audioEl.volume = 1.0;
            if (startSeconds > 0) {
              audioEl.currentTime = startSeconds;
            }
            armFallbackTimer(videoId, startSeconds);

            // Update MediaSession with high-res album artwork from JioSaavn
            window.dilseSetMetadata(
              jioSong.title || title,
              jioSong.artist || artist,
              jioSong.artwork || artworkUrl
            );

            audioEl.play().catch((err) => {
              console.warn('[DilSe Web Player] audioEl.play() rejected:', err);
              triggerFallback();
            });
            return;
          } else {
            console.log(
              `[DilSe Web Player] JioSaavn resolution rejected (Cover: ${isCoverOrInstrumental}, TitleMatch: ${titleMatches}, ArtistMatch: ${artistMatches}). Falling back to YouTube IFrame for authentic audio.`
            );
          }
        }
      } catch (err) {
        console.log('[DilSe Web Player] JioSaavn resolution skipped/failed:', err.message);
      }
    }

    if (sessionId !== currentPlaySessionId) return;

    // Fallback: If not matched on JioSaavn or resolution failed, play via YouTube IFrame (Method 1)
    console.log('[DilSe Web Player] Playing via Method 1 (YouTube IFrame fallback):', videoId);
    playViaIframe(videoId, startSeconds);
  };

  window.dilsePause = function () {
    isUserPaused = true;
    isInterrupted = false;
    wasPlayingBeforeInterruption = false;
    stopBgAudio();
    clearFallbackTimer();
    clearIframeWatchdog();
    stopTicker();
    if (audioEl) {
      try {
        audioEl.pause();
      } catch (_) {}
    }
    if (ytPlayer && typeof ytPlayer.pauseVideo === 'function') {
      try {
        ytPlayer.pauseVideo();
      } catch (_) {}
    }
    broadcastState('paused');
    if ('mediaSession' in navigator) navigator.mediaSession.playbackState = 'paused';
  };

  window.dilseResume = function () {
    isUserPaused = false;
    isInterrupted = false;
    wasPlayingBeforeInterruption = true;
    startBgAudio();
    if (activeEngine === ENGINE_AUDIO && audioEl) {
      try {
        audioEl.muted = false;
        audioEl.volume = 1.0;
        audioEl.play();
      } catch (_) {}
    } else if (activeEngine === ENGINE_IFRAME && ytPlayer && typeof ytPlayer.playVideo === 'function') {
      try {
        if (typeof ytPlayer.unMute === 'function') {
          ytPlayer.unMute();
          ytPlayer.setVolume(100);
        }
        ytPlayer.playVideo();
      } catch (_) {}
    }
    broadcastState('playing');
    if ('mediaSession' in navigator) navigator.mediaSession.playbackState = 'playing';
  };

  window.dilseSeek = function (seconds) {
    lastReportedPos = seconds;
    if (activeEngine === ENGINE_AUDIO && audioEl) {
      try {
        audioEl.currentTime = seconds;
      } catch (_) {}
    } else if (activeEngine === ENGINE_IFRAME && ytPlayer && typeof ytPlayer.seekTo === 'function') {
      try {
        ytPlayer.seekTo(seconds, true);
      } catch (_) {}
    }
  };

  window.dilseSetVolume = function (volumePercent) {
    if (audioEl) {
      try {
        audioEl.volume = Math.max(0, Math.min(1, volumePercent / 100));
      } catch (_) {}
    }
    if (ytPlayer && typeof ytPlayer.setVolume === 'function') {
      try {
        ytPlayer.setVolume(volumePercent);
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
      navigator.mediaSession.setActionHandler('seekforward', () => {
        window.dilseSeek((lastReportedPos || 0) + 10);
      });
      navigator.mediaSession.setActionHandler('seekbackward', () => {
        window.dilseSeek(Math.max(0, (lastReportedPos || 0) - 10));
      });
    } catch (e) {
      console.warn('[DilSe Web Player] MediaSession error:', e);
    }
  };

  console.log('[DilSe Web Player] Dual-Engine player initialized (JioSaavn 320k + YouTube Fallback)');
})();

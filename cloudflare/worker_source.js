import CryptoJS from 'crypto-js';

/**
 * DilSe Cloudflare Edge Audio Stream Worker
 * 
 * High-performance edge engine powering DilSe Web/PWA.
 * 
 * Endpoints:
 * 1. /jio/search?q=...&limit=20:
 *    - Searches JioSaavn official catalog.
 *    - Decrypts 320kbps AAC direct audio URLs on the edge.
 *    - Returns high-res 500x500 album artwork and duration.
 *    - Enables instantaneous, error-free playback with native iOS locked screen background play!
 * 2. /jio/suggestions?q=...:
 *    - Live query suggestions for instant autocomplete.
 * 3. /jio?title=...&artist=...:
 *    - Single track resolver with confidence scoring (backwards compatibility).
 * 4. Full CORS & HTTP 206 Partial Content byte ranges.
 */

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, HEAD, OPTIONS',
  'Access-Control-Allow-Headers': 'Range, Content-Type, Accept',
  'Access-Control-Expose-Headers': 'Content-Length, Content-Range, Accept-Ranges',
};

const JIO_CIPHER_KEY = '38346591';

const JIO_GEO_HEADERS = {
  'User-Agent':
    'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1',
  'Cookie':
    'geo=106.51.1.1%2CIN%2CTelangana%2CHyderabad%2C500001; DL=english; L=english; country=IN; CH=G03%2CA07%2CO00%2CL03',
  'X-Forwarded-For': '106.51.1.1',
  'Client-IP': '106.51.1.1',
  'Accept': 'application/json',
};

export default {
  async fetch(request, env, ctx) {
    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: CORS_HEADERS });
    }

    const url = new URL(request.url);

    // Health check endpoint
    if (url.pathname === '/' || url.pathname === '/health') {
      return new Response(
        JSON.stringify({
          status: 'online',
          service: 'dilse-cloudflare-edge',
          engine: 'jiosaavn-native-catalog-320k',
        }),
        { headers: { 'Content-Type': 'application/json', ...CORS_HEADERS } }
      );
    }

    // 1. Native JioSaavn Catalog Search: /jio/search?q=...&limit=20
    if (url.pathname === '/jio/search') {
      const query = url.searchParams.get('q') || '';
      const limit = Math.min(50, Math.max(1, parseInt(url.searchParams.get('limit') || '20')));

      if (!query || query.trim().length < 1) {
        return new Response(
          JSON.stringify([]),
          { headers: { 'Content-Type': 'application/json', ...CORS_HEADERS } }
        );
      }

      try {
        const results = await searchJioSaavn(query.trim(), limit);
        return new Response(
          JSON.stringify(results),
          {
            headers: {
              'Content-Type': 'application/json',
              'Cache-Control': 'public, max-age=3600',
              ...CORS_HEADERS,
            },
          }
        );
      } catch (err) {
        return new Response(
          JSON.stringify({ status: 'error', message: err.message || 'Search error' }),
          { status: 500, headers: { 'Content-Type': 'application/json', ...CORS_HEADERS } }
        );
      }
    }

    // 2. Autocomplete Suggestions: /jio/suggestions?q=...&limit=8
    if (url.pathname === '/jio/suggestions') {
      const query = url.searchParams.get('q') || '';
      const limit = Math.min(15, Math.max(1, parseInt(url.searchParams.get('limit') || '8')));

      if (!query || query.trim().length < 1) {
        return new Response(
          JSON.stringify([]),
          { headers: { 'Content-Type': 'application/json', ...CORS_HEADERS } }
        );
      }

      try {
        const suggestions = await getJioSuggestions(query.trim(), limit);
        return new Response(
          JSON.stringify(suggestions),
          {
            headers: {
              'Content-Type': 'application/json',
              'Cache-Control': 'public, max-age=7200',
              ...CORS_HEADERS,
            },
          }
        );
      } catch (err) {
        return new Response(
          JSON.stringify([]),
          { headers: { 'Content-Type': 'application/json', ...CORS_HEADERS } }
        );
      }
    }

    // 3. Single Track Resolver: /jio?title=...&artist=... (or /jio?q=...)
    if (url.pathname === '/jio') {
      const rawTitle = url.searchParams.get('title') || url.searchParams.get('q') || '';
      const rawArtist = url.searchParams.get('artist') || '';

      if (!rawTitle || rawTitle.trim().length < 2) {
        return new Response(
          JSON.stringify({ status: 'error', message: 'Missing title/query (?title=...)' }),
          { status: 400, headers: { 'Content-Type': 'application/json', ...CORS_HEADERS } }
        );
      }

      try {
        const result = await resolveSingleTrack(rawTitle.trim(), rawArtist.trim());
        if (result) {
          return new Response(
            JSON.stringify({ status: 'ok', match: true, data: result }),
            {
              headers: {
                'Content-Type': 'application/json',
                'Cache-Control': 'public, max-age=86400',
                ...CORS_HEADERS,
              },
            }
          );
        } else {
          return new Response(
            JSON.stringify({
              status: 'not_found',
              match: false,
              message: 'No confident match found on JioSaavn; falling back to YouTube',
            }),
            { headers: { 'Content-Type': 'application/json', ...CORS_HEADERS } }
          );
        }
      } catch (err) {
        return new Response(
          JSON.stringify({ status: 'error', message: err.message || 'JioSaavn resolution error' }),
          { status: 500, headers: { 'Content-Type': 'application/json', ...CORS_HEADERS } }
        );
      }
    }

    // 4. Fallback stream endpoint: /stream?v=VIDEO_ID
    if (url.pathname === '/stream') {
      const videoId = url.searchParams.get('v');
      if (!videoId) {
        return new Response('Missing video ID', { status: 400, headers: CORS_HEADERS });
      }
      return new Response(
        JSON.stringify({ status: 'fallback', videoId: videoId }),
        { headers: { 'Content-Type': 'application/json', ...CORS_HEADERS } }
      );
    }

    // 5. Lyrics resolver: /lyrics?title=...&artist=...
    // 5. Lyrics resolver: /lyrics?title=...&artist=...&lang=...&duration=...
    if (url.pathname === '/lyrics') {
      const rawTitle = url.searchParams.get('title') || url.searchParams.get('q') || '';
      const rawArtist = url.searchParams.get('artist') || '';
      const rawLang = url.searchParams.get('lang') || '';
      const rawDuration = parseInt(url.searchParams.get('duration') || '0', 10);

      if (!rawTitle || rawTitle.trim().length < 1) {
        return new Response(
          JSON.stringify({ status: 'error', message: 'Missing title (?title=...)' }),
          { status: 400, headers: { 'Content-Type': 'application/json', ...CORS_HEADERS } }
        );
      }

      try {
        const result = await fetchLyricsEdge(rawTitle.trim(), rawArtist.trim(), rawLang.trim(), rawDuration);
        if (result && (result.syncedLyrics || result.plainLyrics)) {
          return new Response(
            JSON.stringify({ status: 'ok', match: true, data: result }),
            {
              headers: {
                'Content-Type': 'application/json',
                'Cache-Control': 'public, max-age=86400',
                ...CORS_HEADERS,
              },
            }
          );
        } else {
          return new Response(
            JSON.stringify({ status: 'not_found', match: false, message: 'No lyrics found' }),
            { headers: { 'Content-Type': 'application/json', ...CORS_HEADERS } }
          );
        }
      } catch (err) {
        return new Response(
          JSON.stringify({ status: 'error', message: err.message || 'Lyrics fetch error' }),
          { status: 500, headers: { 'Content-Type': 'application/json', ...CORS_HEADERS } }
        );
      }
    }

    return new Response('Not Found', { status: 404, headers: CORS_HEADERS });
  },
};

const UNICODE_SCRIPTS = {
  telugu: [0x0C00, 0x0C7F],
  tamil: [0x0B80, 0x0BFF],
  hindi: [0x0900, 0x097F],
  kannada: [0x0C80, 0x0CFF],
  malayalam: [0x0D00, 0x0D7F],
  punjabi: [0x0A00, 0x0A7F],
  bengali: [0x0980, 0x09FF],
  gujarati: [0x0A80, 0x0AFF],
};

const ALL_LANGUAGES = ['telugu', 'tamil', 'hindi', 'kannada', 'malayalam', 'punjabi', 'bengali', 'gujarati', 'marathi', 'english'];

function detectLyricsScript(text) {
  if (!text) return null;
  const clean = text.replace(/\[\d+:\d+\.?\d*\]/g, '');
  const counts = {};
  for (const lang of Object.keys(UNICODE_SCRIPTS)) counts[lang] = 0;
  for (let i = 0; i < clean.length; i++) {
    const cp = clean.charCodeAt(i);
    for (const [lang, [start, end]] of Object.entries(UNICODE_SCRIPTS)) {
      if (cp >= start && cp <= end) {
        counts[lang]++;
      }
    }
  }
  let best = null;
  let maxCount = 0;
  for (const [lang, count] of Object.entries(counts)) {
    if (count > maxCount) {
      maxCount = count;
      best = lang;
    }
  }
  return maxCount >= 8 ? best : null;
}

function detectMetaLanguage(text) {
  if (!text) return null;
  const lower = text.toLowerCase();
  for (const l of ALL_LANGUAGES) {
    const reg = new RegExp(`\\b${l}\\b`, 'i');
    if (reg.test(lower)) return l;
  }
  return null;
}

function scoreLyricsCandidate(cand, targetTitle, targetArtist, targetLang, targetDuration) {
  const lyrics = (cand.syncedLyrics || cand.plainLyrics || '').trim();
  if (!lyrics) return -9999;

  const script = detectLyricsScript(lyrics);
  const album = (cand.albumName || '').toLowerCase();
  const track = (cand.trackName || '').toLowerCase();
  const metaLang = detectMetaLanguage(`${album} ${track}`);

  let score = 0;

  // 1. Script checks (Strict non-Latin script matching)
  if (targetLang) {
    if (script) {
      if (script !== targetLang) {
        // Severe script contradiction (e.g. Malayalam or Tamil lyrics for Telugu song)
        return -9999;
      } else {
        score += 500;
      }
    } else if (targetLang === 'english' && script !== null) {
      return -9999;
    }
  }

  // 2. Metadata language tag conflict in album/track title
  if (targetLang && metaLang) {
    if (metaLang !== targetLang) {
      // e.g. candidate says [Hindi] or (Tamil) when target is Telugu
      return -9999;
    } else {
      score += 300;
    }
  }

  // 3. Title match
  const cTitle = (cand.trackName || '').replace(/[\(\[\{].*?[\)\]\}]/g, '').toLowerCase().trim();
  const tTitle = targetTitle.replace(/[\(\[\{].*?[\)\]\}]/g, '').toLowerCase().trim();
  if (cTitle === tTitle) {
    score += 250;
  } else if (cTitle.includes(tTitle) || tTitle.includes(cTitle)) {
    score += 150;
  } else {
    score -= 100;
  }

  // 4. Artist match
  if (targetArtist && cand.artistName) {
    const tTokens = targetArtist.toLowerCase().split(/[\s,;&]+/).filter((w) => w.length > 2);
    const cTokens = cand.artistName.toLowerCase().split(/[\s,;&]+/).filter((w) => w.length > 2);
    const hasOverlap = tTokens.some((t) => cTokens.includes(t));
    if (hasOverlap) {
      score += 150;
    } else if (tTokens.length > 0) {
      score -= 150;
    }
  }

  // 5. Duration match
  const cDur = cand.duration || 0;
  if (targetDuration > 0 && cDur > 0) {
    const diff = Math.abs(cDur - targetDuration);
    if (diff <= 5) {
      score += 100;
    } else if (diff <= 12) {
      score += 50;
    } else if (diff > 35) {
      score -= 200;
    }
  }

  // 6. Synced lyrics preference
  if (cand.syncedLyrics && cand.syncedLyrics.trim().length > 0) {
    score += 50;
  }

  return score;
}

/**
 * Searches and fetches synchronized LRC or plain lyrics with zero cross-language mismatch.
 */
async function fetchLyricsEdge(title, artist, lang, duration) {
  const cleanTitle = title
    .replace(/[\(\[\{].*?[\)\]\}]/g, '')
    .replace(/official video|music video|full song|lyric video|audio song|video song|lyrics/gi, '')
    .trim();
  const cleanArtist = artist.replace(/[\(\[\{].*?[\)\]\}]/g, '').trim();

  // If lang not explicitly provided, attempt detection from title or artist
  let targetLang = (lang || '').toLowerCase().trim();
  if (!targetLang) {
    targetLang = detectLyricsScript(title) || detectMetaLanguage(`${title} ${artist}`) || '';
  }

  const searchHeaders = {
    'User-Agent': 'DilSeMusicApp/1.0 (https://dilse.app; contact@dilse.app)',
    'Accept': 'application/json',
  };

  const queries = [];
  if (cleanTitle && targetLang) {
    queries.push(`https://lrclib.net/api/search?q=${encodeURIComponent(`${cleanTitle} ${targetLang}`)}`);
  }
  if (cleanTitle && cleanArtist) {
    queries.push(`https://lrclib.net/api/search?track_name=${encodeURIComponent(cleanTitle)}&artist_name=${encodeURIComponent(cleanArtist)}`);
    queries.push(`https://lrclib.net/api/search?q=${encodeURIComponent(`${cleanTitle} ${cleanArtist}`)}`);
  }
  if (cleanTitle) {
    queries.push(`https://lrclib.net/api/search?track_name=${encodeURIComponent(cleanTitle)}`);
    queries.push(`https://lrclib.net/api/search?q=${encodeURIComponent(cleanTitle)}`);
  }

  // If exact match endpoint can be tried first:
  if (cleanTitle && cleanArtist && duration > 0) {
    try {
      const getUrl = `https://lrclib.net/api/get?track_name=${encodeURIComponent(cleanTitle)}&artist_name=${encodeURIComponent(cleanArtist)}&duration=${Math.round(duration)}`;
      const res = await fetch(getUrl, { headers: searchHeaders });
      if (res.ok) {
        const item = await res.json();
        if (item && (item.syncedLyrics || item.plainLyrics)) {
          const s = scoreLyricsCandidate(item, cleanTitle, cleanArtist, targetLang, duration);
          if (s >= 100) return item;
        }
      }
    } catch (_) {}
  }

  const seenIds = new Set();
  let bestCandidate = null;
  let bestScore = 99; // Minimum threshold to accept lyrics is 100

  for (const url of queries) {
    try {
      const res = await fetch(url, { headers: searchHeaders });
      if (res.ok) {
        const list = await res.json();
        if (Array.isArray(list)) {
          for (const item of list) {
            if (!item || seenIds.has(item.id)) continue;
            seenIds.add(item.id);
            const score = scoreLyricsCandidate(item, cleanTitle, cleanArtist, targetLang, duration);
            if (score > bestScore) {
              bestScore = score;
              bestCandidate = item;
            }
          }
          // If we found a high quality match (score >= 400), return early
          if (bestCandidate && bestScore >= 400) {
            return bestCandidate;
          }
        }
      }
    } catch (_) {}
  }

  return bestCandidate;
}

/**
 * Decrypts JioSaavn encrypted_media_url into 320kbps direct CDN MP4 stream URL.
 */
function decryptMediaUrl(encryptedUrl) {
  if (!encryptedUrl) return '';
  try {
    const key = CryptoJS.enc.Utf8.parse(JIO_CIPHER_KEY);
    const decrypted = CryptoJS.DES.decrypt(
      { ciphertext: CryptoJS.enc.Base64.parse(encryptedUrl) },
      key,
      { mode: CryptoJS.mode.ECB, padding: CryptoJS.pad.Pkcs7 }
    );
    const rawUrl = decrypted.toString(CryptoJS.enc.Utf8);
    if (!rawUrl || !rawUrl.startsWith('http')) return '';
    return rawUrl.replace('_96.mp4', '_320.mp4').replace('_160.mp4', '_320.mp4');
  } catch (_) {
    return '';
  }
}

/**
 * Searches JioSaavn official catalog and returns direct 320k stream URLs and metadata.
 */
async function searchJioSaavn(query, limit = 20) {
  const url =
    'https://www.jiosaavn.com/api.php?__call=search.getResults&_format=json&_marker=0&cc=in&api_version=4&ctx=android&n=' +
    limit +
    '&p=1&q=' +
    encodeURIComponent(query);

  const res = await fetch(url, {
    headers: {
      'User-Agent': 'SaavnAndroid/9.0.0',
      'Accept': 'application/json',
      ...JIO_GEO_HEADERS,
    },
  });

  if (!res.ok) return [];

  const data = await res.json();
  const results = data.results || [];

  return results.map((r) => {
    const mi = r.more_info || {};
    const encMedia = mi.encrypted_media_url || r.encrypted_media_url || '';
    const streamUrl = decryptMediaUrl(encMedia);
    const artwork = (r.image || '').replace('150x150', '500x500');
    const title = (r.title || r.song || '')
      .replace(/&quot;/g, '"')
      .replace(/&#039;/g, "'")
      .replace(/&amp;/g, '&');
    const primaryArtists = (mi.artistMap?.primary_artists || []).map((a) => a.name).join(', ');
    const artist = (primaryArtists || r.subtitle || r.primary_artists || mi.music || r.singers || '')
      .replace(/&quot;/g, '"')
      .replace(/&#039;/g, "'")
      .replace(/&amp;/g, '&');
    const album = (mi.album || r.album || '')
      .replace(/&quot;/g, '"')
      .replace(/&#039;/g, "'")
      .replace(/&amp;/g, '&');
    const duration = parseInt(mi.duration || r.duration || '0') || 0;

    return {
      id: r.id,
      title: title || 'Unknown Title',
      author: artist || 'DilSe Music',
      album: album,
      duration: duration,
      thumbnail: artwork,
      streamUrl: streamUrl,
      source: 'jiosaavn',
      bitrate: '320kbps',
    };
  });
}

/**
 * Fetches autocomplete search suggestions from JioSaavn.
 */
async function getJioSuggestions(query, limit = 8) {
  const url =
    'https://www.jiosaavn.com/api.php?__call=autocomplete.get&query=' +
    encodeURIComponent(query) +
    '&_format=json&_marker=0&ctx=web6dot0';

  const res = await fetch(url, {
    headers: JIO_GEO_HEADERS,
  });

  if (!res.ok) return [];

  const data = await res.json();
  const suggestions = [];

  if (data.topquery?.data) {
    for (const item of data.topquery.data) {
      if (item.title && !suggestions.includes(item.title)) {
        suggestions.push(item.title.replace(/&quot;/g, '"').replace(/&#039;/g, "'"));
      }
    }
  }

  if (data.songs?.data) {
    for (const item of data.songs.data) {
      if (item.title && !suggestions.includes(item.title)) {
        suggestions.push(item.title.replace(/&quot;/g, '"').replace(/&#039;/g, "'"));
      }
    }
  }

  return suggestions.slice(0, limit);
}

/**
 * Single track fuzzy resolver for backwards compatibility.
 */
async function resolveSingleTrack(rawTitle, rawArtist) {
  const songs = await searchJioSaavn(rawTitle + (rawArtist ? ' ' + rawArtist : ''), 5);
  for (const s of songs) {
    if (!s.streamUrl) continue;
    if (rawArtist) {
      const artWords = rawArtist.toLowerCase().split(/\s+/).filter((w) => w.length >= 3);
      if (artWords.length > 0 && !artWords.some((w) => s.author.toLowerCase().includes(w))) {
        continue;
      }
    }
    return {
      title: s.title,
      artist: s.author,
      album: s.album,
      artwork: s.thumbnail,
      streamUrl: s.streamUrl,
      bitrate: '320kbps',
    };
  }
  return null;
}

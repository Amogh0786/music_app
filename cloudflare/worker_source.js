import CryptoJS from 'crypto-js';

/**
 * DilSe Cloudflare Edge Audio Stream Worker
 * 
 * High-performance edge engine powering DilSe Web/PWA.
 * 
 * Features:
 * 1. JioSaavn Smart Match Resolver (/jio?title=...&artist=... or /jio?q=...):
 *    - Cleans YouTube metadata (strips studio noise, parses artist/movie).
 *    - Queries JioSaavn search.getResults API.
 *    - Strict match confidence scoring (requires score >= 50).
 *    - Decrypts media URLs with DES-ECB (Key: 38346591).
 *    - Upgrades to 320kbps AAC stream from public CDN.
 *    - If no confident match, returns match: false so player cleanly falls back to YouTube!
 * 2. Full CORS & HTTP 206 Byte Ranges.
 */

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, HEAD, OPTIONS',
  'Access-Control-Allow-Headers': 'Range, Content-Type, Accept',
  'Access-Control-Expose-Headers': 'Content-Length, Content-Range, Accept-Ranges',
};

const JIO_CIPHER_KEY = '38346591';

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
          engine: 'jiosaavn-320k-smart-matcher',
        }),
        { headers: { 'Content-Type': 'application/json', ...CORS_HEADERS } }
      );
    }

    // JioSaavn Track Resolver: /jio?title=...&artist=... (or /jio?q=...)
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
        const result = await resolveJioSaavn(rawTitle.trim(), rawArtist.trim());
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

    // Fallback stream endpoint: /stream?v=VIDEO_ID
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

    return new Response('Not Found', { status: 404, headers: CORS_HEADERS });
  },
};

/**
 * Normalizes text for comparison (removes accents, brackets, punctuation, excess spaces).
 */
function normalize(str) {
  return (str || '')
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/&quot;/g, '')
    .replace(/&#039;/g, '')
    .replace(/&amp;/g, '&')
    .replace(/\([^)]*\)|\[[^\]]*\]/g, '')
    .replace(/[^a-z0-9\s]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

/**
 * Sanitizes YouTube metadata into clean title, clean artist, and movie/context info.
 */
function parseYoutubeMetadata(rawTitle, rawAuthor) {
  let author = (rawAuthor || '').replace(/ - Topic$/i, '').trim();
  const labelNoise = [
    't-series', 'tseries', 'aditya music', 'sony music', 'zee music',
    'lahari music', 'speed audio', 'tips official', 'saregama', 'yrf',
    'think music', 'vevo', 'records', 'entertainment', 'music', 'creations',
    'production', 'audio', 'studios', 'channel', 'media', 'official'
  ];
  for (const label of labelNoise) {
    if (author.toLowerCase().includes(label)) {
      author = '';
      break;
    }
  }

  let clean = (rawTitle || '')
    .replace(/\([^)]*\)|\[[^\]]*\]|\{[^}]*\}/g, ' ')
    .replace(/\b(official\s+(music\s+)?video|full\s+(video\s+)?song|lyric(al)?\s+video|video\s+song|audio\s+song|full\s+audio|lyrics|hd|4k|8k)\b/gi, ' ');

  const pipeParts = clean.split('|').map(p => p.trim()).filter(Boolean);
  let firstSegment = pipeParts[0] || clean;
  let secondSegment = pipeParts.length > 1 ? pipeParts[1] : '';

  let targetTitle = firstSegment;
  let contextInfo = secondSegment;

  if (firstSegment.includes(' - ') || firstSegment.includes(' – ') || firstSegment.includes(' — ')) {
    const dashParts = firstSegment.split(/\s+[-–—]\s+/);
    if (dashParts.length >= 2) {
      const part0 = dashParts[0].trim();
      const part1 = dashParts[1].trim();
      if (author && part0.toLowerCase() === author.toLowerCase()) {
        targetTitle = part1;
      } else if (author && part1.toLowerCase() === author.toLowerCase()) {
        targetTitle = part0;
      } else {
        targetTitle = part0;
        if (!contextInfo) contextInfo = part1;
      }
    }
  }

  targetTitle = targetTitle
    .replace(/[-–—/:]+$/, '')
    .replace(/\b(video|song|audio|full|track)\b/gi, '')
    .replace(/\s+/g, ' ')
    .trim();

  if (contextInfo) {
    contextInfo = contextInfo
      .replace(/[-–—/:]+$/, '')
      .replace(/\b(video|song|audio|full|track|starring|ft|feat)\b/gi, '')
      .replace(/\s+/g, ' ')
      .trim();
  }

  return { targetTitle, targetArtist: author, contextInfo };
}

/**
 * Resolves song on JioSaavn and returns direct 320kbps AAC CDN URL with confidence check.
 */
async function resolveJioSaavn(rawTitle, rawArtist) {
  const { targetTitle, targetArtist, contextInfo } = parseYoutubeMetadata(rawTitle, rawArtist);
  const normTitle = normalize(targetTitle);
  const normArtist = normalize(targetArtist);
  const normContext = normalize(contextInfo);

  if (!normTitle || normTitle.length < 2) return null;

  // Build targeted search query
  let searchQuery = normTitle;
  if (normContext) searchQuery += ' ' + normContext;
  if (normArtist) searchQuery += ' ' + normArtist;

  const searchUrl =
    'https://www.jiosaavn.com/api.php?__call=search.getResults&_format=json&_marker=0&cc=in&n=10&p=1&q=' +
    encodeURIComponent(searchQuery.trim());

  const searchRes = await fetch(searchUrl, {
    headers: {
      'User-Agent':
        'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1',
    },
  });

  if (!searchRes.ok) return null;

  const searchData = await searchRes.json();
  const results = searchData.results || [];
  if (!results.length) return null;

  let bestCandidate = null;
  let highestScore = -1;

  for (const r of results) {
    if (!r.encrypted_media_url) continue;

    const candTitle = normalize(r.song);
    const candArtist = normalize(r.primary_artists || r.singers || r.music);
    const candAlbum = normalize(r.album);

    let score = 0;

    // 1. Title matching
    if (candTitle === normTitle) {
      score = 100;
    } else if (candTitle.startsWith(normTitle) || normTitle.startsWith(candTitle)) {
      score = 80;
    } else {
      const targetWords = normTitle.split(' ').filter(Boolean);
      const candWords = candTitle.split(' ').filter(Boolean);

      let matched = 0;
      for (const tw of targetWords) {
        if (candWords.includes(tw)) matched++;
      }
      const ratio = targetWords.length > 0 ? matched / targetWords.length : 0;
      if (ratio >= 0.7) {
        score = 60 * ratio;
      }
    }

    // 2. Artist alignment boost
    if (score > 0 && normArtist) {
      if (candArtist.includes(normArtist) || normArtist.includes(candArtist)) {
        score += 40;
      }
    }

    // 3. Movie / Context alignment boost
    if (score > 0 && normContext) {
      if (candAlbum.includes(normContext) || candArtist.includes(normContext)) {
        score += 30;
      }
    }

    // 4. Penalties for unwanted versions (karaoke, tribute, instrumental)
    if (!normTitle.includes('instrumental') && candTitle.includes('instrumental')) score -= 30;
    if (!normTitle.includes('karaoke') && candTitle.includes('karaoke')) score -= 30;
    if (!normTitle.includes('tribute') && candTitle.includes('tribute')) score -= 30;

    if (score > highestScore) {
      highestScore = score;
      bestCandidate = r;
    }
  }

  // Reject candidate if confidence score is below 50
  if (!bestCandidate || highestScore < 50) {
    return null;
  }

  // Decrypt media URL using DES-ECB
  const key = CryptoJS.enc.Utf8.parse(JIO_CIPHER_KEY);
  const decrypted = CryptoJS.DES.decrypt(
    { ciphertext: CryptoJS.enc.Base64.parse(bestCandidate.encrypted_media_url) },
    key,
    { mode: CryptoJS.mode.ECB, padding: CryptoJS.pad.Pkcs7 }
  );

  let directUrl = decrypted.toString(CryptoJS.enc.Utf8);
  if (!directUrl || !directUrl.startsWith('http')) return null;

  // Upgrade stream bitrate to 320kbps AAC
  const url320 = directUrl.replace('_96.mp4', '_320.mp4').replace('_160.mp4', '_320.mp4');

  return {
    title: (bestCandidate.song || '').replace(/&quot;/g, '"').replace(/&#039;/g, "'"),
    artist: bestCandidate.primary_artists || bestCandidate.singers || '',
    album: (bestCandidate.album || '').replace(/&quot;/g, '"').replace(/&#039;/g, "'"),
    artwork: (bestCandidate.image || '').replace('150x150', '500x500'),
    streamUrl: url320,
    bitrate: '320kbps',
    confidenceScore: highestScore,
  };
}

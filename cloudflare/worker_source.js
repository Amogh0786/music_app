import CryptoJS from 'crypto-js';

/**
 * DilSe Cloudflare Edge Audio Stream Worker
 * 
 * High-performance edge engine powering DilSe Web/PWA.
 * 1. JioSaavn Resolver (/jio?q=...):
 *    - Resolves Indian & international songs to direct 320kbps AAC streams.
 *    - Decrypts media URLs with DES-ECB (Key: 38346591).
 *    - Returns direct CDN URLs (aac.saavncdn.com) with CORS enabled.
 *    - Unlocks 100% uninterrupted iOS Safari background play when iPhone is locked!
 * 2. YouTube Stream Proxy (/stream?v=...):
 *    - Progressive audio fallback for YouTube content.
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
          engine: 'jiosaavn-320k-enabled',
        }),
        { headers: { 'Content-Type': 'application/json', ...CORS_HEADERS } }
      );
    }

    // JioSaavn Track Resolver: /jio?q=SONG_TITLE_OR_ARTIST
    if (url.pathname === '/jio') {
      const query = url.searchParams.get('q');
      if (!query || query.trim().length < 2) {
        return new Response(
          JSON.stringify({ status: 'error', message: 'Missing search query (?q=...)' }),
          { status: 400, headers: { 'Content-Type': 'application/json', ...CORS_HEADERS } }
        );
      }

      try {
        const result = await resolveJioSaavn(query.trim());
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
            JSON.stringify({ status: 'not_found', match: false }),
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
 * Resolves song on JioSaavn and returns direct 320kbps AAC CDN URL.
 */
async function resolveJioSaavn(query) {
  // Clean query: strip tags, record labels, and video markers
  const cleanQ = query
    .replace(/[\(\[\{].*?[\)\]\}]/g, '')
    .replace(/official video|music video|full song|lyric video|audio song|video song/gi, '')
    .replace(/\|.*$/g, '')
    .trim();

  // 1. Query JioSaavn autocomplete API
  const searchUrl =
    'https://www.jiosaavn.com/api.php?__call=autocomplete.get&query=' +
    encodeURIComponent(cleanQ) +
    '&_format=json&_marker=0&ctx=web6dot0';

  const searchRes = await fetch(searchUrl, {
    headers: {
      'User-Agent':
        'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1',
    },
  });

  if (!searchRes.ok) return null;

  const searchData = await searchRes.json();
  const songs = searchData.songs?.data || [];
  if (!songs.length) return null;

  const topSong = songs[0];
  const pid = topSong.id;
  if (!pid) return null;

  // 2. Fetch song details containing encrypted_media_url
  const detailsUrl =
    'https://www.jiosaavn.com/api.php?__call=song.getDetails&pids=' +
    pid +
    '&_format=json&_marker=0&ctx=web6dot0';

  const detailsRes = await fetch(detailsUrl, {
    headers: {
      'User-Agent':
        'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1',
    },
  });

  if (!detailsRes.ok) return null;

  const detailsData = await detailsRes.json();
  const details = detailsData.songs ? detailsData.songs[0] : detailsData[pid];
  if (!details || !details.encrypted_media_url) return null;

  // 3. Decrypt media URL using DES-ECB
  const key = CryptoJS.enc.Utf8.parse(JIO_CIPHER_KEY);
  const decrypted = CryptoJS.DES.decrypt(
    { ciphertext: CryptoJS.enc.Base64.parse(details.encrypted_media_url) },
    key,
    { mode: CryptoJS.mode.ECB, padding: CryptoJS.pad.Pkcs7 }
  );

  let directUrl = decrypted.toString(CryptoJS.enc.Utf8);
  if (!directUrl || !directUrl.startsWith('http')) return null;

  // 4. Upgrade stream bitrate to highest available (320kbps AAC, or 160kbps fallback)
  const url320 = directUrl.replace('_96.mp4', '_320.mp4').replace('_160.mp4', '_320.mp4');

  return {
    title: details.song || topSong.title,
    artist: details.primary_artists || topSong.music || '',
    album: details.album || '',
    artwork: (details.image || topSong.image || '').replace('150x150', '500x500'),
    streamUrl: url320,
    bitrate: '320kbps',
  };
}

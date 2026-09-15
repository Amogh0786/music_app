/**
 * DilSe Cloudflare Edge Audio Stream Worker
 * 
 * Runs on Cloudflare's global edge network across 300+ cities.
 * Fetches progressive audio streams using YouTube Mobile InnerTube API
 * and proxies chunks with full HTTP 206 Byte Ranges and CORS headers.
 * 
 * Free tier: 100,000 requests/day.
 */

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, HEAD, OPTIONS',
  'Access-Control-Allow-Headers': 'Range, Content-Type, Accept',
  'Access-Control-Expose-Headers': 'Content-Length, Content-Range, Accept-Ranges',
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
        JSON.stringify({ status: 'online', service: 'dilse-cloudflare-edge' }),
        { headers: { 'Content-Type': 'application/json', ...CORS_HEADERS } }
      );
    }

    // Stream endpoint: /stream?v=VIDEO_ID
    if (url.pathname === '/stream') {
      const videoId = url.searchParams.get('v');
      if (!videoId || videoId.length < 5) {
        return new Response('Missing or invalid video ID (?v=...)', {
          status: 400,
          headers: CORS_HEADERS,
        });
      }

      try {
        return await handleAudioStream(request, videoId);
      } catch (err) {
        return new Response(
          JSON.stringify({ error: err.message || 'Stream resolution failed' }),
          { status: 500, headers: { 'Content-Type': 'application/json', ...CORS_HEADERS } }
        );
      }
    }

    return new Response('Not Found', { status: 404, headers: CORS_HEADERS });
  },
};

/**
 * Resolves direct audio stream URL and proxies bytes with HTTP 206 Partial Content.
 */
async function handleAudioStream(request, videoId) {
  // 1. Resolve direct audio stream using YouTube Mobile InnerTube API
  const directUrl = await resolveStreamUrl(videoId);
  if (!directUrl) {
    throw new Error('Unable to extract audio stream for this video.');
  }

  // 2. Prepare headers for upstream Google Video CDN
  const fetchHeaders = new Headers();
  fetchHeaders.set(
    'User-Agent',
    'com.google.android.apps.youtube.music/6.42.52 (Linux; U; Android 14; en_US) gzip'
  );
  fetchHeaders.set('Accept', '*/*');

  // Forward Range header from client (Crucial for iOS Safari Byte-Range support!)
  const clientRange = request.headers.get('Range');
  if (clientRange) {
    fetchHeaders.set('Range', clientRange);
  }

  // 3. Request audio chunk from Google Video CDN
  const upstreamResponse = await fetch(directUrl, {
    method: request.method,
    headers: fetchHeaders,
  });

  // 4. Construct downstream response with CORS and Byte Range headers
  const responseHeaders = new Headers(upstreamResponse.headers);
  for (const [key, value] of Object.entries(CORS_HEADERS)) {
    responseHeaders.set(key, value);
  }

  responseHeaders.set('Accept-Ranges', 'bytes');
  if (!responseHeaders.get('Content-Type') || responseHeaders.get('Content-Type').includes('text')) {
    responseHeaders.set('Content-Type', 'audio/mp4');
  }
  responseHeaders.set('Cache-Control', 'public, max-age=14400'); // Cache for 4 hours

  return new Response(upstreamResponse.body, {
    status: upstreamResponse.status,
    statusText: upstreamResponse.statusText,
    headers: responseHeaders,
  });
}

/**
 * Uses YouTube's Android Music InnerTube client to retrieve unthrottled audio streams.
 */
async function resolveStreamUrl(videoId) {
  const innertubePayload = {
    context: {
      client: {
        clientName: 'ANDROID_MUSIC',
        clientVersion: '6.42.52',
        androidSdkVersion: 34,
        hl: 'en',
        gl: 'US',
      },
    },
    videoId: videoId,
  };

  const response = await fetch('https://music.youtube.com/youtubei/v1/player', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'User-Agent':
        'com.google.android.apps.youtube.music/6.42.52 (Linux; U; Android 14; en_US) gzip',
    },
    body: JSON.stringify(innertubePayload),
  });

  if (!response.ok) {
    throw new Error(`InnerTube API failed with status ${response.status}`);
  }

  const data = await response.json();
  const formats = data.streamingData?.adaptiveFormats || data.streamingData?.formats || [];

  if (!formats.length) {
    throw new Error('No formats found in YouTube player response.');
  }

  // Find best audio stream (Priority: itag 140 128kbps AAC, or any audio/mp4, or highest audio bitrate)
  const audioFormats = formats.filter(
    (f) =>
      (f.mimeType && f.mimeType.startsWith('audio/')) ||
      f.itag === 140 ||
      f.itag === 18
  );

  if (!audioFormats.length) {
    throw new Error('No audio formats available.');
  }

  // Check for itag 140 (standard progressive AAC audio)
  const itag140 = audioFormats.find((f) => f.itag === 140 && f.url);
  if (itag140?.url) return itag140.url;

  // Otherwise pick highest bitrate audio with direct url
  audioFormats.sort((a, b) => (b.bitrate || 0) - (a.bitrate || 0));
  for (const f of audioFormats) {
    if (f.url) return f.url;
  }

  throw new Error('Direct stream URL requires signature decryption.');
}

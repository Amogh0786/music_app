/**
 * DilSe Cloudflare Edge Audio Stream Worker
 * 
 * Runs on Cloudflare's global edge network across 300+ cities.
 * Fetches progressive audio streams using YouTube iOS Mobile InnerTube API
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

const IOS_USER_AGENT =
  'com.google.ios.youtube/20.10.4 (iPhone16,2; U; CPU iOS 18_3_2 like Mac OS X;)';

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
  // 1. Resolve direct audio stream using YouTube iOS InnerTube API
  const directUrl = await resolveStreamUrl(videoId);
  if (!directUrl) {
    throw new Error('Unable to extract audio stream for this video.');
  }

  // 2. Prepare headers for upstream Google Video CDN
  const fetchHeaders = new Headers();
  fetchHeaders.set('User-Agent', IOS_USER_AGENT);
  fetchHeaders.set('Accept', '*/*');

  // Forward or default Range header (Google Video CDN requires Range for adaptive formats!)
  const clientRange = request.headers.get('Range') || 'bytes=0-';
  fetchHeaders.set('Range', clientRange);

  // 3. Request audio chunk from Google Video CDN
  const method = request.method === 'HEAD' ? 'HEAD' : 'GET';
  const upstreamResponse = await fetch(directUrl, {
    method: method,
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
 * Uses YouTube's iOS Mobile InnerTube client to retrieve unthrottled, direct audio streams.
 */
async function resolveStreamUrl(videoId) {
  const iosPayload = {
    context: {
      client: {
        clientName: 'IOS',
        clientVersion: '20.10.4',
        deviceMake: 'Apple',
        deviceModel: 'iPhone16,2',
        userAgent: IOS_USER_AGENT,
        hl: 'en',
        platform: 'MOBILE',
        osName: 'IOS',
        osVersion: '18.1.0.22B83',
        timeZone: 'UTC',
        gl: 'US',
        utcOffsetMinutes: 0,
      },
    },
    videoId: videoId,
  };

  const response = await fetch(
    'https://www.youtube.com/youtubei/v1/player?key=AIzaSyB-63vPrdThhKuerbB2N_l7Kwwcxj6yUAc&prettyPrint=false',
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'User-Agent': IOS_USER_AGENT,
      },
      body: JSON.stringify(iosPayload),
    }
  );

  if (!response.ok) {
    throw new Error(`InnerTube API failed with status ${response.status}`);
  }

  const data = await response.json();
  const formats = data.streamingData?.adaptiveFormats || data.streamingData?.formats || [];

  if (!formats.length) {
    throw new Error('No formats found in YouTube player response.');
  }

  // Priority 1: itag 140 (128kbps AAC audio/mp4)
  const itag140 = formats.find((f) => f.itag === 140 && f.url);
  if (itag140?.url) return itag140.url;

  // Priority 2: Any audio stream with direct url
  const audioFormats = formats.filter(
    (f) => (f.mimeType && f.mimeType.startsWith('audio/')) && f.url
  );
  if (audioFormats.length) {
    audioFormats.sort((a, b) => (b.bitrate || 0) - (a.bitrate || 0));
    return audioFormats[0].url;
  }

  // Priority 3: Any stream with direct url
  for (const f of formats) {
    if (f.url) return f.url;
  }

  throw new Error('No direct stream URL available in formats.');
}

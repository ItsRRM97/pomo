export default async function handler(req, res) {
  // Handle CORS preflight
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PATCH, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization, Notion-Version');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  try {
    // Extract endpoint path from query or default to root
    const { path, ...query } = req.query || {};
    const targetPath = Array.isArray(path) ? path.join('/') : path || '';

    // Construct search params if present
    const searchParams = new URLSearchParams(query).toString();
    const url = `https://api.notion.com/v1/${targetPath}${searchParams ? `?${searchParams}` : ''}`;

    const notionToken = process.env.NOTION_TOKEN || '';
    const accessToken = process.env.FOCUS_ACCESS_TOKEN || '';
    const rawAuth = req.headers.authorization || '';
    const bearer = rawAuth.replace(/^Bearer\s+/i, '').trim();

    let upstreamToken = '';
    if (!bearer) {
      // Web clients with no local key rely on the server secret.
      upstreamToken = notionToken;
    } else if (accessToken && bearer === accessToken) {
      // Shared focus-page access token for new browser sessions.
      upstreamToken = notionToken;
    } else if (bearer.startsWith('secret_') || bearer.startsWith('ntn_')) {
      // Allow a real Notion integration token from Settings.
      upstreamToken = bearer;
    } else {
      return res.status(401).json({
        error:
          'Invalid access token. Use the focus access token or a Notion integration token.',
      });
    }

    if (!upstreamToken) {
      return res.status(401).json({
        error: 'Missing Authorization header or NOTION_TOKEN env var',
      });
    }

    const headers = {
      Authorization: upstreamToken.startsWith('Bearer ')
        ? upstreamToken
        : `Bearer ${upstreamToken}`,
      'Notion-Version': req.headers['notion-version'] || '2022-06-28',
      'Content-Type': 'application/json',
    };

    const fetchOptions = {
      method: req.method,
      headers,
    };

    if (['POST', 'PATCH', 'PUT'].includes(req.method) && req.body) {
      fetchOptions.body =
        typeof req.body === 'string' ? req.body : JSON.stringify(req.body);
    }

    const response = await fetch(url, fetchOptions);
    const data = await response.json();

    return res.status(response.status).json(data);
  } catch (error) {
    console.error('Notion API Proxy Error:', error);
    return res.status(500).json({
      error: 'Internal Server Error proxying to Notion API',
      details: error.message,
    });
  }
}

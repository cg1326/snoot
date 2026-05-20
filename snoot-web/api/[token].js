const EDGE_FN = 'https://jmwlizpemivsadimplsa.supabase.co/functions/v1/sitter-view';

module.exports = async function handler(req, res) {
  const token = req.query.token;
  if (!token) {
    res.redirect('/');
    return;
  }

  let dogName = 'Your dog';
  let photoUrl = null;

  try {
    const response = await fetch(`${EDGE_FN}/${token}?json=true`);
    if (response.ok) {
      const data = await response.json();
      if (data?.dog?.name) dogName = data.dog.name;
      if (data?.dog?.photo_url) photoUrl = data.dog.photo_url;
    }
  } catch (_) {}

  const title = `${dogName}'s care guide`;
  const description = `Care instructions — feeding, walks, bedtime & more.`;
  const host = req.headers.host || 'snoot-web-zeta.vercel.app';
  const pageUrl = `https://${host}/${token}`;

  const ogImage = photoUrl
    ? `<meta property="og:image" content="${photoUrl}" />\n  <meta name="twitter:image" content="${photoUrl}" />\n  <meta name="twitter:card" content="summary_large_image" />`
    : `<meta name="twitter:card" content="summary" />`;

  const html = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>${title}</title>
  <meta property="og:type" content="website" />
  <meta property="og:url" content="${pageUrl}" />
  <meta property="og:title" content="${title}" />
  <meta property="og:description" content="${description}" />
  <meta name="twitter:title" content="${title}" />
  <meta name="twitter:description" content="${description}" />
  ${ogImage}
</head>
<body>
  <script>window.location.replace('/?token=${token}');</script>
  <noscript><meta http-equiv="refresh" content="0;url=/?token=${token}" /></noscript>
</body>
</html>`;

  res.setHeader('Content-Type', 'text/html; charset=utf-8');
  res.setHeader('Cache-Control', 'no-store');
  res.status(200).send(html);
};

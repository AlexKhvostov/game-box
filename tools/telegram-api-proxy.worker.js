/**
 * Cloudflare Worker для Untouch:
 * 1) Прокси HostLand → api.telegram.org  (счета Stars, getMe)
 * 2) Входящий webhook Telegram → Worker  (HostLand из РФ часто ловит Connection timed out)
 *
 * Webhook authentication is enforced by PHP. Configure through
 * tools/deploy_telegram_web.ps1 -Mode webhook-setup after deploying PHP.
 * No bot credentials are required in this Worker.
 */

const HOSTLAND_WEBHOOK = 'https://untouch.ballaball.xyz/api/telegram_webhook.php';
export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);

    if (url.pathname === '/webhook' || url.pathname === '/webhook/') {
      if (request.method === 'GET') {
        return json({ ok: true, service: 'untouch-webhook', version: '1.0.26', delivery: 'await-host-authenticated' });
      }
      return handleTelegramWebhook(request, env, ctx);
    }

    const target = 'https://api.telegram.org' + url.pathname + url.search;
    const headers = new Headers(request.headers);
    headers.delete('host');
    return fetch(target, {
      method: request.method,
      headers,
      body: request.method === 'GET' || request.method === 'HEAD' ? undefined : request.body,
    });
  },
};

async function handleTelegramWebhook(request, env, ctx) {
  if (env.WEBHOOK_SECRET && request.headers.get('X-Telegram-Bot-Api-Secret-Token') !== env.WEBHOOK_SECRET) {
    return new Response('forbidden', { status: 403 });
  }
  let update = {};
  const raw = await request.text();
  try {
    update = raw ? JSON.parse(raw) : {};
  } catch {
    return new Response('ok');
  }

  // PHP owns all bot side effects and verifies Telegram's secret before writing.
  // Await every delivery so /start statistics and referrals also retry on errors.
  try { await forwardHostland(raw, request.headers); }
  catch { return new Response('retry', { status: 503 }); }
  return new Response('ok');
}

async function forwardHostland(raw, incomingHeaders) {
  const headers = { 'Content-Type': 'application/json' };
  const secret = incomingHeaders.get('X-Telegram-Bot-Api-Secret-Token');
  if (secret) headers['X-Telegram-Bot-Api-Secret-Token'] = secret;
  const response = await fetch(HOSTLAND_WEBHOOK, {
      method: 'POST',
      headers,
      body: raw,
      signal: AbortSignal.timeout(8000),
  });
  if (!response.ok || (await response.text()).trim() !== 'ok') throw new Error('Webhook not acknowledged');
}

function json(obj) {
  return new Response(JSON.stringify(obj), {
    headers: { 'Content-Type': 'application/json' },
  });
}

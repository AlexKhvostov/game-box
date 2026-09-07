/**
 * Cloudflare Worker для Untouch:
 * 1) Прокси HostLand → api.telegram.org  (счета Stars, getMe)
 * 2) Входящий webhook Telegram → Worker  (HostLand из РФ часто ловит Connection timed out)
 *
 * Настройка:
 * 1. Вставить этот файл в Worker, Deploy
 * 2. Settings → Variables → Add secret: BOT_TOKEN = токен @UntouchGameBot
 * 3. Открыть в браузере (подставить токен):
 *    https://untouch-tg-api.lihach-ok.workers.dev/bot<TOKEN>/setWebhook?url=https://untouch-tg-api.lihach-ok.workers.dev/webhook
 * 4. ping.php → webhook.url должен стать ...workers.dev/webhook
 */

const HOSTLAND_WEBHOOK = 'https://untouch.ballaball.xyz/api/telegram_webhook.php';
const WEBAPP_URL = 'https://untouch.ballaball.xyz/';
const START_TEXT =
  'Untouch — кубик, которого нельзя касаться.\n\n' +
  'Уводите героя от красных. Риски и шаги дают кристаллы. Бейте свой рекорд.\n\n' +
  'Жмите Играть 👇';

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);

    if (url.pathname === '/webhook' || url.pathname === '/webhook/') {
      if (request.method === 'GET') {
        return json({ ok: true, service: 'untouch-webhook' });
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
  let update = {};
  const raw = await request.text();
  try {
    update = raw ? JSON.parse(raw) : {};
  } catch {
    return new Response('ok');
  }

  const text = String(update.message && update.message.text ? update.message.text : '').trim();
  const chatId = update.message && update.message.chat ? update.message.chat.id : null;
  const startMatch = text.match(/^\/start(?:@\w+)?(?:\s+(.*))?$/u);

  if (startMatch && chatId && env.BOT_TOKEN) {
    const startPayload = startMatch[1] ? String(startMatch[1]).trim() : '';
    const from = update.message && update.message.from ? update.message.from : {};
    ctx.waitUntil(sendStart(env.BOT_TOKEN, chatId, startPayload));
    if (/^r\d{1,20}$/.test(startPayload) && from.id) {
      ctx.waitUntil(bindReferral(env, String(from.id), startPayload, from));
    }
  }

  ctx.waitUntil(forwardHostland(raw, request.headers));
  return new Response('ok');
}

async function sendStart(token, chatId, startPayload = '') {
  const playButton = { text: '🎮 Играть', web_app: { url: WEBAPP_URL } };
  await fetch('https://api.telegram.org/bot' + token + '/sendMessage', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      chat_id: chatId,
      text: START_TEXT,
      reply_markup: {
        inline_keyboard: [[playButton]],
      },
    }),
  });
}

async function sha256Hex(text) {
  const buf = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(text));
  return [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, '0')).join('');
}

async function bindReferral(env, inviteeId, startPayload, from) {
  const m = /^r(\d{1,20})$/.exec(startPayload);
  if (!m || !env.BOT_TOKEN) return;
  const inviterId = m[1];
  const sig = await sha256Hex(inviteeId + ':' + inviterId + ':' + env.BOT_TOKEN);
  try {
    await fetch('https://untouch.ballaball.xyz/api/ref_bind.php', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        inviteeId,
        inviterId,
        user: from || {},
        sig,
      }),
      signal: AbortSignal.timeout(8000),
    });
  } catch {
    // HostLand может не ответить — запись попробует PHP webhook.
  }
}

async function forwardHostland(raw, incomingHeaders) {
  const headers = { 'Content-Type': 'application/json' };
  const secret = incomingHeaders.get('X-Telegram-Bot-Api-Secret-Token');
  if (secret) headers['X-Telegram-Bot-Api-Secret-Token'] = secret;
  try {
    await fetch(HOSTLAND_WEBHOOK, {
      method: 'POST',
      headers,
      body: raw,
      signal: AbortSignal.timeout(8000),
    });
  } catch {
    // HostLand может не ответить — /start уже ушёл с Worker.
  }
}

function json(obj) {
  return new Response(JSON.stringify(obj), {
    headers: { 'Content-Type': 'application/json' },
  });
}

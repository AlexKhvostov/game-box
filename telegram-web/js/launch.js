/* Container policy + server-verified Telegram launch, before any game import.
   SDK platform is NOT signed or a cryptographic native-client attestation. */
const nativePlatforms = new Set(['android', 'ios', 'tdesktop', 'macos']);
const gate = document.getElementById('launch-gate');
const status = document.getElementById('launch-status');
const retry = document.getElementById('launch-retry');
const open = document.getElementById('launch-open');
let checking = false;
let started = false;
let providerPromise = null;
const stylesheetLoads = new WeakMap();

function loadStylesheet(node) {
  const previous = stylesheetLoads.get(node);
  if (previous) return previous;
  const pending = new Promise((resolve, reject) => {
    let timer;
    let settled = false;
    const finish = error => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      node.onload = node.onerror = null;
      if (error) {
        // Keep one marker in its original cascade position. A failed or late
        // response cannot apply from the detached node; retry uses a fresh one.
        const replacement = node.cloneNode(false);
        replacement.removeAttribute('rel');
        node.replaceWith(replacement);
        stylesheetLoads.delete(node);
        reject(new Error('styles_unavailable'));
      } else resolve();
    };
    node.onload = () => finish();
    node.onerror = () => finish(true);
    timer = setTimeout(() => finish(true), 20000);
    node.rel = 'stylesheet';
  });
  stylesheetLoads.set(node, pending);
  return pending;
}

async function loadGameStyles() {
  // Parallel bounded loads, reused across retries, never before server ACK.
  await Promise.all([...document.querySelectorAll('link[data-game-style]')].map(loadStylesheet));
}

function script(src, id, timeout = 10000) {
  return new Promise((resolve, reject) => {
    const node = document.createElement('script');
    node.id = id;
    node.async = true;
    let timer;
    const finish = error => {
      clearTimeout(timer);
      node.onload = node.onerror = null;
      if (error) { node.remove(); reject(new Error('provider_unavailable')); }
      else resolve();
    };
    node.onload = () => finish();
    node.onerror = () => finish(true);
    timer = setTimeout(() => finish(true), timeout);
    node.src = src;
    document.head.appendChild(node);
  });
}

async function provider() {
  if (window.Telegram?.WebApp) return window.Telegram.WebApp;
  if (!providerPromise) providerPromise = script('https://telegram.org/js/telegram-web-app.js', 'launch-sdk').catch(error => { providerPromise = null; throw error; });
  await providerPromise;
  return window.Telegram?.WebApp || null;
}

function startParameter(tg) {
  const valid = value => typeof value === 'string' && /^[A-Za-z0-9_-]{1,512}$/.test(value) ? value : '';
  // Used only to preserve a link, never as proof of identity or authorization.
  try {
    const signed = new URLSearchParams(tg?.initData || '').get('start_param');
    if (valid(signed)) return signed;
    const query = new URLSearchParams(location.search);
    for (const key of ['ref', 'start_param', 'startapp', 'tgWebAppStartParam']) if (valid(query.get(key))) return query.get(key);
    const hash = new URLSearchParams(location.hash.replace(/^#/, ''));
    const raw = new URLSearchParams(hash.get('tgWebAppData') || '').get('start_param');
    if (valid(raw)) return raw;
    if (valid(hash.get('tgWebAppStartParam'))) return hash.get('tgWebAppStartParam');
  } catch (_) {}
  return '';
}

function updateLink(tg) {
  const link = new URL('tg://resolve?domain=UntouchGameBot&appname=untouch');
  const param = startParameter(tg);
  if (param) link.searchParams.set('startapp', param);
  open.href = link.href;
}

function applyInsets(tg) {
  const value = raw => Number.isFinite(Number(raw)) ? Math.max(0, Number(raw)) : 0;
  for (const side of ['top', 'right', 'bottom', 'left']) {
    let pixels = value(tg?.safeAreaInset?.[side]) + value(tg?.contentSafeAreaInset?.[side]);
    if (side === 'top' && !pixels && nativePlatforms.has(tg?.platform)) pixels = 44;
    gate.style.setProperty(`--launch-inset-${side}`, `${pixels}px`);
  }
}

function show(text, canRetry = false) {
  status.textContent = text;
  retry.hidden = !canRetry;
}

async function verify(tg) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 10000);
  try {
    const response = await fetch(new URL('../api/launch.php', import.meta.url), {
      method: 'POST', credentials: 'same-origin', cache: 'no-store', signal: controller.signal,
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ platform: tg.platform, initData: tg.initData }),
    });
    const data = await response.json();
    if (response.ok && data?.ok === true && data?.verified === true) return;
    throw new Error(response.status === 401 || response.status === 403 ? 'reopen_required' : 'connection_failed');
  } finally { clearTimeout(timeout); }
}

async function startGame(tg, snapshot) {
  // This is the single import boundary. Build versions propagate to all entries.
  await loadGameStyles();
  if (!window.Adsgram) await script('https://sad.adsgram.ai/js/sad.min.js', 'launch-ads-sdk').catch(() => {});
  if (window.Telegram?.WebApp !== tg || tg.platform !== snapshot.platform || tg.initData !== snapshot.initData) throw new Error('reopen_required');
  const entries = ['main.js', 'neon-window-chrome.js', 'neon-shop-fit.js', 'neon-services-layout.js', 'neon-result-fit.js', 'neon-ranking-layout.js', 'neon-profile-layout.js'];
  started = true;
  document.documentElement.dataset.launchVerified = 'true';
  gate.hidden = true;
  for (const entry of entries) {
    const url = new URL(entry, import.meta.url);
    url.search = new URL(import.meta.url).search;
    await import(url.href);
  }
}

async function checkLaunch() {
  if (checking || started) return;
  const repeat = !retry.hidden;
  // A pending second tap must keep hitting the same disabled control. Reserve
  // the existing status height before replacing it with shorter progress text.
  if (repeat) status.style.minHeight = `${status.getBoundingClientRect().height}px`;
  checking = true;
  retry.disabled = true;
  gate.setAttribute('aria-busy', 'true');
  show('Проверяем запуск в Telegram…', repeat);
  try {
    const tg = await provider();
    updateLink(tg);
    applyInsets(tg);
    // Display the restriction card in Telegram Web too; no game admission.
    await tg?.ready?.();
    applyInsets(tg);
    if (!tg || !nativePlatforms.has(tg.platform)) {
      show('Игра доступна в приложениях Telegram для телефона и компьютера. Telegram Web не поддерживается.', repeat);
      return;
    }
    if (typeof tg.initData !== 'string' || !tg.initData) {
      show('Не удалось подтвердить запуск. Закройте это окно и откройте игру заново через бота.', true);
      return;
    }
    const snapshot = { platform: tg.platform, initData: tg.initData };
    await verify(snapshot);
    if (window.Telegram?.WebApp !== tg || tg.platform !== snapshot.platform || tg.initData !== snapshot.initData) throw new Error('reopen_required');
    show('Запускаем игру…', repeat);
    await startGame(tg, snapshot);
  } catch (error) {
    if (started) {
      delete document.documentElement.dataset.launchVerified;
      gate.hidden = false;
      show('Не удалось загрузить игру. Закройте окно и откройте игру заново через бота.', repeat);
    } else show(error?.message === 'reopen_required' ? 'Запуск не подтверждён или устарел. Закройте окно и откройте игру заново через бота.' : error?.message === 'styles_unavailable' ? 'Не удалось загрузить оформление игры. Проверьте подключение и повторите попытку.' : 'Не удалось проверить запуск. Проверьте подключение и повторите попытку.', true);
  } finally {
    checking = false;
    retry.disabled = started;
    gate.removeAttribute('aria-busy');
  }
}

retry.addEventListener('click', checkLaunch);
updateLink(null);
checkLaunch();

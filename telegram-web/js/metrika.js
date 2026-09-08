/** Яндекс.Метрика для Mini App. Без номера счётчика ничего не грузим. */

let counterId = 0;
let started = false;

function userFromInitData(raw) {
  if (!raw) return null;
  try {
    const params = new URLSearchParams(String(raw));
    const json = params.get('user');
    return json ? JSON.parse(json) : null;
  } catch (_) {
    return null;
  }
}

function telegramLogin() {
  try {
    const tg = window.Telegram?.WebApp;
    let name = String(tg?.initDataUnsafe?.user?.username || '').trim();
    if (!name) {
      const fromInit = userFromInitData(tg?.initData);
      name = String(fromInit?.username || '').trim();
    }
    if (!name) {
      const hash = String(location.hash || '').replace(/^#/, '');
      const payload = new URLSearchParams(hash).get('tgWebAppData');
      const fromHash = userFromInitData(payload || '');
      name = String(fromHash?.username || '').trim();
    }
    name = name.replace(/^@/, '').replace(/[^a-zA-Z0-9_]/g, '');
    return name.slice(0, 32);
  } catch (_) {
    return '';
  }
}

function pageUrl() {
  let base = 'https://untouch.ballaball.xyz/';
  try {
    base = `${location.origin}${location.pathname || '/'}`;
  } catch (_) {}
  const login = telegramLogin();
  if (!login) return base;
  const q = new URLSearchParams({
    utm_source: 'telegram',
    utm_medium: 'miniapp',
    utm_campaign: 'untouch',
    utm_content: login,
  });
  return `${base}?${q.toString()}`;
}

export function initMetrika(rawId) {
  const id = Number(String(rawId ?? '').replace(/\D/g, ''));
  if (!id) return false;
  counterId = id;
  if (started) return true;
  started = true;

  window.ym =
    window.ym ||
    function ymStub() {
      (window.ym.a = window.ym.a || []).push(arguments);
    };
  window.ym.l = 1 * new Date();

  if (![...document.scripts].some((s) => (s.src || '').includes('mc.yandex.ru/metrika/tag.js'))) {
    const script = document.createElement('script');
    script.async = true;
    script.src = `https://mc.yandex.ru/metrika/tag.js?id=${id}`;
    script.onerror = () => console.warn('[metrika] tag.js blocked');
    document.head.appendChild(script);
  }

  // Короткий URL + UTM с @username. Полный #tgWebAppData в Метрику не шлём.
  window.ym(id, 'init', {
    ssr: true,
    webvisor: false,
    clickmap: false,
    accurateTrackBounce: true,
    trackLinks: true,
    trackHash: false,
    url: pageUrl(),
  });
  return true;
}

export function metrikaGoal(name, params) {
  if (!counterId || typeof window.ym !== 'function') return;
  try {
    window.ym(counterId, 'reachGoal', name, params || {});
  } catch (_) {}
}

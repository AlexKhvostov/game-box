/** Яндекс.Метрика для Mini App. Без номера счётчика ничего не грузим. */

let counterId = 0;

export function initMetrika(rawId) {
  const id = Number(String(rawId ?? '').replace(/\D/g, ''));
  if (!id) return false;
  counterId = id;

  window.ym =
    window.ym ||
    function ymStub() {
      (window.ym.a = window.ym.a || []).push(arguments);
    };
  window.ym.l = Date.now();

  if (!document.querySelector('script[src*="mc.yandex.ru/metrika/tag.js"]')) {
    const script = document.createElement('script');
    script.async = true;
    script.src = `https://mc.yandex.ru/metrika/tag.js?id=${id}`;
    document.head.appendChild(script);
  }

  window.ym(id, 'init', {
    ssr: true,
    webvisor: true,
    clickmap: true,
    accurateTrackBounce: true,
    trackLinks: true,
    referrer: document.referrer,
    url: location.href,
  });
  return true;
}

export function metrikaGoal(name, params) {
  if (!counterId || typeof window.ym !== 'function') return;
  try {
    window.ym(counterId, 'reachGoal', name, params || {});
  } catch (_) {}
}

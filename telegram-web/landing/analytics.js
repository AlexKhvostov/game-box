/* Landing-only GA4. Consent and events never depend on game/account services. */
(() => {
  'use strict';
  if (window.UntouchAnalytics) return;
  const id = document.currentScript?.dataset.measurementId || '';
  if (!/^G-[A-Z0-9]+$/.test(id)) return;
  const key = 'untouch_analytics_consent_v1';
  const banner = document.querySelector('[data-analytics-consent]');
  const debug = new URL(location.href).searchParams.get('analytics_debug') === '1';
  const allowedQuery = new Set(['utm_source','utm_medium','utm_campaign','utm_content','utm_term','utm_id','utm_source_platform','utm_creative_format','utm_marketing_tactic']);
  const page = new URL(location.href);
  for (const name of [...page.searchParams.keys()]) if (!allowedQuery.has(name)) page.searchParams.delete(name);
  page.hash = '';
  let referrer = '';
  try { referrer = new URL(document.referrer).origin + '/'; } catch { /* Direct visit. */ }
  let state = 'unknown', initialized = false;
  try { const saved = localStorage.getItem(key); if (['granted','denied'].includes(saved)) state = saved; } catch { /* Current page still works. */ }
  window.dataLayer = window.dataLayer || [];
  window.gtag = window.gtag || function () { window.dataLayer.push(arguments); };
  const consent = analytics => ({analytics_storage:analytics, ad_storage:'denied', ad_user_data:'denied', ad_personalization:'denied'});
  window.gtag('consent', 'default', consent('denied'));

  function send(name, params = {}) {
    if (state !== 'granted') return;
    const details = {...params, send_to:id};
    if (debug) details.debug_mode = true;
    window.gtag('event', name, details);
    if (debug) console.info('[Untouch analytics queued]', name, JSON.stringify(params));
  }
  function forgetCookies() {
    const names = ['_ga', '_ga_' + id.slice(2)];
    for (const name of names) for (const domain of ['', location.hostname, '.' + location.hostname]) {
      document.cookie = name + '=; Max-Age=0; Path=/; SameSite=Lax' + (domain ? '; Domain=' + domain : '');
    }
  }
  function choose(value, persist = true) {
    if (!['granted','denied'].includes(value)) return;
    state = value;
    document.documentElement.dataset.analyticsState = state;
    if (persist) try { localStorage.setItem(key, state); } catch { /* In-memory choice. */ }
    window['ga-disable-' + id] = state !== 'granted';
    window.gtag('consent', 'update', consent(state));
    if (banner) banner.hidden = true;
    if (state === 'denied') { forgetCookies(); return; }
    if (initialized) return;
    initialized = true;
    window.gtag('js', new Date());
    const options = {page_location:page.href, page_referrer:referrer,
      allow_google_signals:false, allow_ad_personalization_signals:false};
    if (debug) options.debug_mode = true;
    // config produces the single initial page_view and parses the original UTM.
    window.gtag('config', id, options);
    const script = document.createElement('script');
    script.id = 'untouch-google-tag'; script.async = true;
    script.src = 'https://www.googletagmanager.com/gtag/js?id=' + encodeURIComponent(id);
    script.onload = () => { document.documentElement.dataset.analyticsTag = 'loaded'; };
    script.onerror = () => { document.documentElement.dataset.analyticsTag = 'blocked'; };
    document.head.append(script);
  }
  function requestConsent() {
    if (!banner) return;
    banner.hidden = false;
    banner.querySelector('[data-analytics-allow]')?.focus();
  }
  banner?.querySelector('[data-analytics-allow]')?.addEventListener('click', () => choose('granted'));
  banner?.querySelector('[data-analytics-deny]')?.addEventListener('click', () => choose('denied'));
  for (const control of document.querySelectorAll('[data-analytics-settings]')) control.addEventListener('click', requestConsent);
  function placement(node) {
    if (node.closest('header')) return 'header';
    if (node.closest('#demo-widget')) return 'demo';
    if (node.closest('.hero')) return 'hero';
    if (node.closest('.final-cta')) return 'final';
    if (node.closest('footer')) return 'footer';
    return 'other';
  }
  document.addEventListener('click', event => {
    const control = event.target.closest?.('a,button');
    if (!control) return;
    const link = control.getAttribute('href') || '';
    if (control.hasAttribute('data-app-store')) {
      send('download_click', {store:'app_store', placement:placement(control), availability:'coming_soon'});
    } else if (/^https:\/\/play\.google\.com\//.test(link)) {
      send('download_click', {store:'google_play', placement:placement(control), availability:'closed_test'});
    } else if (/^https:\/\/t\.me\/UntouchGameBot(?:\/|$)/.test(link)) {
      send('telegram_click', {placement:placement(control)});
    }
  }, true);
  window.addEventListener('untouch:demo-start', event => {
    const attempt = Math.max(1, Number(event.detail?.attempt_number) || 1);
    send(attempt === 1 ? 'demo_start' : 'demo_retry', {attempt_number:attempt});
  });
  window.addEventListener('untouch:demo-end', event => {
    send('demo_end', {attempt_number:Math.max(1,Number(event.detail?.attempt_number)||1),
      duration_seconds:Math.max(0,Math.round(Number(event.detail?.duration_ms)||0)/1000)});
  });
  window.UntouchAnalytics = Object.freeze({setConsent:choose, requestConsent});
  document.documentElement.dataset.analyticsState = state;
  if (state === 'unknown') { if (banner) banner.hidden = false; }
  else choose(state, false);
})();

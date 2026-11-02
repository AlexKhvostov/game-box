(() => {
  'use strict';
  const preferenceKey = 'untouch_landing_language_v1';
  const valid = value => value === 'en' || value === 'ru';
  let current = null;
  function preferredLanguage() {
    const explicit = new URL(location.href).searchParams.get('lang');
    if (valid(explicit)) return explicit;
    try {
      const saved = localStorage.getItem(preferenceKey);
      if (valid(saved)) return saved;
    } catch { /* The default and switch still work without browser storage. */ }
    return 'en';
  }
  function apply(language, {remember = false, updateUrl = false} = {}) {
    if (!valid(language)) return;
    const changed = current !== language;
    document.documentElement.lang = language;
    for (const node of document.querySelectorAll('[data-en][data-ru]')) {
      node.textContent = node.dataset[language];
    }
    for (const attribute of ['aria-label', 'alt', 'title', 'content', 'src']) {
      for (const node of document.querySelectorAll(`[data-${attribute}-en][data-${attribute}-ru]`)) {
        const value = node.getAttribute(`data-${attribute}-${language}`);
        if (node.getAttribute(attribute) !== value) node.setAttribute(attribute, value);
      }
    }
    for (const button of document.querySelectorAll('[data-language]')) {
      button.setAttribute('aria-pressed', String(button.dataset.language === language));
    }
    for (const link of document.querySelectorAll('[data-legal-page]')) {
      link.setAttribute('href', link.dataset.legalPage + '/' + (language === 'en' ? '#english' : ''));
    }
    const canonical = document.querySelector('link[rel="canonical"]');
    if (canonical) canonical.href = 'https://untouch.fun/' + (language === 'ru' ? '?lang=ru' : '');
    if (changed) {
      const frame = document.querySelector('#landing-playable');
      if (frame) {
        // The demo selects its language at startup. Reopen it only on a real language change.
        const demo = new URL(frame.dataset.demoSrc, location.href);
        demo.searchParams.set('lang', language);
        frame.src = demo.href;
      }
      current = language;
    }
    if (remember) {
      try { localStorage.setItem(preferenceKey, language); } catch { /* Session-only choice. */ }
    }
    if (updateUrl) {
      const url = new URL(location.href);
      url.searchParams.set('lang', language);
      // Preserve campaign parameters and the current section.
      history.replaceState(null, '', url.href);
    }
  }
  for (const button of document.querySelectorAll('[data-language]')) {
    button.addEventListener('click', () => apply(button.dataset.language, {remember:true, updateUrl:true}));
  }
  window.addEventListener('popstate', () => apply(preferredLanguage()));
  apply(preferredLanguage());
})();

(() => {
  'use strict';
  const params = new URL(location.href).searchParams;
  function render(lang) {
    document.documentElement.lang = lang;
    document.title = lang === 'ru'
      ? 'Untouch — Уже в Google Play'
      : 'Untouch — Available on Google Play';
    for (const element of document.querySelectorAll('[data-en]')) {
      element.textContent = element.dataset[lang];
    }
    for (const button of document.querySelectorAll('[data-lang]')) {
      button.setAttribute('aria-pressed', String(button.dataset.lang === lang));
    }
  }
  for (const button of document.querySelectorAll('[data-lang]')) {
    button.addEventListener('click', () => render(button.dataset.lang));
  }
  render(params.get('lang') === 'ru' ? 'ru' : 'en');
})();

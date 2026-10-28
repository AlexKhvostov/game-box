(() => {
  'use strict';
  const frame = document.querySelector('#landing-playable');
  if (!frame) return;
  const control = action => frame.contentWindow?.postMessage({type: 'untouch:landing-control', action}, location.origin);
  window.addEventListener('untouch:pause-demo', () => control('pause'));
  document.querySelector('[data-demo-reset]')?.addEventListener('click', () => control('reset'));
  window.addEventListener('message', event => {
    if (event.origin !== location.origin || event.source !== frame.contentWindow || event.data?.type !== 'untouch:landing-demo') return;
    if (!['start', 'end'].includes(event.data.event)) return;
    const attempt = Number(event.data.attempt_number);
    if (!Number.isInteger(attempt) || attempt < 1 || attempt > 3) return;
    const detail = {attempt_number: attempt};
    if (event.data.event === 'end') {
      const duration = Number(event.data.duration_ms);
      if (!Number.isFinite(duration) || duration < 0) return;
      detail.duration_ms = Math.floor(duration);
    }
    window.dispatchEvent(new CustomEvent(`untouch:demo-${event.data.event}`, {detail}));
  });
  if ('IntersectionObserver' in window) {
    new IntersectionObserver(entries => {
      if (!entries[0].isIntersecting) control('pause');
    }).observe(frame);
  }
})();

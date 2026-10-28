(() => {
  'use strict';
  const mascot = document.querySelector('[data-watching-cube]');
  if (!mascot) return;
  const eyes = [...mascot.querySelectorAll('.cube-eye')];
  const reducedMotion = matchMedia('(prefers-reduced-motion: reduce)');
  let pendingFrame = 0;
  let pointer = null;
  let visible = true;

  function center() {
    pointer = null;
    if (pendingFrame) cancelAnimationFrame(pendingFrame);
    pendingFrame = 0;
    mascot.style.removeProperty('--look-x');
    mascot.style.removeProperty('--look-y');
    for (const eye of eyes) {
      eye.style.removeProperty('--look-x');
      eye.style.removeProperty('--look-y');
    }
  }

  function paint() {
    pendingFrame = 0;
    if (!pointer || !visible || document.hidden || reducedMotion.matches) return;
    for (const eye of eyes) {
      const rect = eye.getBoundingClientRect();
      const dx = pointer.x - (rect.left + rect.width / 2);
      const dy = pointer.y - (rect.top + rect.height / 2);
      const distance = Math.hypot(dx, dy);
      const strength = Math.min(distance / (rect.width * .6), 1);
      eye.style.setProperty('--look-x', `${distance ? dx / distance * rect.width * .16 * strength : 0}px`);
      eye.style.setProperty('--look-y', `${distance ? dy / distance * rect.height * .1 * strength : 0}px`);
    }
  }

  function follow(event) {
    if (!visible || reducedMotion.matches || document.hidden) return;
    pointer = { x: event.clientX, y: event.clientY };
    if (!pendingFrame) pendingFrame = requestAnimationFrame(paint);
  }

  document.addEventListener('pointermove', follow, { passive: true });
  document.addEventListener('pointerdown', follow, { passive: true });
  window.addEventListener('untouch:demo-pointer', event => {
    if (!Number.isFinite(event.detail?.clientX) || !Number.isFinite(event.detail?.clientY)) return;
    follow(event.detail);
  });
  document.documentElement.addEventListener('pointerleave', center);
  document.addEventListener('visibilitychange', center);
  window.addEventListener('blur', center);
  reducedMotion.addEventListener('change', center);
  if ('IntersectionObserver' in window) {
    const observer = new IntersectionObserver(entries => {
      visible = entries[0].isIntersecting;
      if (!visible) center();
    });
    observer.observe(mascot);
  }
})();

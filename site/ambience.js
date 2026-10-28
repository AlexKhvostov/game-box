(() => {
  'use strict';
  const mascot = document.querySelector('[data-watching-cube]');
  if (!mascot) return;
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
  }

  function paint() {
    pendingFrame = 0;
    if (!pointer || !visible || document.hidden || reducedMotion.matches) return;
    const rect = mascot.getBoundingClientRect();
    const dx = pointer.x - (rect.left + rect.width * .44);
    const dy = pointer.y - (rect.top + rect.height * .49);
    const distance = Math.hypot(dx, dy);
    const strength = Math.min(distance / 180, 1);
    const limit = rect.width * .025;
    mascot.style.setProperty('--look-x', `${distance ? dx / distance * limit * strength : 0}px`);
    mascot.style.setProperty('--look-y', `${distance ? dy / distance * limit * strength : 0}px`);
  }

  function follow(event) {
    if (!visible || reducedMotion.matches || document.hidden) return;
    pointer = { x: event.clientX, y: event.clientY };
    if (!pendingFrame) pendingFrame = requestAnimationFrame(paint);
  }

  document.addEventListener('pointermove', follow, { passive: true });
  document.addEventListener('pointerdown', follow, { passive: true });
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

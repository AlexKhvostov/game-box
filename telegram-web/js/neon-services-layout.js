// UI-only native breakpoints. No game/economy methods, timers or network work.
const root = document.querySelector('#sheet-root');
const panel = document.querySelector('#sheet-panel');
const body = document.querySelector('#sheet-body');
if (root && panel && body) {
  let frame = 0;
  let activeBody = null;
  let observed = new Set();
  const resize = new ResizeObserver(schedule);
  const mutations = new MutationObserver(schedule);

  function visibleShop() {
    return !root.hidden && root.classList.contains('open') &&
      panel.classList.contains('sheet-crystals')
      ? body.querySelector('.crystals-sheet') : null;
  }

  function clearActive() {
    if (frame) cancelAnimationFrame(frame);
    frame = 0;
    resize.disconnect();
    mutations.disconnect();
    observed.clear();
    activeBody = null;
  }

  function schedule() {
    if (!visibleShop()) { clearActive(); return; }
    if (!frame) frame = requestAnimationFrame(layout);
  }

  function layout() {
    frame = 0;
    const shop = visibleShop();
    if (!shop) { clearActive(); return; }
    if (shop !== activeBody) {
      resize.disconnect();
      observed.clear();
      mutations.disconnect();
      activeBody = shop;
      mutations.observe(shop, { childList: true, characterData: true, subtree: true });
    }
    const daily = shop.querySelector('.neon-daily-pane');
    const dayLabel = daily?.querySelector('.daily-day-name');
    const rent = shop.querySelector('.neon-rent-pane');
    const rentTitle = rent?.querySelector('.rent-title');
    daily?.classList.toggle('daily-large-text', !!dayLabel &&
      parseFloat(getComputedStyle(dayLabel).fontSize) > 16);
    rent?.classList.toggle('two-columns', !!rentTitle && rent.clientWidth >= 304 &&
      parseFloat(getComputedStyle(rentTitle).fontSize) <= 13 * (16 / 12));
    const targets = new Set([daily, dayLabel, rent, rentTitle].filter(Boolean));
    for (const node of observed) if (!targets.has(node)) resize.unobserve(node);
    for (const node of targets) if (!observed.has(node)) resize.observe(node);
    observed = targets;
  }

  function lifecycle() {
    if (!visibleShop()) clearActive();
    else schedule();
  }
  const lifecycleObserver = new MutationObserver(lifecycle);
  lifecycleObserver.observe(root, { attributes: true, attributeFilter: ['class', 'hidden'] });
  lifecycleObserver.observe(panel, { attributes: true, attributeFilter: ['class'] });
  lifecycle();
}

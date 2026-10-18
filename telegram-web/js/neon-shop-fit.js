// Paint/layout only: Android FittedBox equivalent for the currently visible shop.
const shopRoot = document.getElementById('sheet-root');
const shopPanel = document.getElementById('sheet-panel');
const shopBody = document.getElementById('sheet-body');
let fitFrame = 0;
let watchingBody = false;
let watched = new Set();

function visibleShop() {
  if (!shopRoot || shopRoot.hidden || !shopRoot.classList.contains('open') || !shopPanel?.classList.contains('sheet-crystals')) return null;
  return shopBody?.querySelector('.crystals-sheet') || null;
}

function scheduleFit() {
  if (!visibleShop()) { stopActiveFit(); return; }
  if (!fitFrame) fitFrame = requestAnimationFrame(fitVisibleShop);
}

const shopResize = new ResizeObserver(scheduleFit);
const shopContent = new MutationObserver(scheduleFit);

function stopActiveFit() {
  if (fitFrame) cancelAnimationFrame(fitFrame);
  fitFrame = 0;
  shopResize.disconnect();
  watched.clear();
  if (watchingBody) shopContent.disconnect();
  watchingBody = false;
}

function fitVisibleShop() {
  fitFrame = 0;
  const shop = visibleShop();
  if (!shop) { stopActiveFit(); return; }
  const tabLabel = shop.querySelector('.tab-txt');
  if (tabLabel) {
    const font = parseFloat(getComputedStyle(tabLabel).fontSize);
    for (const [key, value] of [['--shop-window-height', `${512 * Math.min(1.5, Math.max(1, font / 12))}px`], ['--shop-tab-label-h', `${Math.min(22, Math.max(15, font * 1.1))}px`]]) {
      if (shopPanel.style.getPropertyValue(key) !== value) shopPanel.style.setProperty(key, value);
    }
  }
  const balance = shop.querySelector('#sheet-crystal-balance');
  const label = shop.querySelector('.cb-label');
  if (balance && label) {
    const height = Math.min(110, Math.max(62, parseFloat(getComputedStyle(balance).fontSize) * 1.1 + parseFloat(getComputedStyle(label).fontSize) * 1.2 + 14));
    const value = `${height}px`;
    if (shopPanel.style.getPropertyValue('--shop-header-h') !== value) shopPanel.style.setProperty('--shop-header-h', value);
  }
  const gift = shop.querySelector('#gift-btn');
  if (gift) {
    const title = gift.querySelector('.gift-ready-lbl');
    const value = gift.querySelector('.amt, .gift-timer');
    const titleHeight = Math.max(21, parseFloat(getComputedStyle(title).fontSize) * 1.1);
    const valueHeight = Math.max(26, parseFloat(getComputedStyle(value).fontSize) * 1.1);
    for (const [key, height] of [['--shop-gift-title-h', titleHeight], ['--shop-gift-value-h', valueHeight]]) {
      const desired = `${height}px`;
      if (gift.style.getPropertyValue(key) !== desired) gift.style.setProperty(key, desired);
    }
  }
  const pane = shop.querySelector('.neon-shop-packs-pane');
  if (pane) pane.classList.toggle('compact', pane.clientHeight < 300);
  const next = new Set(pane ? [pane] : []);
  for (const slot of shop.querySelectorAll('[data-shop-fit]')) {
    const leaf = slot.firstElementChild;
    if (!leaf) continue;
    next.add(slot); next.add(leaf);
    const css = getComputedStyle(slot);
    const left = parseFloat(css.paddingLeft) || 0, right = parseFloat(css.paddingRight) || 0;
    const top = parseFloat(css.paddingTop) || 0, bottom = parseFloat(css.paddingBottom) || 0;
    const width = Math.max(0, slot.clientWidth - left - right);
    const height = Math.max(0, slot.clientHeight - top - bottom);
    if (!width || !height) continue;
    const scale = Math.min(1, width / Math.max(1, leaf.scrollWidth, leaf.offsetWidth), height / Math.max(1, leaf.scrollHeight, leaf.offsetHeight));
    const alignLeft = slot.dataset.shopFit === 'left';
    const desired = {
      left: `${alignLeft ? left : left + width / 2}px`,
      top: `${top + height / 2}px`,
      transformOrigin: alignLeft ? 'left center' : 'center',
      transform: `${alignLeft ? 'translateY(-50%)' : 'translate(-50%, -50%)'} scale(${scale})`,
    };
    for (const [property, value] of Object.entries(desired)) if (leaf.style[property] !== value) leaf.style[property] = value;
  }
  for (const node of watched) if (!next.has(node)) shopResize.unobserve(node);
  for (const node of next) if (!watched.has(node)) shopResize.observe(node);
  watched = next;
}

function syncFitLifecycle() {
  if (!visibleShop()) { stopActiveFit(); return; }
  if (!watchingBody) {
    shopContent.observe(shopBody, { childList: true, characterData: true, subtree: true });
    watchingBody = true;
  }
  scheduleFit();
}

// Two small persistent lifecycle targets reopen active observation when needed.
const shopLifecycle = new MutationObserver(syncFitLifecycle);
if (shopRoot && shopPanel && shopBody) {
  shopLifecycle.observe(shopRoot, { attributes: true, attributeFilter: ['class', 'hidden'] });
  shopLifecycle.observe(shopPanel, { attributes: true, attributeFilter: ['class'] });
  syncFitLifecycle();
}

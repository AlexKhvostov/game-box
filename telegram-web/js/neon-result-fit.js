// DOM paint/layout only. Existing result calculations/actions remain in main.js.
const root = document.querySelector('#result-overlay');
if (root) {
  let frame = 0;
  let active = false;
  let opened = !root.hidden;
  let watched = new Set();
  const resize = new ResizeObserver(schedule);
  const contents = new MutationObserver(schedule);

  function visible() { return !root.hidden; }
  function clear() {
    if (frame) cancelAnimationFrame(frame);
    frame = 0;
    resize.disconnect();
    contents.disconnect();
    watched.clear();
    active = false;
    opened = false;
  }
  function schedule() {
    if (!visible()) { clear(); return; }
    if (!frame) frame = requestAnimationFrame(fit);
  }
  function fit() {
    frame = 0;
    if (!visible()) { clear(); return; }
    if (!active || opened) {
      for (const owner of root.querySelectorAll('.result-viewport, .result-scroll')) owner.scrollTop = 0;
      opened = false;
    }
    if (!active) {
      contents.observe(root, { childList: true, characterData: true, subtree: true });
      active = true;
    }
    const card = root.querySelector('.result-card');
    const time = root.querySelector('#result-time');
    if (card && time) card.style.setProperty('--result-text-scale', String(Math.min(2, Math.max(1, parseFloat(getComputedStyle(time).fontSize) / 46))));
    const targets = new Set();
    for (const slot of root.querySelectorAll('[data-result-fit]')) {
      const leaf = slot.firstElementChild;
      if (!leaf) continue;
      slot.hidden = leaf.hidden;
      targets.add(slot);
      targets.add(leaf);
      if (slot.hidden) continue;
      const style = getComputedStyle(slot);
      const width = Math.max(0, slot.clientWidth - parseFloat(style.paddingLeft) - parseFloat(style.paddingRight));
      const height = Math.max(0, slot.clientHeight - parseFloat(style.paddingTop) - parseFloat(style.paddingBottom));
      const naturalWidth = Math.max(leaf.scrollWidth, leaf.offsetWidth, 1);
      const naturalHeight = Math.max(leaf.scrollHeight, leaf.offsetHeight, 1);
      const scale = Math.min(1, width / naturalWidth, height / naturalHeight);
      leaf.style.transform = `translateY(-50%) scale(${scale})`;
    }
    for (const node of watched) if (!targets.has(node)) resize.unobserve(node);
    for (const node of targets) if (!watched.has(node)) resize.observe(node);
    watched = targets;
  }
  const lifecycle = new MutationObserver(records => {
    if (!visible()) { clear(); return; }
    if (records.some(record => record.attributeName === 'hidden' && record.oldValue !== null)) opened = true;
    schedule();
  });
  lifecycle.observe(root, { attributes: true, attributeOldValue: true, attributeFilter: ['hidden', 'class'] });
  if (visible()) schedule();
}

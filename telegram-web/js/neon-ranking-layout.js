// Readonly presentation flags for native large-text layouts. No action/model work.
const root = document.querySelector('#sheet-root');
const panel = document.querySelector('#sheet-panel');
const body = document.querySelector('#sheet-body');
if (root && panel && body) {
  let frame = 0;
  let active = false;
  let watched = new Set();
  const resize = new ResizeObserver(schedule);
  const content = new MutationObserver(schedule);
  function visible() { return !root.hidden && root.classList.contains('open') && panel.classList.contains('sheet-leaderboard'); }
  function clear() {
    if (frame) cancelAnimationFrame(frame);
    frame = 0;
    resize.disconnect(); content.disconnect(); watched.clear(); active = false;
  }
  function schedule() { if (!visible()) { clear(); return; } if (!frame) frame = requestAnimationFrame(layout); }
  function layout() {
    frame = 0;
    if (!visible()) { clear(); return; }
    if (!active) { content.observe(body, { childList: true, characterData: true, subtree: true }); active = true; }
    const sheet = body.querySelector('.neon-ranking');
    const legend = sheet?.querySelector('.lb-legend-text');
    sheet?.classList.toggle('leaderboard-large-text', !!legend && parseFloat(getComputedStyle(legend).fontSize) > 15);
    const chrome = sheet?.querySelector('.lb-chrome');
    const list = sheet?.querySelector('.leaderboard-sheet-scroll');
    const contentPanel = sheet?.querySelector('.lb-content-panel');
    const actions = sheet?.querySelector('.lb-actions');
    if (sheet && chrome && list && contentPanel && actions) {
      const style = getComputedStyle(sheet);
      const legendStyle = legend && getComputedStyle(legend);
      const lineHeight = parseFloat(legendStyle?.lineHeight) || (parseFloat(legendStyle?.fontSize) || 10) * 1.2;
      // Virtual pinned geometry is identical before/after moving the same nodes.
      const available = sheet.clientHeight - chrome.offsetHeight - actions.offsetHeight
        - (parseFloat(style.paddingTop) || 0) - (parseFloat(style.paddingBottom) || 0);
      const scrollChrome = available < Math.max(64, lineHeight * 2);
      sheet.classList.toggle('leaderboard-scroll-chrome', scrollChrome);
      if (scrollChrome && chrome.parentElement !== list) list.prepend(chrome);
      else if (!scrollChrome && chrome.parentElement !== sheet) sheet.insertBefore(chrome, contentPanel);
    }
    const player = body.querySelector('.neon-player .player-modal-card');
    const label = player?.querySelector('.stat-label');
    player?.classList.toggle('player-large-text', !!label && parseFloat(getComputedStyle(label).fontSize) > 16.5);
    const targets = new Set([sheet, legend, chrome, actions, player, label].filter(Boolean));
    for (const node of watched) if (!targets.has(node)) resize.unobserve(node);
    for (const node of targets) if (!watched.has(node)) resize.observe(node);
    watched = targets;
  }
  const lifecycle = new MutationObserver(() => { if (visible()) schedule(); else clear(); });
  lifecycle.observe(root, { attributes: true, attributeFilter: ['hidden', 'class'] });
  lifecycle.observe(panel, { attributes: true, attributeFilter: ['class'] });
  if (visible()) schedule();
}

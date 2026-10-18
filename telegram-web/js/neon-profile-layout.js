// Readonly native compact/text-scale flags. Profile actions and data stay intact.
const root = document.querySelector('#sheet-root');
const panel = document.querySelector('#sheet-panel');
const body = document.querySelector('#sheet-body');
if (root && panel && body) {
  let frame = 0;
  let active = false;
  let watched = new Set();
  const resize = new ResizeObserver(schedule);
  const content = new MutationObserver(schedule);
  function visible() { return !root.hidden && root.classList.contains('open') && panel.classList.contains('sheet-profile'); }
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
    const sheet = body.querySelector('.neon-profile');
    const sample = sheet?.querySelector('.profile-field-title');
    const font = sample ? parseFloat(getComputedStyle(sample).fontSize) : 12;
    const compact = innerHeight <= 600 && font <= 12;
    sheet?.classList.toggle('profile-compact', compact);
    sheet?.classList.toggle('profile-person-header', compact || font > 18);
    sheet?.classList.toggle('profile-large-text', font > 18);
    const input = sheet?.querySelector('.profile-nick-input');
    const inputFont = input ? parseFloat(getComputedStyle(input).fontSize) || 16 : 16;
    sheet?.classList.toggle('profile-nick-large', inputFont > 24);
    const fieldHeight = `${48 * (inputFont / 16)}px`;
    if (sheet && sheet.style.getPropertyValue('--profile-nick-field-height') !== fieldHeight) sheet.style.setProperty('--profile-nick-field-height', fieldHeight);
    const targets = new Set([sheet, sample, input].filter(Boolean));
    for (const node of watched) if (!targets.has(node)) resize.unobserve(node);
    for (const node of targets) if (!watched.has(node)) resize.observe(node);
    watched = targets;
  }
  const lifecycle = new MutationObserver(() => { if (visible()) schedule(); else clear(); });
  lifecycle.observe(root, { attributes: true, attributeFilter: ['hidden', 'class'] });
  lifecycle.observe(panel, { attributes: true, attributeFilter: ['class'] });
  if (visible()) schedule();
}

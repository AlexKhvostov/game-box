// The shared close control uses the existing sheet action, including Plus back.
document.getElementById('sheet-window-close')?.addEventListener('click', (event) => {
  event.stopPropagation();
  window.app?.sheets?.close();
});

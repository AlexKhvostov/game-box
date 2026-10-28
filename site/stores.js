const appStoreDialog = document.querySelector('#app-store-dialog');
let opener;
for (const button of document.querySelectorAll('[data-app-store]')) button.addEventListener('click', () => {
  opener = button;
  window.dispatchEvent(new Event('untouch:pause-demo'));
  appStoreDialog.showModal();
});
appStoreDialog.querySelector('[data-close-store]').addEventListener('click', () => appStoreDialog.close());
appStoreDialog.addEventListener('click', event => {
  const bounds = appStoreDialog.getBoundingClientRect();
  if (event.target === appStoreDialog && (event.clientX < bounds.left || event.clientX > bounds.right || event.clientY < bounds.top || event.clientY > bounds.bottom)) appStoreDialog.close();
});
appStoreDialog.addEventListener('close', () => opener?.focus());

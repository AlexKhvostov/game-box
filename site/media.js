// This hosting route can stall on large responses. Bounded HTTP ranges keep
// original image quality and the unchanged game module without large transfers.
const STEP = 8192;
let active = 0;
const waiting = [];
async function limited(action, priority = false) {
  if (active >= 2) await new Promise(resolve => priority ? waiting.unshift(resolve) : waiting.push(resolve));
  active++;
  try { return await action(); }
  finally { active--; waiting.shift()?.(); }
}
async function rangedBlob(url, size, type, priority = false) {
  const parts = await Promise.all(Array.from({length:Math.ceil(size / STEP)}, (_, i) => limited(async () => {
    const start = i * STEP, end = Math.min(size - 1, start + STEP - 1);
    for (let attempt = 0; attempt < 3; attempt++) {
      try {
        const response = await fetch(url, {headers:{Range:`bytes=${start}-${end}`}, signal:AbortSignal.timeout(30000)});
        if (response.status !== 206 || response.headers.get('Content-Range') !== `bytes ${start}-${end}/${size}`) throw new Error('Unexpected range response');
        const bytes = await response.arrayBuffer();
        if (bytes.byteLength !== end - start + 1) throw new Error('Incomplete range');
        return bytes;
      } catch (error) { if (attempt === 2) throw error; }
    }
  }, priority)));
  return new Blob(parts, {type});
}
export async function loadGameModule(url) {
  if (!url.search) url.search = new URL(import.meta.url).search || '?v=android-palette-20261013';
  try {
  const path='demo-engine/'+url.pathname.split('/').at(-1);
  const info=(await delivery)[path];
  let blob;
  if(info) blob=await imageBlob(path,'text/javascript',true);
  else {
  const response = await fetch(url, {method:'HEAD'});
  if (!response.ok) throw new Error('Game module unavailable');
  const size = Number(response.headers.get('Content-Length'));
  if (!size || size > 100000) throw new Error('Invalid module size');
  blob = await rangedBlob(url, size, 'text/javascript', true);
  }
  const source = (await blob.text()).replace(/from '(\.\/[^']+)'/g, (_, path) => `from '${new URL(path, url).href}'`);
  return await import(URL.createObjectURL(new Blob([source], {type:'text/javascript'})));
  } catch { return await import(url.href); }
}
const cache = new Map();
const deliveryUrl = new URL('./assets/delivery.json', import.meta.url);
deliveryUrl.search = new URL(import.meta.url).search;
const delivery = fetch(deliveryUrl).then(response => {
  if (!response.ok) throw new Error('Image delivery manifest unavailable');
  return response.json();
});
async function imageBlob(path, type='image/webp', priority=false) {
  const info = (await delivery)[path];
  if (!info) throw new Error('Asset missing from delivery manifest');
  const parts = await Promise.all(info.parts.map(part => limited(async () => {
    for (let attempt=0;attempt<3;attempt++) {
      try {
        const response = await fetch(new URL(part, document.baseURI), {signal:AbortSignal.timeout(30000)});
        if (!response.ok) throw new Error('Image part unavailable');
        const payload = await response.json();
        return Uint8Array.from(atob(payload.data), value => value.charCodeAt(0));
      } catch (error) { if (attempt===2) throw error; }
    }
  },priority)));
  const blob = new Blob(parts, {type});
  if (blob.size !== info.size) throw new Error('Incomplete image delivery');
  const digest = [...new Uint8Array(await crypto.subtle.digest('SHA-256', await blob.arrayBuffer()))].map(b => b.toString(16).padStart(2,'0')).join('');
  if (digest !== info.sha256) throw new Error('Image integrity mismatch');
  return blob;
}
async function showImage(image) {
  const path = image.dataset.src;
  if (!path || image.dataset.requested) return;
  image.dataset.requested = 'true';
  try {
    if (!cache.has(path)) cache.set(path, imageBlob(path).then(blob => URL.createObjectURL(blob)));
    const source = await cache.get(path);
    // The observer already deferred loading. Native lazy loading can reject
    // decode() while this image is offscreen, despite a valid verified Blob.
    image.loading = 'eager';
    image.src = source;
  } catch (error) {
    // Standard delivery remains available if range support is unavailable.
    image.src = path;
    console.warn('Image range delivery failed', path, error.message);
  }
}
const lazy = new IntersectionObserver(entries => {
  for (const entry of entries) if (entry.isIntersecting) { showImage(entry.target); lazy.unobserve(entry.target); }
}, {rootMargin:'600px'});
for (const image of document.querySelectorAll('img[data-src]')) {
  if (image.loading === 'lazy') lazy.observe(image); else showImage(image);
}

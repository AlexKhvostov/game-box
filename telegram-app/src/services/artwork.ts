// Keep the result illustration decoded before the first round finishes, as
// Android GameHomeScreen does. Retain successful loads for the WebView session.
const decoded = new Map<string, Promise<HTMLImageElement>>();
export const resultArtwork = '/assets/branding/ui/result-scene-v1.png';
export function loadArtwork(src: string): Promise<HTMLImageElement> {
  let pending = decoded.get(src);
  if (!pending) {
    pending = new Promise<HTMLImageElement>((resolve, reject) => {
      const art = new Image();
      art.onload = () => art.decode().then(() => resolve(art), reject);
      art.onerror = () => reject(new Error('artwork_unavailable'));
      art.src = src;
    }).catch(error => { decoded.delete(src); throw error; });
    decoded.set(src, pending);
  }
  return pending;
}
export function warmArtwork() {
  for (const src of [resultArtwork, '/assets/branding/ui/hud-player-portrait-v1.png',
    '/assets/branding/ui/simple-energy-helmet.png', '/assets/branding/ui/simple-energy-jump.png',
    '/assets/branding/ui/jump-v1.png']) void loadArtwork(src).catch(() => {});
}

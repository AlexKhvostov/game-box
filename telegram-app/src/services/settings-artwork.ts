// The settings illustrations share at most four decoded resources while their
// windows are mounted. A partial HTTP200 PNG must never become a ready image.
export const settingsArtworkPaths = {
  sensitivity: '/assets/branding/ui/sensitivity-scene-v1.png',
  atlas: '/assets/branding/ui/settings-icons-v2.png',
  'hero-off': '/assets/branding/ui/settings-faceless-v1.png',
  'enemy-off': '/assets/branding/ui/settings-enemy-faceless-v1.png',
} as const;
export type SettingsArtworkKind = keyof typeof settingsArtworkPaths;
export type ArtworkState = {status: 'loading' | 'ready' | 'error'; url: string};
type Resource = {url: string; dispose: () => void};
const MAX_BYTES = 8 * 1024 * 1024;
const crcTable = Uint32Array.from({length: 256}, (_, value) => {
  let c = value;
  for (let i = 0; i < 8; i++) c = c & 1 ? 0xedb88320 ^ c >>> 1 : c >>> 1;
  return c >>> 0;
});
export function validateSettingsPng(bytes: Uint8Array) {
  const signature = [137,80,78,71,13,10,26,10];
  if (bytes.length < 45 || bytes.length > MAX_BYTES || signature.some((n,i) => bytes[i] !== n)) throw Error('artwork_invalid');
  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  let offset = 8, first = true, data = false;
  while (offset + 12 <= bytes.length) {
    const length = view.getUint32(offset), end = offset + 12 + length;
    if (end > bytes.length) throw Error('artwork_incomplete');
    const type = String.fromCharCode(...bytes.subarray(offset + 4, offset + 8));
    if (!/^[A-Za-z]{4}$/.test(type)) throw Error('artwork_invalid');
    let crc = 0xffffffff;
    for (let i = offset + 4; i < end - 4; i++) crc = crcTable[(crc ^ bytes[i]!) & 255]! ^ crc >>> 8;
    if (((crc ^ 0xffffffff) >>> 0) !== view.getUint32(end - 4)) throw Error('artwork_corrupt');
    if (first) {
      if (type !== 'IHDR' || length !== 13) throw Error('artwork_invalid');
      const width = view.getUint32(offset + 8), height = view.getUint32(offset + 12);
      if (!width || !height || width > 4096 || height > 4096) throw Error('artwork_dimensions');
      first = false;
    } else if (type === 'IHDR') throw Error('artwork_invalid');
    if (type === 'IDAT' && length > 0) data = true;
    if (type === 'IEND') {
      if (length !== 0 || !data || end !== bytes.length) throw Error('artwork_incomplete');
      return;
    }
    offset = end;
  }
  throw Error('artwork_incomplete');
}

export async function fetchSettingsArtwork(kind: SettingsArtworkKind, signal: AbortSignal): Promise<Resource> {
  if (!Object.hasOwn(settingsArtworkPaths, kind)) throw Error('artwork_invalid');
  const response = await fetch(settingsArtworkPaths[kind], {signal});
  if (!response.ok || !/^image\/png(?:;|$)/i.test(response.headers.get('content-type') ?? '')) throw Error('artwork_unavailable');
  if (Number(response.headers.get('content-length')) > MAX_BYTES) throw Error('artwork_too_large');
  const parts: Uint8Array[] = []; let size = 0;
  if (response.body) {
    const reader = response.body.getReader();
    try {
      for (;;) {
        const part = await reader.read(); if (part.done) break;
        size += part.value.byteLength;
        if (size > MAX_BYTES) { await reader.cancel(); throw Error('artwork_too_large'); }
        parts.push(part.value);
      }
    } finally { reader.releaseLock(); }
  } else { const part = new Uint8Array(await response.arrayBuffer()); size = part.length; parts.push(part); }
  if (signal.aborted) throw new DOMException('Aborted', 'AbortError');
  const bytes = new Uint8Array(size); let offset = 0;
  for (const part of parts) { bytes.set(part, offset); offset += part.length; }
  validateSettingsPng(bytes);
  const url = URL.createObjectURL(new Blob([bytes.buffer], {type: 'image/png'})), image = new Image();
  let disposed = false;
  const dispose = () => { if (disposed) return; disposed = true; image.removeAttribute('src'); URL.revokeObjectURL(url); };
  let abort: (() => void) | undefined;
  try {
    image.src = url;
    await Promise.race([image.decode(), new Promise<never>((_, reject) => {
      abort = () => reject(new DOMException('Aborted', 'AbortError'));
      signal.addEventListener('abort', abort, {once: true});
      if (signal.aborted) abort();
    })]);
    if (signal.aborted || !image.naturalWidth || !image.naturalHeight) throw Error('artwork_unavailable');
    return {url, dispose};
  } catch (error) { dispose(); throw error; }
  finally { if (abort) signal.removeEventListener('abort', abort); }
}

type Entry = {listeners: Set<(state: ArtworkState) => void>; state: ArtworkState; controller?: AbortController; resource?: Resource; generation: number; timer?: ReturnType<typeof setTimeout>};
export class SettingsArtworkPool {
  private entries = new Map<SettingsArtworkKind, Entry>();
  constructor(private loader = fetchSettingsArtwork, private timeoutMs = 40000) {}
  acquire(kind: SettingsArtworkKind, listener: (state: ArtworkState) => void) {
    if (!Object.hasOwn(settingsArtworkPaths, kind)) throw Error('artwork_invalid');
    let entry = this.entries.get(kind);
    if (!entry) { entry = {listeners: new Set(), state: {status: 'loading', url: ''}, generation: 0}; this.entries.set(kind, entry); }
    const current = entry; current.listeners.add(listener); listener(current.state);
    if (!current.controller && !current.resource && current.state.status !== 'error') this.start(kind, current);
    let released = false;
    return {
      retry: () => { if (!released && current.state.status === 'error') this.start(kind, current); },
      unavailable: () => { if (!released && current.state.status === 'ready') { current.resource?.dispose(); current.resource = undefined; this.publish(current, {status: 'error', url: ''}); } },
      release: () => {
        if (released) return; released = true; current.listeners.delete(listener);
        if (!current.listeners.size) { current.generation++; current.controller?.abort(); clearTimeout(current.timer); current.resource?.dispose(); this.entries.delete(kind); }
      },
    };
  }
  private publish(entry: Entry, state: ArtworkState) { entry.state = state; for (const listener of entry.listeners) listener(state); }
  private start(kind: SettingsArtworkKind, entry: Entry) {
    if (entry.controller || !entry.listeners.size) return;
    const controller = new AbortController(), generation = ++entry.generation; entry.controller = controller;
    this.publish(entry, {status: 'loading', url: ''});
    let timer: ReturnType<typeof setTimeout>;
    const timeout = new Promise<never>((_, reject) => { timer = setTimeout(() => { controller.abort(); reject(Error('artwork_timeout')); }, this.timeoutMs); entry.timer = timer; });
    // Also dispose a late decoder result after a timeout/last release.
    const task = Promise.resolve().then(() => {
      if (controller.signal.aborted || entry.generation !== generation || !entry.listeners.size) throw Error('artwork_cancelled');
      return this.loader(kind, controller.signal);
    }).then(resource => {
      if (controller.signal.aborted || entry.generation !== generation || !entry.listeners.size) { resource.dispose(); throw Error('artwork_cancelled'); }
      return resource;
    });
    void Promise.race([task, timeout]).then(resource => {
      if (entry.generation !== generation || !entry.listeners.size) { resource.dispose(); return; }
      entry.resource = resource; this.publish(entry, {status: 'ready', url: resource.url});
    }).catch(() => { if (entry.generation === generation && entry.listeners.size) { if (entry.controller === controller) entry.controller = undefined; this.publish(entry, {status: 'error', url: ''}); } })
      .finally(() => { clearTimeout(timer); if (entry.timer === timer) entry.timer = undefined; if (entry.controller === controller) entry.controller = undefined; });
  }
  get size() { return this.entries.size; }
}
export const settingsArtworkPool = new SettingsArtworkPool();

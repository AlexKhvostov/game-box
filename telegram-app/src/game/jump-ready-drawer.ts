import {createJumpGlowDrawer, createJumpGlowPixels, jumpGlowFraction, type JumpGlowPlacement} from './jump-glow';
import {jumpReadyFlash} from './jump-ready-signal';

export interface JumpReadyPlacement extends JumpGlowPlacement {
  ready: boolean;
  readyAgeMs?: number | null;
  reduced?: boolean;
}

export function createJumpReadyPixels(side = 256, flash = false): Uint8ClampedArray {
  const pixels = createJumpGlowPixels(side, {radius: .1});
  for (let i = 0; i < pixels.length; i += 4) {
    pixels[i] = flash ? 255 : 232;
    pixels[i + 1] = 255;
    pixels[i + 2] = flash ? 236 : 105;
    pixels[i + 3] = Math.round(Math.min(255, pixels[i + 3]! * (flash ? 1.65 : 1.3)));
  }
  return pixels;
}

/** Selected H02.B: cached warm charge, lemon ready, one white-warm pulse. */
export function createJumpReadyDrawer(): (c: CanvasRenderingContext2D, p: JumpReadyPlacement) => void {
  const charging = createJumpGlowDrawer({radius: .1});
  function texture(flash = false) {
    const canvas = document.createElement('canvas'); canvas.width = canvas.height = 256;
    const c = canvas.getContext('2d')!;
    const data = c.createImageData(256, 256); data.data.set(createJumpReadyPixels(256, flash));
    c.putImageData(data, 0, 0); return canvas;
  }
  const ready = texture(), flash = texture(true);
  return (c, p) => {
    if (p.enabled === false || ![p.x, p.y, p.size, p.opacity ?? 1].every(Number.isFinite) || p.size <= 0) return;
    if (!p.ready) { charging(c, p); return; }
    c.save();
    try {
      c.globalAlpha *= jumpGlowFraction(p.opacity ?? 1);
      c.drawImage(ready, p.x, p.y, p.size, p.size);
      const pulse = jumpReadyFlash(p.readyAgeMs, p.reduced);
      if (pulse > 0) { c.globalAlpha *= pulse; c.drawImage(flash, p.x, p.y, p.size, p.size); }
    } finally { c.restore(); }
  };
}

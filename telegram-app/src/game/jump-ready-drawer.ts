import {createJumpGlowPixels, jumpGlowFraction, type JumpGlowPlacement} from './jump-glow.ts';
import {paintJumpSideNeon,paintJumpBodyFlash} from './jump-side-neon.ts';

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

/** Approved H02.3: white sides, one lamp flash, lemon neon readiness. */
export function createJumpReadyDrawer(): (c: CanvasRenderingContext2D, p: JumpReadyPlacement) => void {
  return (c,p) => {
    if(p.enabled===false || ![p.x,p.y,p.size,p.opacity??1].every(Number.isFinite) || p.size<=0)return;
    c.save();
    try {
      c.globalAlpha*=jumpGlowFraction(p.opacity??1);
      const placement={x:p.x,y:p.y,size:p.size,jump:{enabled:true,ready:p.ready,progress:p.progress,readyAgeMs:p.readyAgeMs},reduced:p.reduced};
      paintJumpBodyFlash(c,placement);paintJumpSideNeon(c,placement);
    } finally {c.restore();}
  };
}

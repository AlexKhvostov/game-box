// Read-only sketch snapshot of current jump artwork; game source is unchanged.
const clamp = (v, low, high) => Math.min(high, Math.max(low, v));
export const jumpGlowFraction = (v) => Number.isFinite(v) ? clamp(v, 0, 1) : 0;
function validateTextureSide(side) {
    if (!Number.isInteger(side) || side < 16 || side > 1024)
        throw new RangeError('jump_glow_texture_size');
}
/** Generate the reusable RGBA layer once, not in the animation loop. */
export function createJumpGlowPixels(side = 256, style = {}) {
    validateTextureSide(side);
    const finite = (v, fallback) => v !== undefined && Number.isFinite(v) ? v : fallback;
    const radius = clamp(finite(style.radius, .15), 0, .45);
    const eyeDepth = clamp(finite(style.eyeDepth, .14), .01, .23);
    const endDepth = clamp(finite(style.endDepth, .22), eyeDepth, .32);
    const strength = clamp(finite(style.strength, 1), 0, 1);
    const pixels = new Uint8ClampedArray(side * side * 4);
    for (let row = 0; row < side; row++) {
        const y = (row + .5) / side;
        const corner = Math.pow(Math.abs(2 * y - 1), 1.4);
        const depth = eyeDepth + (endDepth - eyeDepth) * corner;
        const rimFade = clamp(Math.min(y, 1 - y) / .035, 0, 1);
        // The light follows the rounded side boundary; its source never floats inward.
        const dy = y < radius ? radius - y : y > 1 - radius ? y - (1 - radius) : 0;
        const inset = dy > 0 ? radius - Math.sqrt(Math.max(0, radius * radius - dy * dy)) : 0;
        for (let col = 0; col < side; col++) {
            const x = (col + .5) / side, d = Math.min(x, 1 - x) - inset;
            if (d < 0 || d > .34)
                continue;
            // Smooth horizontal falloff. There is deliberately no vertical blur:
            // partial charge is cropped when drawn, keeping 66% distinct from 100%.
            const diffuse = .94 * Math.exp(-Math.pow(d / (depth * .8), 2));
            const core = .38 * Math.exp(-Math.pow((d - .025) / .032, 2));
            const seam = .10 * Math.exp(-d / .014);
            const alpha = (1 - (1 - diffuse) * (1 - core) * (1 - seam)) * strength * rimFade;
            const coverage = clamp(d * side + .5, 0, 1);
            const i = (row * side + col) * 4;
            pixels[i] = 255;
            pixels[i + 1] = 243 + 12 * core;
            pixels[i + 2] = 122 + 88 * core;
            pixels[i + 3] = Math.round(255 * alpha * coverage);
        }
    }
    return pixels;
}
/** One shared canvas texture; drawImage is the only per-frame artwork operation. */
export function createJumpGlowDrawer(style = {}, textureSide = 256) {
    validateTextureSide(textureSide);
    const texture = document.createElement('canvas');
    texture.width = texture.height = textureSide;
    const context = texture.getContext('2d');
    if (!context)
        throw new Error('jump_glow_canvas_unavailable');
    const data = context.createImageData(textureSide, textureSide);
    data.data.set(createJumpGlowPixels(textureSide, style));
    context.putImageData(data, 0, 0);
    return (c, { x, y, size, progress, enabled = true, opacity = 1 }) => {
        const p = enabled ? jumpGlowFraction(progress) : 0;
        if (p <= 0 || !Number.isFinite(size) || size <= 0 || !Number.isFinite(x) || !Number.isFinite(y))
            return;
        const top = textureSide * (1 - p), height = textureSide * p;
        c.save();
        try {
            c.globalAlpha *= jumpGlowFraction(opacity);
            c.imageSmoothingEnabled = true;
            // Crop a static full-height texture. Its depth stays tied to hero anatomy.
            c.drawImage(texture, 0, top, textureSide, height, x, y + size * (1 - p), size, size * p);
        }
        finally {
            c.restore();
        }
    };
}
let sharedDrawer;
export function drawJumpGlow(context, placement) {
    (sharedDrawer ??= createJumpGlowDrawer())(context, placement);
}

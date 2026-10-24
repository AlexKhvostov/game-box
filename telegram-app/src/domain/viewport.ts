// Matches lib/ui/game_viewport.dart and GameHomeScreen's actual mobile layout.
export const REFERENCE_WIDTH = 412;
export const FIELD_SIDE = 380;
export function viewportGeometry(width: number, height: number, safeTop = 0, safeBottom = 0) {
  const scale = Math.min(width / REFERENCE_WIDTH, 1);
  const logicalHeight = Math.max(0, height - safeTop - safeBottom) / scale;
  return { scale, width: Math.min(width, REFERENCE_WIDTH), logicalHeight,
    fieldSide: FIELD_SIDE * scale, margin: 16 * scale,
    hudHeight: Math.min(112, logicalHeight * .2) * scale };
}
export function textScale(width: number, height: number, system = 1, safeVertical = 0) {
  const logicalHeight = Math.max(0, height - safeVertical) / Math.min(width / REFERENCE_WIDTH, 1);
  const clamp = (v: number, min: number, max: number) => Math.min(max, Math.max(min, v));
  const factor = clamp(Math.sqrt(logicalHeight / 740), .9, 1);
  const limit = Math.min(1.15 + .25 * clamp((width - 320) / 92, 0, 1),
    1.1 + .3 * clamp((logicalHeight - 560) / 180, 0, 1));
  return Math.min(system, limit) * factor;
}

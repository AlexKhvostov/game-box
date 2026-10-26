export const floorBrandAsset = '/assets/branding/ui/untouch-floor-brand-v1.webp';
export const floorBrandOpacity = .28;
export const floorBrandAspectRatio = 960 / 448;

// Same footer geometry as GameFloorBrand on Android, in logical game units.
export function floorBrandSize(width: number, height: number) {
  const w = Math.min(264, Math.max(0, width) * .78);
  const h = Math.min(w / floorBrandAspectRatio, 124, Math.max(0, height) * .60);
  return {width: h * floorBrandAspectRatio, height: h};
}

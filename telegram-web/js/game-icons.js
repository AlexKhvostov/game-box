/** Иконки из lib/ui — RestingCubeIcon, CrystalCubeIcon, Material (как во Flutter). */

const ICONS = 'icons';

export function restingCubeImg(size = 18, className = '') {
  const cls = ['game-icon', 'resting-cube-img', className].filter(Boolean).join(' ');
  return `<img src="${ICONS}/resting-cube.svg" width="${size}" height="${size}" alt="" class="${cls}" draggable="false">`;
}

export function uiIconImg(name, size = 22, className = '') {
  const cls = ['game-icon', 'ui-icon', className].filter(Boolean).join(' ');
  return `<img src="${ICONS}/ui-${name}.svg" width="${size}" height="${size}" alt="" class="${cls}" draggable="false">`;
}

export function heartIcon(size = 18, className = '') {
  return uiIconImg('heart', size, className);
}

export function shopWatchIcon(frozen, size = 22) {
  return uiIconImg(frozen ? 'timer' : 'play', size);
}

export function rentKindIcon(kind, size = 22) {
  return uiIconImg(kind === 'jump' ? 'jump' : 'shield', size);
}

export function checkMarkHtml(size = 12, dark = false) {
  const fill = dark ? '#0E1419' : '#3DDC97';
  return `<svg class="inline-check" width="${size}" height="${size}" viewBox="0 0 24 24" aria-hidden="true"><path fill="${fill}" d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-2 15-5-5 1.41-1.41L10 14.17l7.59-7.59L19 8l-9 9z"/></svg>`;
}

/** TabBar — Icons.* как в crystals_sheet.dart, currentColor для темы таба. */
export const TAB_ICON_SVG = {
  daily: `<svg class="tab-svg" viewBox="0 0 24 24" aria-hidden="true"><path fill="currentColor" d="M19 4h-1V2h-2v2H8V2H6v2H5a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V6a2 2 0 0 0-2-2zm0 16H5V10h14v10zM7 12h2v2H7v-2zm4 0h2v2h-2v-2zm4 0h2v2h-2v-2z"/></svg>`,
  shop: `<svg class="tab-svg" viewBox="0 0 24 24" aria-hidden="true"><path fill="currentColor" d="M4 4h16v2H4V4zm1 4h14l-1.25 10a1.5 1.5 0 0 1-1.49 1.3H7.74a1.5 1.5 0 0 1-1.49-1.3L5 8zm4.5 3a1.5 1.5 0 0 0-1.5 1.5v2.5a1.5 1.5 0 0 0 3 0v-2.5A1.5 1.5 0 0 0 10.5 11z"/></svg>`,
  rent: `<svg class="tab-svg" viewBox="0 0 24 24" aria-hidden="true"><path fill="currentColor" d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1 5v5.25l3.15 1.85-.9 1.54L11 13V7h2z"/></svg>`,
  earn: `<svg class="tab-svg" viewBox="0 0 24 24" aria-hidden="true"><path fill="currentColor" d="M12 2l2.39 7.26H22l-6.19 4.5 2.36 7.24L12 16.77 5.83 21l2.36-7.24L2 9.26h7.61L12 2z"/></svg>`,
};

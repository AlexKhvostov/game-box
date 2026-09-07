/** CrystalCubeIcon — lib/ui/crystal_cube_icon.dart */
const CRYSTAL_SVG = 'icons/crystal.svg';

export function crystalImg(size = 24, glow = false) {
  const cls = glow ? 'crystal-img glow' : 'crystal-img';
  return `<img src="${CRYSTAL_SVG}" width="${size}" height="${size}" alt="" class="${cls}" draggable="false">`;
}

export function crystalRewardBadge(amount, { emphasized = true, plusHint = '' } = {}) {
  const showDouble = plusHint && plusHint.includes('×') && !plusHint.includes('Boost');
  const hintHtml = plusHint
    ? `<span class="crystal-plus-hint">${plusHint}</span>`
    : '';
  return `
    <span class="crystal-reward-badge ${emphasized ? 'emph' : 'soft'}${showDouble ? ' has-double' : ''}">
      ${crystalImg(14, emphasized || showDouble)}
      <span class="crystal-reward-amt">+${amount}</span>
      ${hintHtml}
    </span>`;
}

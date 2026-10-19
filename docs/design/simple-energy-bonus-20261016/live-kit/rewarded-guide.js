// UIKit E03: mirrors Flutter RewardedAdGuide, without contacting an ad network.
const svg=(content,view='0 0 300 100')=>`<svg viewBox="${view}" preserveAspectRatio="none" fill="none" aria-hidden="true">${content}</svg>`;
let artworkId=0;
const arrowPath='M5 14H28V7Q28 4 30.5 5.5L43 16Q45 18 43 20L30.5 30.5Q28 32 28 29V22H5C-.3 22-.3 14 5 14Z';
const defs=id=>`<defs>
<linearGradient id="${id}-cyan" x2="0" y2="1"><stop stop-color="#aafaff"/><stop offset=".4" stop-color="#54e9ff"/><stop offset="1" stop-color="#13b6e6"/></linearGradient>
<linearGradient id="${id}-rim" x2="1" y2="1"><stop stop-color="#b5fdff"/><stop offset=".5" stop-color="#54e9ff"/><stop offset="1" stop-color="#159ac5"/></linearGradient>
<linearGradient id="${id}-screen"><stop stop-color="#13191f" stop-opacity="0"/><stop offset=".65" stop-color="#11161c"/></linearGradient>
<linearGradient id="${id}-edge"><stop stop-color="#54e9ff" stop-opacity="0"/><stop offset=".5" stop-color="#a5f8ff"/><stop offset="1" stop-color="#54e9ff"/></linearGradient>
<linearGradient id="${id}-button" x2="1" y2="1"><stop stop-color="#45484a"/><stop offset="1" stop-color="#191b1d"/></linearGradient>
<linearGradient id="${id}-hand" x2="1" y2="1"><stop stop-color="#fff"/><stop offset="1" stop-color="#d4f4ff"/></linearGradient>
<filter id="${id}-glow" x="-60%" y="-60%" width="220%" height="220%"><feGaussianBlur stdDeviation="2.3"/></filter></defs>`;
const arrow=id=>`<path d="${arrowPath}" fill="#54e9ff" opacity=".45" filter="url(#${id}-glow)"/><path d="${arrowPath}" transform="translate(0 1.3)" fill="#00668e"/><path d="${arrowPath}" fill="url(#${id}-cyan)" stroke="#9dffff" stroke-opacity=".5" stroke-width=".7" stroke-linejoin="round"/>`;
const step=(n,wait,action)=>{
  const id=`rg-art-${++artworkId}`;
  return `<section class="rg-step" aria-label="${n}. ${wait}. ${action}">
${svg(`${defs(id)}<circle cx="13" cy="15" r="12" fill="url(#${id}-rim)"/><text x="13" y="21" text-anchor="middle" fill="#002638" font-size="16" font-weight="900">${n}</text>
<circle cx="67" cy="52" r="26" stroke="#54e9ff" stroke-width="5" opacity=".5" filter="url(#${id}-glow)"/>
<circle cx="67" cy="52" r="26" fill="#003147" stroke="url(#${id}-rim)" stroke-width="3.2"/>
<g stroke="#54e9ff" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><path d="M67 34v17l12 11"/>${n===1?'<path d="m100 35 4-3m-1 13h6m-9 10 4 3" stroke-width="2.7"/>':'<circle cx="100" cy="51" r=".8"/><circle cx="108" cy="51" r=".8" opacity=".8"/><circle cx="116" cy="51" r=".8" opacity=".6"/>'}</g>
<g transform="translate(125 39) scale(.7083 .75)">${arrow(id)}</g>
<path d="M164 7h98q25 0 25 25v58H164Z" fill="url(#${id}-screen)"/>
<path d="M170 7h92q25 0 25 25v56" stroke="#54e9ff" stroke-width="4" opacity=".5" filter="url(#${id}-glow)"/>
<path d="M170 7h92q25 0 25 25v56" stroke="url(#${id}-edge)" stroke-width="2.5" stroke-linecap="round"/>
<g stroke="#747b80" stroke-width="1.5"><rect x="253" y="18" width="19" height="8" rx="2"/><path d="M272 20v4m-42 2v-3m4 3v-5m4 5v-7m4 7v-9"/></g>
<circle cx="255" cy="58" r="22" fill="#080b0e"/><circle cx="255" cy="57" r="20" fill="url(#${id}-button)" stroke="#53585a"/>
${n===1?'<path d="m248 48 11 9-11 9Z" fill="#e2e5e6"/><path d="M263 49v16" stroke="#e2e5e6" stroke-width="3" stroke-linecap="round"/>':'<path d="m248 50 14 14m0-14-14 14" stroke="#e2e5e6" stroke-width="3" stroke-linecap="round"/>'}
<path d="m275 36 6-6m-10 0 2-7" stroke="#54e9ff" stroke-width="3" stroke-linecap="round"/>
<path d="M279 92Q274 92 271 86L262 69C260 65 261 62 264 62C267 62 268 64 270 68L277 80 275 76C274 73 278 71 281 75L284 81 282 78C281 75 285 74 288 78L291 84 290 82C289 79 293 79 295 83L298 90Q300 94 295 96L289 98Q284 100 279 94Z" fill="url(#${id}-hand)" stroke="#54e9ff" stroke-width="1.2" stroke-linejoin="round"/>
<path d="m274 75 4 7m4-2 3 1m4 2 3 5" stroke="#6ccde3" stroke-opacity=".6" stroke-width=".8" stroke-linecap="round"/>`)}
<div class="rg-step-labels"><strong>${wait}</strong><strong>${action}</strong></div></section>`;
};
const down=()=>{const id=`rg-flow-${++artworkId}`;return `<span class="rg-down" aria-hidden="true">${svg(`${defs(id)}<g transform="translate(36 0) rotate(90)">${arrow(id)}</g>`,'0 0 36 48')}</span>`;};
export function rewardedGuideBody({reward=40,waitLabel=''}={}) {
  const amount=Number.isSafeInteger(reward)&&reward>0?reward:40;
  return `<div class="rg-body"><p class="rg-intro">Досмотрите рекламу</p>
  ${step(1,'Подождите','Перейдите')}${down()}${step(2,'Ещё немного','Закройте')}${down()}
  <div class="rg-reward"><span>+${amount} <i aria-hidden="true">ϟ</i></span><strong>Бонус ваш!</strong></div>
  <button class="neon-btn primary rg-launch" data-action="start-video" ${waitLabel?'disabled data-ad-wait="prompt"':''}><span aria-hidden="true">▶</span> ${waitLabel||'Смотреть рекламу'}</button>
  <button class="text-button rg-cancel" data-action="close">Не сейчас</button>
  <div class="rg-disclosure">Яндекс: данные соединения и устройства.<div>18+ · Добровольно · <details><summary>О рекламе и данных</summary><p>18+. Для видео Яндекс получает данные соединения и доступные SDK идентификаторы устройства. Без персонализации и геолокации. Нажатие «Смотреть рекламу» разрешает видео на сеанс.</p><p>Кнопки появляются не сразу. Вид рекламы может отличаться; иногда сразу появляется крестик. В UI kit видео демонстрационное, настоящая рекламная сеть не вызывается.</p></details></div></div></div>`;
}

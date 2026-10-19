// UIKit E03: mirrors Flutter RewardedAdGuide, without contacting an ad network.
const svg=(content,view='0 0 300 100')=>`<svg viewBox="${view}" fill="none" aria-hidden="true">${content}</svg>`;
const step=(n,wait,action)=>`<section class="rg-step" aria-label="${n}. ${wait}. ${action}">
${svg(`<circle cx="13" cy="15" r="12" fill="#54e9ff"/><text x="13" y="21" text-anchor="middle" fill="#002638" font-size="16" font-weight="900">${n}</text>
<g stroke="#54e9ff" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><circle cx="67" cy="52" r="26" fill="#00384c"/><path d="M67 34v17l12 11"/><path d="M132 52h18m-8-8 8 8-8 8"/><circle cx="100" cy="51" r=".8"/><circle cx="108" cy="51" r=".8"/><circle cx="116" cy="51" r=".8"/></g>
<path d="M168 8h94q25 0 25 25v56H164Z" fill="#11161c"/><path d="M168 8h94q25 0 25 25v56" stroke="#54e9ff" stroke-width="2.6"/>
<g stroke="#747b80" stroke-width="1.5"><rect x="253" y="18" width="19" height="8" rx="2"/><path d="M272 20v4m-42 2v-3m4 3v-5m4 5v-7m4 7v-9"/></g>
<circle cx="255" cy="58" r="22" fill="#080b0e"/><circle cx="255" cy="57" r="20" fill="#272b2f" stroke="#53585a"/>
${n===1?'<path d="m248 48 11 9-11 9Z" fill="#e2e5e6"/><path d="M263 49v16" stroke="#e2e5e6" stroke-width="3" stroke-linecap="round"/>':'<path d="m248 50 14 14m0-14-14 14" stroke="#e2e5e6" stroke-width="3" stroke-linecap="round"/>'}
<path d="m275 36 6-6m-10 0 2-7" stroke="#54e9ff" stroke-width="3" stroke-linecap="round"/>
<path d="m277 91-7-7-6-12q-2-5 1-6t5 3l4 8v-4q3-3 6 1 4-3 7 2 5-2 7 4l4 9-7 8Z" fill="#f0fbff" stroke="#54e9ff" stroke-width="1.5"/>`)}
<div class="rg-step-labels"><strong>${wait}</strong><strong>${action}</strong></div></section>`;
const down='<span class="rg-down" aria-hidden="true">↓</span>';
export function rewardedGuideBody({reward=40,waitLabel=''}={}) {
  const amount=Number.isSafeInteger(reward)&&reward>0?reward:40;
  return `<div class="rg-body"><p class="rg-intro">Досмотрите рекламу</p>
  ${step(1,'Подождите','Перейдите')}${down}${step(2,'Ещё немного','Закройте')}${down}
  <div class="rg-reward"><span>+${amount} <i aria-hidden="true">ϟ</i></span><strong>Бонус ваш!</strong></div>
  <button class="neon-btn primary rg-launch" data-action="start-video" ${waitLabel?'disabled data-ad-wait="prompt"':''}><span aria-hidden="true">▶</span> ${waitLabel||'Смотреть рекламу'}</button>
  <button class="text-button rg-cancel" data-action="close">Не сейчас</button>
  <div class="rg-disclosure">Яндекс: данные соединения и устройства.<div>18+ · Добровольно · <details><summary>О рекламе и данных</summary><p>18+. Для видео Яндекс получает данные соединения и доступные SDK идентификаторы устройства. Без персонализации и геолокации. Нажатие «Смотреть рекламу» разрешает видео на сеанс.</p><p>Кнопки появляются не сразу. Вид рекламы может отличаться; иногда сразу появляется крестик. В UI kit видео демонстрационное, настоящая рекламная сеть не вызывается.</p></details></div></div></div>`;
}

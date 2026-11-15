import {windowCloseIcon} from './icons.js';
import {checkedLevel} from './level-up-animation.js';
const names=['Первый','Второй','Третий','Четвёртый','Пятый','Шестой','Седьмой'];
export const levelTitle=level=>`${names[checkedLevel(level)-1]} уровень`;
export function levelUpContents(level,{titleId,copyId,closable=true}){
  checkedLevel(level);
  return `<section class="lu-window-content" data-part="surface"><header class="lu-dialog-head" data-part="header"><div><small>НОВЫЙ УРОВЕНЬ</small><h2 id="${titleId}">Поздравляем!</h2></div>${closable?`<button type="button" class="lu-close" data-levelup-close aria-label="Закрыть поздравление">${windowCloseIcon}</button>`:''}</header>
    <div data-levelup-scene data-part="scene"></div>
    <footer class="lu-dialog-footer" data-part="actions"><div class="lu-rank-announcement" id="${copyId}" data-part="rank"><span class="lu-rank-kicker">УРОВЕНЬ ПОВЫШЕН</span><div class="lu-rank-banner"><i class="lu-rank-wing lu-rank-wing--left" aria-hidden="true"></i><strong data-levelup-copy>${levelTitle(level)}</strong><i class="lu-rank-wing lu-rank-wing--right" aria-hidden="true"></i></div></div><button type="button" class="lu-accept" data-levelup-accept data-part="accept"><span>Продолжить</span><i aria-hidden="true"></i></button></footer></section>`;
}

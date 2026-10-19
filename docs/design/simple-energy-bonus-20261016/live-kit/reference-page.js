import {referenceCatalog} from "./references/catalog.js";

export {referenceCatalog};
export const referenceById=id=>referenceCatalog.find(item=>item.id===id);
const sourceName=page=>({
  1:"Баланс главного экрана",2:"Главное окно энергии",
  3:"Подписка и видео",4:"Приглашения и покупки",5:"Шлем и прыжок",
})[page];
const grid=(group,cls="")=>'<div class="reference-grid '+cls+'">'+referenceCatalog.filter(item=>item.group===group).map(item=>
  '<article class="reference-card"><h3>'+item.title+'</h3><button class="reference-thumb" data-action="reference-'+item.id+'" aria-label="Рассмотреть: '+item.title+'"><img src="references/'+item.file+'" width="'+item.width+'" height="'+item.height+'" loading="lazy" alt="'+item.title+'"><span class="zoom-hint" aria-hidden="true">Рассмотреть ↗</span></button><p class="reference-source"><strong>PDF · лист '+item.page+'</strong> / '+sourceName(item.page)+'<br>'+item.width+' × '+item.height+' px · '+(group==="boards"?"исходный лист":"исходный фрагмент")+'</p></article>'
).join("")+'</div>';
export function referencePage() {
  return '<section class="ranking-reference-latest"><div><h2>График среднего · эскиз</h2><p>Столбики попыток и линия среднего. В живом компоненте показано 100 попыток, подсветка выделяет текущие 50. Числа и порог в эскизе условные; компонент использует действующую формулу.</p><a href="#average-chart">Открыть компонент UIKit →</a></div><a href="references/proposals/average-chart-v1.png" target="_blank" rel="noopener"><img src="references/proposals/average-chart-v1.png" alt="Эскиз графика среднего результата"></a></section>'+ '<section class="ranking-reference-latest"><div><h2>Реклама · согласованный эскиз</h2><p>Подождите → перейдите → ещё немного подождите → закройте → получите энергию. Схематические уголки без рекламного текста.</p><a href="#rewarded-guide">Открыть компонент UIKit →</a></div><a href="references/proposals/rewarded-guide-v2.png" target="_blank" rel="noopener"><img src="references/proposals/rewarded-guide-v2.png" alt="Согласованный эскиз инструкции рекламы: ожидание, переход, закрытие, бонус"></a></section>'+
    '<section class="ranking-reference-latest"><div><h2>Рейтинг · новый референс</h2><p>Вкладки «Рекорд» и «Средние» соединены с содержимым. «Мои попытки» в шапке; во «Средних» показано общее число попыток.</p><a href="#ranking">Открыть живой прототип →</a></div><a href="references/proposals/ranking-tabs-v2.png" target="_blank" rel="noopener"><img src="references/proposals/ranking-tabs-v2.png" alt="Актуальный референс рейтинга: Рекорд и Средние, два состояния одного окна"></a></section><section class="reference-intro"><div><h2>Оригинальные референсы</h2><p>Те самые окна и детали из подготовленного PDF. Каждый фрагмент извлечён из исходной иллюстрации. Нажмите на окно или деталь, чтобы рассмотреть крупно.</p></div><a class="reference-pdf" href="references/untouch-energy-ui-kit-20261016.pdf" target="_blank" rel="noopener">Открыть весь PDF ↗</a></section>'+
    '<div class="section-head"><h2><span class="index">R01</span>Отдельные окна</h2><p>Главные состояния, подписка, видео, друзья, покупка и усиления</p></div>'+grid("windows")+
    '<div class="section-head"><h2><span class="index">R02</span>Кнопки, иллюстрации и детали</h2><p>Золото, неон, баланс, кубик, шлем и жест прыжка</p></div>'+grid("details","reference-details-grid")+
    '<div class="section-head"><h2><span class="index">R03</span>Исходные листы целиком</h2><p>Полная композиция иллюстраций на страницах PDF</p></div>'+grid("boards","reference-board-grid")+
    '<p class="reference-notes">Это страница исходных изображений для визуальной сверки. Интерактивные окна находятся во вкладках «Компоненты» и «Сценарий». Показанные в референсах коды, игроки и системные окна демонстрационные.</p>';
}
export function referenceViewer(id) {
  const item=referenceById(id),index=referenceCatalog.findIndex(x=>x.id===id);
  if(!item)return "";
  return '<header class="reference-viewer-head"><h2>'+item.title+'</h2><button class="icon-btn close" data-action="close" aria-label="Закрыть референс">✕</button></header><div class="reference-image-stage"><img src="references/'+item.file+'" alt="'+item.title+'"></div><div class="reference-viewer-info"><span>PDF · лист '+item.page+' / '+sourceName(item.page)+'<br>'+item.width+' × '+item.height+' px</span><a href="references/'+item.file+'" target="_blank" rel="noopener">Исходный размер ↗</a></div><nav class="reference-viewer-nav" aria-label="Просмотр референсов"><button class="neon-btn" data-action="reference-prev" '+(index===0?"disabled":"")+'>← Назад</button><span>'+(index+1)+' / '+referenceCatalog.length+'</span><button class="neon-btn" data-action="reference-next" '+(index===referenceCatalog.length-1?"disabled":"")+'>Далее →</button></nav>';
}

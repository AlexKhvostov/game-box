// Isolated UI-kit fixtures. No account, wallet, ranking or network mutations.
export const averageChartDemo=Array.from({length:100},(_,i)=>i%13===3?200+(i%8)*100:1000+((i*7307+1931)%19001));
export function averageChartSeries(durations,{windowSize=50,previousWeightPercent=92,minDurationMs=0}={}) {
  const eligible=[],weight=previousWeightPercent/100;
  const rows=durations.map((ms,index)=>{
    const included=ms>minDurationMs;
    if(included)eligible.push(ms);
    const used=eligible.slice(-windowSize);
    let sum=0,total=0;
    for(let j=used.length-1,w=1;j>=0;j--,w*=weight){sum+=used[j]*w;total+=w;}
    return {index,ms,included,average:total?sum/total:null};
  });
  const active=new Set(rows.filter(r=>r.included).slice(-windowSize).map(r=>r.index));
  return rows.map(r=>({...r,inCurrentWindow:active.has(r.index)}));
}
const number=ms=>(ms/1000).toFixed(3).replace('.',',');
const stamp=ms=>`${Math.floor(ms/60000)}:${String(Math.round(ms/1000)%60).padStart(2,'0')}`;
let selected=null;
export function selectAverageChart(index){selected=Number.isInteger(index)&&index>=0&&index<averageChartDemo.length?index:null;}
export function averageChartCard({modal=false,durations=averageChartDemo,minDurationMs=0}={}){
  const rows=averageChartSeries(durations,{minDurationMs}),last=rows.at(-1),chosen=rows[selected??rows.length-1];
  const W=1000,H=380,L=64,R=28,T=16,B=46,plotW=W-L-R,plotH=H-T-B;
  const max=Math.max(20000,...rows.map(r=>r.ms),...rows.map(r=>r.average??0)),top=Math.ceil(max/5000)*5000;
  const x=i=>L+plotW*(i+.5)/rows.length,y=ms=>T+plotH*(1-ms/top),barW=Math.min(35,plotW/Math.max(1,rows.length)*.54);
  const ticks=Array.from({length:5},(_,i)=>top*i/4);
  const grid=ticks.map(ms=>`<path d="M${L} ${y(ms)}H${W-R}" class="ac-grid"/><text x="${L-12}" y="${y(ms)+5}" text-anchor="end">${stamp(ms)}</text>`).join('');
  const activeCount=rows.filter(r=>r.inCurrentWindow).length,firstActive=rows.findIndex(r=>r.inCurrentWindow),start=L+plotW*Math.max(0,firstActive)/rows.length;
  const band=activeCount?`<rect class="ac-active-band" x="${start}" y="${T}" width="${W-R-start}" height="${plotH}" rx="4"/><path class="ac-window-boundary" d="M${start} ${T}V${H-B}"/>`:'';
  const axis=`<div class="ac-fixed-axis" aria-hidden="true"><svg viewBox="0 0 64 380">${ticks.map(ms=>`<text x="52" y="${y(ms)+5}" text-anchor="end">${stamp(ms)}</text>`).join('')}</svg></div>`;
  const labelEvery=rows.length>30?20:3;
  const bars=rows.map(r=>`<rect class="ac-bar ${r.inCurrentWindow?'':'ac-past'} ${r.ms<1000?'ac-short':''} ${!r.included?'ac-excluded':''} ${r.index===(selected??rows.length-1)?'ac-selected':''}" x="${x(r.index)-barW/2}" y="${y(r.ms)}" width="${barW}" height="${Math.max(2,plotH*r.ms/top)}" rx="2"/><text class="ac-x-label" x="${x(r.index)}" y="${H-22}" text-anchor="middle">${r.index===0||r.index===rows.length-1||(r.index+1)%labelEvery===0?r.index+1:''}</text>`).join('');
  const line=rows.filter(r=>r.average!==null),path=line.map((r,i)=>`${i?'L':'M'}${x(r.index)} ${y(r.average)}`).join('');
  const points=line.map(r=>`<circle cx="${x(r.index)}" cy="${y(r.average)}" r="${r.index===(selected??rows.length-1)?6:4}" class="ac-point"/>`).join('');
  const actions=rows.map(r=>`<button data-action="average-chart-select-${r.index}" aria-label="Попытка ${r.index+1}: ${number(r.ms)} с, среднее ${r.average===null?'нет':number(r.average)+' с'}" aria-pressed="${r.index===(selected??rows.length-1)}" style="left:${100*(x(r.index)-plotW/rows.length*.5)/W}%;width:${100*plotW/rows.length/W}%"></button>`).join('');
  return `<section class="average-chart-card" aria-label="График среднего результата">
    <header class="ac-header"><div><h2>Средний результат</h2><p>Последние ${rows.length} попыток</p></div><strong><span aria-hidden="true">⌁</span> ${last?.average==null?'—':number(last.average)} <small>с</small></strong>${modal?'<button class="ac-close" data-action="close" aria-label="Закрыть график">×</button>':''}</header>
    <div class="ac-window-guide"><span>На графике: ${rows.length} попыток</span><strong>В расчёте — последние ${activeCount}</strong></div>
    <div class="ac-plot"><span class="ac-time">Время, мин:сек</span><div class="ac-chart-shell"><div class="ac-canvas"><svg viewBox="0 0 ${W} ${H}" role="img" aria-label="Бирюзовые столбики — попытки, серые — короче секунды, жёлтая линия — среднее"><defs><linearGradient id="ac-bars" x2="0" y2="1"><stop stop-color="#64fbf5"/><stop offset="1" stop-color="#00a8cd"/></linearGradient></defs>${band}${grid}<path d="M${L} ${T}V${H-B}H${W-R}" class="ac-axis"/>${bars}<path d="${path}" class="ac-line"/>${points}</svg><div class="ac-pick-columns">${actions}</div></div>${axis}</div><span class="ac-attempts">Попытки</span></div>
    <div class="ac-selection" aria-live="polite">Попытка ${chosen.index+1}: <b>${number(chosen.ms)} с</b><span>Среднее <b>${chosen.average==null?'—':number(chosen.average)+' с'}</b></span></div>
    <div class="ac-legend"><span><i class="ac-swatch"></i>Попытка ≥ 1 с</span><span><i class="ac-swatch ac-grey"></i>Короче 1 с</span><span><i class="ac-line-swatch"></i>Среднее</span></div>
    <p class="ac-footnote">Для текущего среднего — последние ${activeCount} подходящих попыток. Линия — среднее после каждой попытки.<br>${minDurationMs===0?'Короткие попытки тоже учитываются':`Порог: больше ${number(minDurationMs)} с`}</p>
  </section>`;
}
export function averageChartPage(){return `<div class="section-head"><h2><span class="index">G01</span>График среднего</h2><p>Живой компонент по референсу · демонстрационные данные</p></div><div class="ac-showcase">${averageChartCard()}<button class="neon-btn" data-action="average-chart-open">Открыть отдельным окном</button></div>`;}
export function addAverageChartButtons(root){
  if(selected===null)requestAnimationFrame(()=>root.querySelectorAll('.ac-canvas').forEach(el=>el.scrollLeft=el.scrollWidth));
  root.querySelectorAll('.rank-average-title .rank-info-area').forEach(host=>{
    if(host.querySelector('.rank-chart-button'))return;
    const button=document.createElement('button');button.className='rank-chart-button';button.dataset.action='average-chart-open';button.textContent='График';button.setAttribute('aria-label','Открыть график среднего');host.prepend(button);
  });
}

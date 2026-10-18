import { configEditor } from './config-editor.js?v=v1.0.61_20261006_213029_176';
const API = '../api/admin.php';
const KEY_STORE = 'untouch_admin_key';
const FILTERS = [
  ['all', 'Все'],
  ['today', 'Сегодня'],
  ['week', 'Неделя'],
  ['new_today', 'Новые сегодня'],
  ['new_week', 'Новые за неделю'],
  ['started', 'С /start'],
  ['played', 'Играли'],
  ['premium', 'Premium'],
  ['blocked', 'Заблокировали'],
];

const state = {
  filter: 'all',
  platform: 'telegram',
  mobileRows: new Map(),
  deleteCsrf: '',
  q: '',
  page: 1,
  view: 'config',
};

const $ = (id) => document.getElementById(id);

function fmtNum(n) {
  return new Intl.NumberFormat('ru-RU').format(Number(n) || 0);
}

function fmtWhen(ms) {
  const n = Number(ms) || 0;
  if (n < 1000) return '—';
  return new Intl.DateTimeFormat('ru-RU', {
    timeZone: 'Europe/Moscow',
    day: '2-digit',
    month: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
  }).format(new Date(n));
}

function esc(value) {
  return String(value ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

function storedKey() {
  try { return sessionStorage.getItem(KEY_STORE) || ''; } catch (_) { return ''; }
}

function rememberKey(key) {
  try {
    if (key) sessionStorage.setItem(KEY_STORE, key);
    else sessionStorage.removeItem(KEY_STORE);
  } catch (_) {}
}

async function api(action, extra = {}) {
  const isGet = ['status', 'stats', 'users', 'config_get', 'mobile_pace_get'].includes(action);
  const url = new URL(API, window.location.href);
  url.searchParams.set('action', action);
  if (isGet && extra.q) url.searchParams.set('q', extra.q);
  if (isGet && extra.filter) url.searchParams.set('filter', extra.filter);
  if (isGet && extra.platform) url.searchParams.set('platform', extra.platform);
  if (isGet && extra.page) url.searchParams.set('page', String(extra.page));
  const headers = { 'Content-Type': 'application/json' };
  const key = extra.key || storedKey();
  if (key) headers.Authorization = `Bearer ${key}`;
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 10000);
  let res, text;
  try {
  res = await fetch(url, {
    method: isGet ? 'GET' : 'POST',
    credentials: 'same-origin',
    headers,
    signal: controller.signal,
    body: isGet ? undefined : JSON.stringify({ action, ...extra }),
  });
  text = await res.text();
  } finally { clearTimeout(timeout); }
  let data = null;
  try { data = text ? JSON.parse(text) : null; } catch (_) {}
  if (!res.ok || !data || data.ok === false) {
    const hint = (data && data.error)
      || (text && text.replace(/<[^>]+>/g, ' ').replace(/\s+/g, ' ').trim().slice(0, 180))
      || `Ошибка запроса (${res.status})`;
    const err = new Error(hint);
    err.status = res.status;
    err.details = data;
    throw err;
  }
  return data;
}

function showLogin(errorText = '') {
  $('app').classList.add('hidden');
  $('login').classList.remove('hidden');
  const box = $('login-error');
  if (errorText) {
    box.hidden = false;
    box.textContent = errorText;
  } else {
    box.hidden = true;
  }
}

let paceSnapshot;
async function loadMobilePace(){
  const panel=$('mobile-pace-panel');if(!panel)return;
  try{
    paceSnapshot=await api('mobile_pace_get');
    panel.innerHTML=`<h2>Android: скорость врагов</h2><p>Базовые значения для Android86 и новее: старт каждого врага отличается до ±5%, ускорение до ±8%. Значения выбираются один раз на раунд. Шаг —1/10 размера героя. Новые настройки применятся после повторного открытия приложения; начатая игра не меняется.</p><form id="mobile-pace-form"><div class="cfg-fields"><div class="cfg-field"><label for="mobile-pace-speed">Стартовая скорость (шаг/с)</label><input id="mobile-pace-speed" name="speed" type="number" min="0.01" max="250" step="0.01" required value="${esc(paceSnapshot.config.startSpeedSteps)}"></div><div class="cfg-field"><label for="mobile-pace-acceleration">Ускорение (шаг/с за секунду)</label><input id="mobile-pace-acceleration" name="acceleration" type="number" min="0" max="50" step="0.01" required value="${esc(paceSnapshot.config.accelerationSteps)}"></div></div><div class="cfg-actions"><button type="submit">Сохранить скорость Android</button></div><p class="cfg-status" role="status" id="mobile-pace-status"></p></form>`;
    $('mobile-pace-form').onsubmit=async event=>{
      event.preventDefault();const form=event.target;const button=form.querySelector('button');button.disabled=true;
      try{paceSnapshot=await api('mobile_pace_save',{config:{startSpeedSteps:Number(form.elements.speed.value),accelerationSteps:Number(form.elements.acceleration.value)},revision:paceSnapshot.revision,csrf:paceSnapshot.csrf});$('mobile-pace-status').textContent='Сохранено. Откройте приложение заново, чтобы загрузить значения.';}
      catch(err){$('mobile-pace-status').textContent=err.message;}
      finally{button.disabled=false;}
    };
  }catch(err){panel.textContent=err.message;}
}

function showApp() {
  $('login').classList.add('hidden');
  $('app').classList.remove('hidden');
}

function setView(view) {
  state.view = ['ads', 'monetize', 'config'].includes(view) ? view : 'people';
  const people = $('view-people');
  const ads = $('view-ads');
  const monetize = $('view-monetize');
  const config = $('view-config');
  people?.classList.toggle('hidden', state.view !== 'people');
  ads?.classList.toggle('hidden', state.view !== 'ads');
  monetize?.classList.toggle('hidden', state.view !== 'monetize');
  config?.classList.toggle('hidden', state.view !== 'config');
  $('tabs')?.querySelectorAll('[data-view]').forEach((btn) => {
    btn.classList.toggle('on', btn.getAttribute('data-view') === state.view);
  });
  const title = $('page-title');
  const sub = $('page-sub');
  const reload = $('reload');
  if (state.view === 'config') {
    if (title) title.textContent = 'Настройки игры';
    if (sub) sub.textContent = 'Один конфиг для Mini App и PHP · экспорт параметров для APK';
    if (reload) reload.hidden = true;
    if (!$('app').classList.contains('hidden')) {
      if (!$('shared-config-editor')) config.innerHTML = '<section id="mobile-pace-panel" class="panel"></section><div id="shared-config-editor"></div>';
      loadMobilePace();
      configEditor.mount($('shared-config-editor'), api);
    }
  } else if (state.view === 'ads') {
    if (title) title.textContent = 'Как рекламировать';
    if (sub) sub.textContent = 'Бесплатные площадки, платная закупка и реклама внутри игры';
    if (reload) reload.hidden = true;
  } else if (state.view === 'monetize') {
    if (title) title.textContent = 'Монетизация';
    if (sub) sub.textContent = 'Баланс экономики, расчёт кассы и JSON для Remote Config';
    if (reload) reload.hidden = true;
    window.UntouchMonetize?.mount(monetize);
  } else {
    if (title) title.textContent = 'Кто пишет боту';
    if (sub) sub.textContent = 'Дни по Москве (UTC+3)';
    if (reload) reload.hidden = false;
  }
}

function renderCards(stats) {
  const items = [
    ['Всего написали', stats.total, 'accent'],
    ['Активны сегодня', stats.activeToday, 'cyan'],
    ['Новые сегодня', stats.newToday, 'accent'],
    ['Активны за неделю', stats.activeWeek, ''],
    ['Новые за неделю', stats.newWeek, ''],
    ['За 30 дней', stats.activeMonth, ''],
    ['Сообщения сегодня', stats.messagesToday, ''],
    ['/start сегодня', stats.startsToday, ''],
    ['Играли', stats.players, 'cyan'],
    ['По приглашению', stats.referrals, ''],
    ['Купили Stars', stats.paid, 'warn'],
    ['Заблокировали бота', stats.blocked, ''],
  ];
  $('cards').innerHTML = items.map(([label, value, tone]) => `
    <article class="card ${tone}">
      <p class="label">${esc(label)}</p>
      <p class="value">${fmtNum(value)}</p>
    </article>
  `).join('');
}

function renderChart(chart) {
  const rows = Array.isArray(chart) ? chart : [];
  const max = Math.max(1, ...rows.map((r) => Math.max(r.active || 0, r.newUsers || 0)));
  $('chart').innerHTML = rows.map((r) => {
    const activeH = Math.round(((r.active || 0) / max) * 110);
    const newH = Math.round(((r.newUsers || 0) / max) * 110);
    const label = String(r.day || '').slice(8);
    return `
      <div class="bar" title="${esc(r.day)}: активны ${r.active || 0}, новые ${r.newUsers || 0}">
        <span class="stack active" style="height:${activeH}px"></span>
        <span class="stack fresh" style="height:${newH}px"></span>
        <span class="day">${esc(label)}</span>
      </div>
    `;
  }).join('');
}

function renderFilters() {
  $('filters').innerHTML = FILTERS.map(([id, label]) => (
    `<button type="button" data-filter="${id}" class="${state.filter === id ? 'on' : ''}">${label}</button>`
  )).join('');
}

function displayName(row) {
  if (row.platform === 'android') return row.nickname || row.userId;
  const full = [row.firstName, row.lastName].filter(Boolean).join(' ').trim();
  return full || (row.username ? `@${row.username}` : 'Без имени');
}

function renderRows(data) {
  state.mobileRows = new Map(data.items.filter(r => r.platform === 'android').map(r => [r.userId, r]));
  state.deleteCsrf = data.deleteCsrf || '';
  $('list-meta').textContent = `${fmtNum(data.total)} человек`;
  if (!data.items.length) {
    $('rows').innerHTML = '<tr><td colspan="8" class="empty">Пока никого. Список начнёт расти, когда люди напишут боту после заливки.</td></tr>';
    $('pager').innerHTML = '';
    return;
  }
  $('rows').innerHTML = data.items.map((row) => {
    const tags = [];
    if (row.played) tags.push('<span class="tag ok">играл</span>');
    if (row.invitedBy) tags.push('<span class="tag">реф</span>');
    if (row.isPremium) tags.push('<span class="tag warn">Premium</span>');
    if (row.blocked) tags.push('<span class="tag bad">блок</span>');
    const uname = row.platform === 'android' ? (row.googleLinked ? [row.googleName, row.googleEmail || 'Google ID: ' + row.googleSubject].filter(Boolean).join(' · ') : 'Google не подключён') : (row.username ? `@${row.username}` : '');
    return `
      <tr>
        <td>
          <span class="name">${esc(displayName(row))}</span>
          <span class="uname">${esc(uname)}</span>
          <div class="tags">${tags.join('')}</div>
        </td>
        <td>${row.username
          ? `<a href="https://t.me/${esc(row.username)}" target="_blank" rel="noreferrer">${esc(row.userId)}</a>`
          : esc(row.userId)}</td>
        <td>${fmtWhen(row.firstSeenAt)}</td>
        <td>${fmtWhen(row.lastSeenAt)}</td>
        <td>${fmtNum(row.messageCount)}</td>
        <td>${fmtNum(row.startCount)}</td>
        <td>${esc(row.lastKind || '—')}</td>
        <td class="muted">${row.platform === 'android' ? `<button type="button" class="ghost" data-delete-mobile="${esc(row.userId)}">Удалить профиль</button>` : esc(row.lastText || '—')}</td>
      </tr>
    `;
  }).join('');

  const prev = state.page > 1
    ? `<button type="button" class="ghost" data-page="${state.page - 1}">Назад</button>`
    : '';
  const next = state.page < data.pages
    ? `<button type="button" class="ghost" data-page="${state.page + 1}">Дальше</button>`
    : '';
  $('pager').innerHTML = `${prev}<span class="muted">стр. ${data.page} из ${data.pages}</span>${next}`;
}

async function loadAll() {
  const android=state.platform==='android';
  $('cards').classList.toggle('hidden',android);
  $('chart').closest('section').classList.toggle('hidden',android);
  if(android){
    $('page-title').textContent='Игроки Android';
    $('page-sub').textContent='Игровые ники, Google и ID профилей';
    renderRows(await api('users',{q:state.q,filter:state.filter,page:state.page,platform:state.platform}));
    return;
  }
  $('page-title').textContent='Кто пишет боту';
  $('page-sub').textContent='Дни по Москве (UTC+3)';
  const [stats, users] = await Promise.all([
    api('stats'),
    api('users', { q: state.q, filter: state.filter, page: state.page, platform: state.platform }),
  ]);
  renderCards(stats.stats || {});
  renderChart(stats.chart || []);
  renderRows(users);
}

async function boot() {
  renderFilters();
  setView('config');
  try {
    const status = await api('status');
    if (!status.configured) {
      showLogin('Добавьте admin_key в api/bot_config.php на хостинге и залейте файл заново.');
      return;
    }
    if (!status.authed) {
      showLogin();
      return;
    }
    showApp();
    setView('config');
  } catch (err) {
    showLogin(err.message || 'Не удалось открыть админку');
  }
}

$('login-form').addEventListener('submit', async (e) => {
  e.preventDefault();
  const key = $('admin-key').value.trim();
  try {
    await api('login', { key });
    rememberKey(key);
    $('admin-key').value = '';
    showApp();
    setView('config');
  } catch (err) {
    showLogin(err.message || 'Неверный ключ');
  }
});

$('logout').addEventListener('click', async () => {
  try { await api('logout'); } catch (_) {}
  rememberKey('');
  showLogin();
});

$('reload').addEventListener('click', () => {
  loadAll().catch((err) => {
    if (err.status === 401) showLogin('Сессия истекла');
  });
});

$('tabs')?.addEventListener('click', (e) => {
  const btn = e.target.closest('[data-view]');
  if (!btn) return;
  setView(btn.getAttribute('data-view'));
  if (state.view === 'people') loadAll().catch(err => {
    if (err.status === 401) showLogin('Сессия истекла');
    else $('list-meta').textContent = err.message;
  });
});

$('filters').addEventListener('click', (e) => {
  const btn = e.target.closest('[data-filter]');
  if (!btn) return;
  state.filter = btn.getAttribute('data-filter');
  state.page = 1;
  renderFilters();
  loadAll().catch((err) => {
    if (err.status === 401) showLogin('Сессия истекла');
  });
});

$('pager').addEventListener('click', (e) => {
  const btn = e.target.closest('[data-page]');
  if (!btn) return;
  state.page = Number(btn.getAttribute('data-page')) || 1;
  loadAll().catch((err) => {
    if (err.status === 401) showLogin('Сессия истекла');
  });
});

let searchTimer = 0;
$('search').addEventListener('input', () => {
  clearTimeout(searchTimer);
  searchTimer = setTimeout(() => {
    state.q = $('search').value.trim();
    state.page = 1;
    loadAll().catch((err) => {
      if (err.status === 401) showLogin('Сессия истекла');
    });
  }, 250);
});

$('users-platform').addEventListener('change', async (event) => {
  state.platform=event.target.value;state.page=1;state.filter='all';renderFilters();
  $('search').placeholder=state.platform==='android'?'Игровой ник, Google или ID':'Имя, @username или ID';
  try {await loadAll();} catch(err) {$('list-meta').textContent=err.message;}
});
$('rows').addEventListener('click', async (event) => {
  const button=event.target.closest('[data-delete-mobile]');if(!button)return;
  const row=state.mobileRows.get(button.dataset.deleteMobile);if(!row)return;
  const confirmedId=window.prompt(`Удалить профиль ${row.nickname} (${row.googleEmail || row.googleName || 'Гость'})? Прогресс, кристаллы и результаты будут удалены. Введите ${row.userId} для подтверждения.`);
  if(confirmedId!==row.userId)return;
  button.disabled=true;
  try {await api('delete_mobile',{userId:row.userId,confirmedId,fingerprint:row.deleteFingerprint,csrf:state.deleteCsrf});await loadAll();}
  catch(err){$('list-meta').textContent=err.message;button.disabled=false;}
});
boot();

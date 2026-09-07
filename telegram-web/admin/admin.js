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
  q: '',
  page: 1,
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
  const isGet = action === 'status' || action === 'stats' || action === 'users';
  const url = new URL(API, window.location.href);
  url.searchParams.set('action', action);
  if (isGet && extra.q) url.searchParams.set('q', extra.q);
  if (isGet && extra.filter) url.searchParams.set('filter', extra.filter);
  if (isGet && extra.page) url.searchParams.set('page', String(extra.page));
  const headers = { 'Content-Type': 'application/json' };
  const key = extra.key || storedKey();
  if (key) headers.Authorization = `Bearer ${key}`;
  const res = await fetch(url, {
    method: isGet ? 'GET' : 'POST',
    credentials: 'same-origin',
    headers,
    body: isGet ? undefined : JSON.stringify({ action, ...extra }),
  });
  const text = await res.text();
  let data = null;
  try { data = text ? JSON.parse(text) : null; } catch (_) {}
  if (!res.ok || !data || data.ok === false) {
    const hint = (data && data.error)
      || (text && text.replace(/<[^>]+>/g, ' ').replace(/\s+/g, ' ').trim().slice(0, 180))
      || `Ошибка запроса (${res.status})`;
    const err = new Error(hint);
    err.status = res.status;
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

function showApp() {
  $('login').classList.add('hidden');
  $('app').classList.remove('hidden');
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
  const full = [row.firstName, row.lastName].filter(Boolean).join(' ').trim();
  return full || (row.username ? `@${row.username}` : 'Без имени');
}

function renderRows(data) {
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
    const uname = row.username ? `@${row.username}` : '';
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
        <td class="muted">${esc(row.lastText || '—')}</td>
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
  const [stats, users] = await Promise.all([
    api('stats'),
    api('users', { q: state.q, filter: state.filter, page: state.page }),
  ]);
  renderCards(stats.stats || {});
  renderChart(stats.chart || []);
  renderRows(users);
}

async function boot() {
  renderFilters();
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
    await loadAll();
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
    await loadAll();
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

boot();

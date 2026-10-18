import { cloneConfig, valueAt, setValue, defaultValue, validateConfig, exportConfig } from './config-model.js?v=v1.0.22_20261003_233329_134';

const DRAFT_KEY = 'untouch_admin_config_draft_v1';
const esc = value => String(value ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const labels = { '': 'Без значения', warning: 'Предупреждение', success: 'Успех', error: 'Ошибка', deal: 'Выгодно', best: 'Лучший выбор', max: 'Максимум', ru: 'Русский', en: 'Английский' };

export class ConfigEditor {
  constructor() {
    this.config = null;
    this.saved = null;
    this.schema = null;
    this.scope = 'all';
    this.busy = false;
    this.errors = {};
    this.message = '';
    this.draftTimer = null;
    window.addEventListener('beforeunload', event => {
      if (!this.dirty) return;
      event.preventDefault();
      event.returnValue = '';
    });
  }
  get dirty() { return Boolean(this.config && this.saved && JSON.stringify(this.config) !== JSON.stringify(this.saved)); }
  async loadSchema() {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 10000);
    try {
      const res = await fetch('config-schema.json', { cache: 'no-cache', signal: controller.signal });
      if (!res.ok) throw new Error('Не удалось загрузить схему');
      return await res.json();
    } finally { clearTimeout(timeout); }
  }
  async mount(root, api, reload = false) {
    this.root = root;
    this.api = api;
    if (this.config && !reload) return;
    if (this.loading) return this.loading;
    this.loading = this.load().finally(() => { this.loading = null; });
    return this.loading;
  }
  async load() {
    this.busy = true;
    if (!this.config) this.root.innerHTML = '<section class="panel"><p role="status">Загружаем настройки…</p></section>';
    this.update();
    try {
      const [snapshot, schema] = await Promise.all([
        this.api('config_get'),
        this.loadSchema(),
      ]);
      this.schema = schema;
      this.config = cloneConfig(snapshot.config);
      this.saved = cloneConfig(snapshot.config);
      this.revision = snapshot.revision;
      this.csrf = snapshot.csrf;
      this.updatedAt = snapshot.updatedAt;
      this.source = snapshot.source;
      this.message = 'Настройки загружены с сервера.';
      this.render();
    } catch (err) {
      this.message = err.message;
      if (!this.config) {
        this.root.innerHTML = `<section class="panel"><p class="error" role="alert">${esc(err.message)}</p><button type="button" data-retry>Повторить</button></section>`;
        this.root.querySelector('[data-retry]').onclick = () => this.mount(this.root, this.api, true);
      }
    } finally { this.busy = false; this.update(); }
  }
  control(path, rule, value) {
    const id = `cfg-${path.replace(/\./g, '-')}`;
    const attrs = `id="${id}" data-path="${esc(path)}" aria-describedby="${id}-hint ${id}-error"`;
    let input;
    if (rule.type === 'boolean') {
      input = `<label class="cfg-toggle"><input ${attrs} type="checkbox" ${value ? 'checked' : ''}><span>${value ? 'Включено' : 'Выключено'}</span></label>`;
    } else if (rule.choices) {
      input = `<select ${attrs}>${rule.choices.map(choice => `<option value="${esc(choice)}" ${choice === (value ?? '') ? 'selected' : ''}>${esc(labels[choice] ?? choice)}</option>`).join('')}</select>`;
    } else if (rule.type === 'number') {
      input = `<input ${attrs} type="number" min="${rule.min}" max="${rule.max}" step="${rule.step ?? 1}" value="${esc(value)}" inputmode="${rule.step === 1 ? 'numeric' : 'decimal'}">`;
    } else {
      input = `<input ${attrs} type="text" value="${esc(value)}" ${rule.format === 'color' ? 'placeholder="#172028"' : ''} maxlength="${rule.maxLength ?? 128}" spellcheck="false">`;
      if (rule.format === 'color') input = `<div class="cfg-color"><input type="color" data-color-path="${esc(path)}" aria-label="Выбрать цвет: ${esc(rule.label)}" value="${/^#[0-9a-f]{6}$/i.test(value ?? '') ? value : '#172028'}">${input}</div>`;
    }
    return `<div class="cfg-field"><label for="${id}">${esc(rule.label)}</label>${input}<small id="${id}-hint">${esc(rule.description || (rule.type === 'number' ? `${rule.min}–${rule.max}` : path))}</small><small class="cfg-key">${esc(path)}</small><span class="cfg-error" data-error="${esc(path)}" id="${id}-error"></span></div>`;
  }
  arrayHtml(field) {
    const items = valueAt(this.config, field.path) || [];
    return `<section class="cfg-array" data-array="${field.path}"><div class="cfg-array-head"><div><h3>${esc(field.label)}</h3><p>${esc(field.description)}</p><code>${esc(field.path)}</code></div><button class="ghost" type="button" data-add="${field.path}" ${items.length >= field.maxItems ? 'disabled' : ''}>+ Добавить</button></div><span class="cfg-error" data-error="${field.path}"></span><div class="cfg-array-items ${field.items.type === 'object' ? '' : 'cfg-scalar-list'}">${items.map((item, i) => `<div class="cfg-array-row"><div class="cfg-row-head"><strong>${field.path.endsWith('dailyRewardTokens') ? 'День' : 'Строка'} ${i + 1}</strong><button type="button" class="ghost" data-remove="${field.path}" data-index="${i}" ${items.length <= field.minItems ? 'disabled' : ''} aria-label="Удалить строку ${i + 1}">Удалить</button></div><div class="cfg-row-fields">${field.items.type === 'object' ? Object.entries(field.items.fields).map(([key, rule]) => this.control(`${field.path}.${i}.${key}`, rule, item[key])).join('') : this.control(`${field.path}.${i}`, field.items, item)}</div></div>`).join('')}</div></section>`;
  }
  render() {
    const opened = new Set([...this.root.querySelectorAll('details[open][data-group]')].map(node => node.dataset.group));
    this.root.innerHTML = `
      <section class="panel cfg-toolbar">
        <div><h2>Настройки игры</h2><p class="sub">Изменения слева → JSON справа → сохранение на сервер.</p></div>
        <div class="cfg-actions"><button type="button" data-save>Сохранить и опубликовать</button><button type="button" class="ghost" data-discard>Сбросить изменения</button><button type="button" class="ghost" data-reload>Загрузить с сервера</button></div>
        <div class="cfg-state"><span data-dirty></span><span data-version></span></div>
        <p class="cfg-status" data-message role="status" aria-live="polite"></p>
      </section>
      <nav class="cfg-nav" aria-label="Блоки настроек">${this.schema.groups.map(g => `<button type="button" class="ghost" data-jump="${g.id}">${esc(g.title)}</button>`).join('')}</nav>
      <div class="cfg-layout">
        <div class="cfg-form">${this.schema.groups.map((g, i) => `<details class="panel cfg-group" data-group="${g.id}" id="cfg-group-${g.id}" ${opened.has(g.id) || (!opened.size && i === 0) ? 'open' : ''}><summary><span>${esc(g.title)}</span><span class="cfg-group-count">${g.fields.length} параметров</span></summary><p class="cfg-description">${esc(g.description)}</p><div class="cfg-fields">${g.fields.filter(f => f.type !== 'array').map(f => this.control(f.path, f, valueAt(this.config, f.path))).join('')}</div>${g.fields.filter(f => f.type === 'array').map(f => this.arrayHtml(f)).join('')}</details>`).join('')}
        </div>
        <aside class="panel cfg-preview"><h2>JSON текущего черновика</h2><p class="sub">Превью обновляется при каждом изменении. Для APK выберите имя параметра Remote Config.</p><label for="cfg-export-scope">Что экспортировать</label><select id="cfg-export-scope">${['all', ...this.schema.remoteConfigKeys].map(key => `<option value="${key}" ${this.scope === key ? 'selected' : ''}>${key === 'all' ? 'Полный JSON для Telegram' : `Remote Config → ${key}`}</option>`).join('')}</select><p class="cfg-export-hint" data-export-hint></p><textarea id="cfg-json" readonly spellcheck="false" aria-label="JSON конфигурации"></textarea><div class="cfg-actions"><button type="button" data-copy>Копировать</button><button type="button" class="ghost" data-download>Скачать JSON</button></div><p class="cfg-validity" data-validity></p><details class="cfg-import"><summary>Импорт JSON</summary><p class="sub">Полный JSON или значение выбранного параметра. Импорт меняет только черновик.</p><textarea id="cfg-import-json" spellcheck="false" aria-label="JSON для импорта" placeholder="Вставьте JSON"></textarea><button type="button" class="ghost" data-import>Применить к черновику</button></details><button class="ghost cfg-draft" type="button" data-restore-draft hidden>Восстановить локальный черновик</button><p class="sub">Сохранённое применяется при следующем открытии игры. Уже начатая попытка сохраняет свои правила.</p></aside>
      </div>`;
    this.root.oninput = event => this.onInput(event);
    this.root.onchange = event => {
      if (event.target.id === 'cfg-export-scope') { this.scope = event.target.value; this.update(); }
    };
    this.root.onclick = event => this.onClick(event);
    this.update();
  }
  findRule(path) {
    for (const group of this.schema.groups) for (const field of group.fields) {
      if (field.path === path) return field;
      if (field.type === 'array' && path.startsWith(field.path + '.')) {
        const parts = path.slice(field.path.length + 1).split('.');
        return field.items.type === 'object' ? field.items.fields[parts[1]] : field.items;
      }
    }
    return null;
  }
  onInput(event) {
    const el = event.target;
    const path = el.dataset.path || el.dataset.colorPath;
    if (!path || this.busy) return;
    const rule = this.findRule(path);
    if (!rule) return;
    let value = el.type === 'checkbox' ? el.checked : el.value;
    if (rule.type === 'number') value = value === '' ? null : Number(value);
    if (rule.nullable && value === '') value = null;
    setValue(this.config, path, value);
    if (el.dataset.colorPath) this.root.querySelector(`[data-path="${path}"]`).value = value;
    if (rule.format === 'color' && /^#[0-9a-f]{6}$/i.test(value ?? '')) this.root.querySelector(`[data-color-path="${path}"]`).value = value;
    if (el.type === 'checkbox') el.nextElementSibling.textContent = value ? 'Включено' : 'Выключено';
    this.message = '';
    this.rememberDraft();
    this.update();
  }
  rememberDraft() {
    clearTimeout(this.draftTimer);
    this.draftTimer = setTimeout(() => {
      try { localStorage.setItem(DRAFT_KEY, JSON.stringify({ config: this.config, revision: this.revision, updatedAt: Date.now() })); } catch (_) {}
    }, 300);
  }
  update() {
    if (!this.config || !this.schema || !this.root.querySelector('[data-save]')) return;
    this.errors = validateConfig(this.config, this.schema);
    const entries = Object.entries(this.errors);
    this.root.querySelectorAll('[data-error]').forEach(el => { el.textContent = this.errors[el.dataset.error] || ''; });
    this.root.querySelectorAll('[data-path]').forEach(el => { el.setAttribute('aria-invalid', this.errors[el.dataset.path] ? 'true' : 'false'); el.disabled = this.busy; });
    this.root.querySelectorAll('[data-color-path], [data-add], [data-remove]').forEach(el => {
      if (el.dataset.colorPath) el.disabled = this.busy;
      else {
        const field = this.schema.groups.flatMap(g => g.fields).find(f => f.path === (el.dataset.add || el.dataset.remove));
        const length = valueAt(this.config, field.path).length;
        el.disabled = this.busy || (el.dataset.add ? length >= field.maxItems : length <= field.minItems);
      }
    });
    const save = this.root.querySelector('[data-save]');
    save.disabled = this.busy || !this.dirty || entries.length > 0;
    save.textContent = this.busy ? 'Подождите…' : 'Сохранить и опубликовать';
    this.root.querySelector('[data-discard]').disabled = this.busy || !this.dirty;
    this.root.querySelector('[data-reload]').disabled = this.busy;
    this.root.querySelector('[data-dirty]').textContent = this.dirty ? 'Есть несохранённые изменения' : 'Черновик совпадает с сервером';
    this.root.querySelector('[data-version]').textContent = this.updatedAt ? `Сохранено ${new Date(this.updatedAt).toLocaleString('ru-RU')}` : 'Начальная конфигурация из сборки';
    this.root.querySelector('[data-message]').textContent = this.message;
    this.root.querySelector('[data-validity]').textContent = entries.length ? `Исправьте ${entries.length} ошибок. Первая: ${entries[0][0]} — ${entries[0][1]}` : 'JSON проверен. Дополнительные поля при импорте сохраняются.';
    this.root.querySelector('[data-validity]').classList.toggle('error', entries.length > 0);
    this.root.querySelector('#cfg-json').value = exportConfig(this.config, this.scope, this.schema);
    this.root.querySelector('[data-export-hint]').textContent = this.scope === 'all' ? 'Полная конфигурация, которую публикует админка.' : `В Firebase создайте параметр «${this.scope}» и вставьте это значение. Автоматическая отправка в Firebase не выполняется.`;
    try {
      const draft = JSON.parse(localStorage.getItem(DRAFT_KEY) || 'null');
      this.root.querySelector('[data-restore-draft]').hidden = !draft?.config || JSON.stringify(draft.config) === JSON.stringify(this.config);
      this.root.querySelector('[data-restore-draft]').textContent = draft?.revision !== this.revision ? 'Скачать черновик предыдущей версии' : 'Восстановить локальный черновик';
    } catch (_) { this.root.querySelector('[data-restore-draft]').hidden = true; }
  }
  async save() {
    if (this.busy || !this.dirty || Object.keys(this.errors).length) return;
    this.busy = true;
    this.message = '';
    this.update();
    try {
      const snapshot = await this.api('config_save', { config: cloneConfig(this.config), revision: this.revision, csrf: this.csrf });
      this.config = cloneConfig(snapshot.config);
      this.saved = cloneConfig(snapshot.config);
      this.revision = snapshot.revision;
      this.updatedAt = snapshot.updatedAt;
      clearTimeout(this.draftTimer);
      try { localStorage.removeItem(DRAFT_KEY); } catch (_) {}
      this.message = 'Сохранено и опубликовано. Новые открытия игры используют эти настройки.';
    } catch (err) {
      this.message = err.message;
      if (err.details?.errors) {
        this.message += ' ' + Object.entries(err.details.errors).map(([p, e]) => `${p}: ${e}`).join('; ');
      }
    } finally { this.busy = false; this.update(); }
  }
  importJson(raw) {
    let next = cloneConfig(this.config);
    if (this.scope === 'forceLocale') next.forceLocale = raw.trim();
    else {
      const parsed = JSON.parse(raw);
      if (this.scope === 'all') {
        if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) throw new Error('Нужен полный JSON-объект');
        next = cloneConfig(parsed);
      } else next[this.scope] = parsed;
    }
    const errors = validateConfig(next, this.schema);
    if (Object.keys(errors).length) throw new Error('Импорт отклонён: ' + Object.entries(errors).slice(0, 4).map(([p, e]) => `${p}: ${e}`).join('; '));
    this.config = next;
    this.rememberDraft();
    this.message = 'JSON импортирован в черновик. Для публикации нажмите «Сохранить». ';
    this.render();
  }
  async onClick(event) {
    const button = event.target.closest('button');
    if (!button || !this.root.contains(button) || button.disabled || this.busy) return;
    try {
      if (button.hasAttribute('data-save')) return await this.save();
      if (button.hasAttribute('data-reload')) {
        clearTimeout(this.draftTimer);
        if (this.dirty) {
          try { localStorage.setItem(DRAFT_KEY, JSON.stringify({ config: this.config, revision: this.revision, updatedAt: Date.now() })); } catch (_) {}
        }
        return await this.mount(this.root, this.api, true);
      }
      if (button.hasAttribute('data-discard')) { this.config = cloneConfig(this.saved); this.message = 'Изменения сброшены к загруженной версии.'; clearTimeout(this.draftTimer); try { localStorage.removeItem(DRAFT_KEY); } catch (_) {} this.render(); }
      if (button.dataset.jump) { const group = this.root.querySelector(`[data-group="${button.dataset.jump}"]`); group.open = true; group.scrollIntoView({ behavior: 'smooth', block: 'start' }); }
      if (button.dataset.add || button.dataset.remove) {
        const path = button.dataset.add || button.dataset.remove;
        const field = this.findRule(path);
        const items = valueAt(this.config, path);
        if (button.dataset.add) items.push(defaultValue(field.items));
        else items.splice(Number(button.dataset.index), 1);
        this.message = '';
        this.rememberDraft();
        this.render();
      }
      if (button.hasAttribute('data-copy')) {
        const output = this.root.querySelector('#cfg-json');
        try { await navigator.clipboard.writeText(output.value); this.message = 'JSON скопирован.'; }
        catch (_) { output.focus(); output.select(); this.message = 'JSON выделен. Нажмите Ctrl+C или «Копировать» в меню устройства.'; }
      }
      if (button.hasAttribute('data-download')) {
        const text = exportConfig(this.config, this.scope, this.schema);
        const plain = this.scope === 'forceLocale';
        const url = URL.createObjectURL(new Blob([text], { type: plain ? 'text/plain' : 'application/json' }));
        const a = document.createElement('a');
        a.href = url;
        a.download = this.scope === 'all' ? 'gameplay-config.json' : `${this.scope}.${plain ? 'txt' : 'json'}`;
        a.click();
        setTimeout(() => URL.revokeObjectURL(url), 1000);
      }
      if (button.hasAttribute('data-import')) this.importJson(this.root.querySelector('#cfg-import-json').value);
      if (button.hasAttribute('data-restore-draft')) {
        const draft = JSON.parse(localStorage.getItem(DRAFT_KEY) || 'null');
        if (draft?.revision !== this.revision) {
          const url = URL.createObjectURL(new Blob([JSON.stringify(draft.config, null, 2)], { type: 'application/json' }));
          const a = document.createElement('a'); a.href = url; a.download = 'gameplay-config-draft.json'; a.click();
          setTimeout(() => URL.revokeObjectURL(url), 1000);
          this.message = 'Старый черновик скачан. Можно проверить его и импортировать нужный блок в актуальную версию.';
          this.update();
          return;
        }
        this.config = cloneConfig(draft.config);
        this.message = 'Локальный черновик восстановлен. На сервер пока не сохранён.';
        this.render();
      }
    } catch (err) { this.message = err.message; }
    this.update();
  }
}

export const configEditor = new ConfigEditor();

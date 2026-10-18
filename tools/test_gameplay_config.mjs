import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import path from 'node:path';
import { pathToFileURL } from 'node:url';
import http from 'node:http';

const root = path.resolve(import.meta.dirname, '..');
const web = process.env.UNTOUCH_WEB_ROOT || path.join(root, 'telegram-web');
const defaults = JSON.parse(await fs.readFile(path.join(web, 'config/gameplay-config.json'), 'utf8'));
const schema = JSON.parse(await fs.readFile(path.join(web, 'admin/config-schema.json'), 'utf8'));
const model = await import('data:text/javascript;base64,' + Buffer.from(await fs.readFile(path.join(web, 'admin/config-model.js'))).toString('base64'));
assert.deepEqual(model.validateConfig(defaults, schema), {});
const legacyJump = model.cloneConfig(defaults);
delete legacyJump.game.jumpCooldownSec;
assert.deepEqual(model.validateConfig(legacyJump, schema), {}, 'Existing published configs must remain valid');
const fastJump = model.cloneConfig(defaults);
fastJump.game.jumpCooldownSec = 1.9;
assert.ok(model.validateConfig(fastJump, schema)['game.jumpCooldownSec'], 'Jump cooldown must be at least two seconds');
for (const key of schema.remoteConfigKeys.filter(k => k !== 'forceLocale')) assert.deepEqual(JSON.parse(model.exportConfig(defaults, key, schema)), defaults[key]);
assert.equal(model.exportConfig(defaults, 'forceLocale', schema), '');
const bad = model.cloneConfig(defaults);
bad.enemies.speedMax = bad.enemies.speedMin - 1;
assert.ok(Object.keys(model.validateConfig(bad, schema)).length);
const duplicate = model.cloneConfig(defaults);
duplicate.economy.starsShop.packs[1].id = duplicate.economy.starsShop.packs[0].id;
assert.ok(Object.keys(model.validateConfig(duplicate, schema)).some(k => k.endsWith('.id')));
const scalarPaths = new Set(schema.groups.flatMap(g => g.fields.map(f => f.path)));
function covered(value, prefix = '') {
  if (scalarPaths.has(prefix)) return;
  if (value && typeof value === 'object' && !Array.isArray(value)) for (const [k, v] of Object.entries(value)) covered(v, prefix ? `${prefix}.${k}` : k);
  else assert.fail(`Missing schema field: ${prefix}`);
}
covered(defaults);
const storage = new Map();
globalThis.localStorage = { getItem: k => storage.get(k) ?? null, setItem: (k, v) => storage.set(k, v) };
const loader = await import('data:text/javascript;base64,' + Buffer.from(await fs.readFile(path.join(web, 'js/remote-config.js'))).toString('base64'));
globalThis.fetch = async url => { assert.equal(url, 'api/config.php'); return { ok: true, json: async () => ({ ok: true, config: defaults, revision: 'test' }) }; };
assert.deepEqual(await new loader.RemoteConfigService().loadConfig(), defaults);
globalThis.fetch = async () => { throw new Error('offline'); };
assert.deepEqual(await new loader.RemoteConfigService().loadConfig(), defaults);
storage.clear();
globalThis.fetch = async url => { if (url === 'api/config.php') throw new Error('offline'); assert.equal(url, 'config/gameplay-config.json'); return { ok: true, json: async () => defaults }; };
assert.deepEqual(await new loader.RemoteConfigService().loadConfig(), defaults);
console.log('PASS: schema coverage, validation, APK exports, hosting/cache/default fallback');

if (!process.env.UNTOUCH_PHP_MODULES) process.exit(0);
const modules = process.env.UNTOUCH_PHP_MODULES;
const { PHP, PHPRequestHandler } = await import(pathToFileURL(path.join(modules, '@php-wasm/universal/index.js')));
const { loadNodeRuntime } = await import(pathToFileURL(path.join(modules, '@php-wasm/node/index.js')));
const php = new PHP(await loadNodeRuntime('8.3', { emscriptenOptions: { processId: 1 } }));
async function copy(dir, target) {
  php.mkdirTree(target);
  for (const entry of await fs.readdir(dir, { withFileTypes: true })) {
    if (entry.name === 'bot_config.php' || entry.name === 'config-data') continue;
    const src = path.join(dir, entry.name), dest = `${target}/${entry.name}`;
    if (entry.isDirectory()) await copy(src, dest);
    else php.writeFile(dest, await fs.readFile(src));
  }
}
await copy(web, '/www');
const syntax = await php.run({ code: `<?php
$count = 0;
foreach (new RecursiveIteratorIterator(new RecursiveDirectoryIterator('/www/api')) as $file) {
    if ($file->getExtension() === 'php') { token_get_all(file_get_contents($file->getPathname()), TOKEN_PARSE); $count++; }
}
echo $count;` });
assert.ok(Number(syntax.text) > 10, syntax.text);
console.log(`PASS: PHP syntax (${syntax.text} files)`);
php.mkdirTree('/www/api/config-data');
php.writeFile('/www/api/bot_config.php', "<?php return ['admin_key'=>'local-test-only', 'webhook_secret'=>'test-webhook-secret'];");
const handler = new PHPRequestHandler({ php, documentRoot: '/www', absoluteUrl: 'http://127.0.0.1', cookieStore: false });
const auth = { Authorization: 'Bearer local-test-only' };
const legacyConfig = model.cloneConfig(defaults);
delete legacyConfig.economy.energy;
for (const pack of legacyConfig.economy.starsShop.packs) delete pack.energy;
php.writeFile('/www/api/config-data/published.json', JSON.stringify({config:legacyConfig,revision:'legacy-before-energy'}));
const upgradedCache = await handler.request({url:'/api/config.php',method:'GET',headers:{'If-None-Match':'"legacy-before-energy"'}});
assert.equal(upgradedCache.httpStatusCode,200);
assert.deepEqual(JSON.parse(upgradedCache.text).config,defaults);
assert.notEqual(JSON.parse(upgradedCache.text).revision,'legacy-before-energy');
php.unlink('/www/api/config-data/published.json');
for (const update of [{ pre_checkout_query: { id: 'test' } }, { message: { from: { id: 42 }, successful_payment: { invoice_payload: 'test' } } }]) {
  const forged = await handler.request({ url: '/api/telegram_webhook.php', method: 'POST', headers: { 'Content-Type': 'application/json' }, body: Buffer.from(JSON.stringify(update)) });
  assert.equal(forged.httpStatusCode, 403);
  const response = await handler.request({ url: '/api/telegram_webhook.php', method: 'POST', headers: { 'Content-Type': 'application/json', 'X-Telegram-Bot-Api-Secret-Token':'test-webhook-secret' }, body: Buffer.from(JSON.stringify(update)) });
  assert.equal(response.httpStatusCode, 500, response.text);
  assert.equal(response.text, 'retry');
}
console.log('PASS: PHP does not acknowledge checkout/payment when database persistence fails');
async function request(url, body, headers = auth) {
  return handler.request({ url, method: body ? 'POST' : 'GET', headers: { ...headers, 'Content-Type': 'application/json' }, body: body ? Buffer.from(JSON.stringify(body)) : undefined });
}
assert.equal((await request('/api/admin.php?action=config_get', null, {})).httpStatusCode, 401);
const initial = await request('/api/admin.php?action=config_get');
assert.equal(initial.httpStatusCode, 200, initial.text);
const snapshot = JSON.parse(initial.text);
assert.deepEqual(snapshot.config, defaults);
assert.equal((await request('/api/admin.php?action=config_save', { config: defaults, revision: snapshot.revision })).httpStatusCode, 403);
assert.equal((await request('/api/admin.php?action=config_save', { config: bad, revision: snapshot.revision, csrf: snapshot.csrf })).httpStatusCode, 422);
const edited = model.cloneConfig(defaults);
edited.economy.starsShop.packs[0].stars += 1;
edited.futureParameter = { kept: true };
const saved = await request('/api/admin.php?action=config_save', { config: edited, revision: snapshot.revision, csrf: snapshot.csrf });
assert.equal(saved.httpStatusCode, 200, saved.text);
const published = JSON.parse(saved.text);
assert.notEqual(published.revision, snapshot.revision);
assert.equal((await request('/api/admin.php?action=config_save', { config: defaults, revision: snapshot.revision, csrf: snapshot.csrf })).httpStatusCode, 409);
const publicConfig = await request('/api/config.php', null, {});
assert.deepEqual(JSON.parse(publicConfig.text).config, edited);
assert.equal((await request('/api/config.php', null, { 'If-None-Match': `"${JSON.parse(publicConfig.text).revision}"` })).httpStatusCode, 304);
const products = await php.run({ code: "<?php require '/www/api/tg_common.php'; echo json_encode(tg_products());" });
assert.equal(JSON.parse(products.text)[edited.economy.starsShop.packs[0].id].stars, edited.economy.starsShop.packs[0].stars);
const login = await request('/api/admin.php?action=login', { key: 'local-test-only' }, {});
assert.equal(login.httpStatusCode, 200, login.text);
console.log('PASS: PHP authorization, CSRF, validation, atomic publish, revision conflict, public config, ETag, payment catalogue, login; no MySQL needed');

if (process.env.UNTOUCH_BROWSER_MODULES) {
  const { chromium } = await import(pathToFileURL(path.join(process.env.UNTOUCH_BROWSER_MODULES, 'playwright/index.mjs')));
  const server = http.createServer(async (req, res) => {
    try {
      const chunks = []; for await (const chunk of req) chunks.push(chunk);
      const result = await handler.request({ url: req.url, method: req.method, headers: req.headers, body: Buffer.concat(chunks) });
      res.writeHead(result.httpStatusCode, result.headers); res.end(result.bytes);
    } catch (e) { res.writeHead(500); res.end(String(e)); }
  });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  const browser = await chromium.launch({ headless: true });
  try {
    const page = await browser.newPage({ viewport: { width: 1440, height: 1000 } });
    const errors = []; page.on('pageerror', e => errors.push(e.message));
    await page.goto(`http://127.0.0.1:${server.address().port}/admin/`);
    await page.locator('#admin-key').fill('local-test-only');
    await page.locator('#login-form button').click();
    await page.locator('#cfg-json').waitFor();
    const field = page.locator('[data-path="player.size"]');
    await page.locator('[data-group="player"] summary').click();
    await field.fill('35');
    assert.equal(JSON.parse(await page.locator('#cfg-json').inputValue()).player.size, 35);
    await field.fill('-1');
    assert.equal(await page.locator('[data-save]').isDisabled(), true);
    assert.equal(await field.getAttribute('aria-invalid'), 'true');
    await field.fill('35');
    await page.locator('[data-save]').click();
    await page.waitForFunction(() => document.querySelector('[data-save]').disabled && document.querySelector('[data-message]').textContent.toLowerCase().includes('сохранено'));
    await page.locator('#cfg-export-scope').selectOption('economy');
    assert.deepEqual(JSON.parse(await page.locator('#cfg-json').inputValue()), edited.economy);
    await page.locator('#cfg-export-scope').selectOption('all');
    await field.fill('36');
    await page.waitForFunction(() => JSON.parse(localStorage.getItem('untouch_admin_config_draft_v1') || 'null')?.config.player.size === 36);
    await page.reload();
    await page.locator('[data-restore-draft]').waitFor({ state: 'visible' });
    await page.locator('[data-restore-draft]').click();
    assert.equal(JSON.parse(await page.locator('#cfg-json').inputValue()).player.size, 36);
    await page.locator('[data-discard]').click();
    assert.equal(JSON.parse(await page.locator('#cfg-json').inputValue()).player.size, 35);
    await page.evaluate(() => scrollTo(0, 0));
    const preview = await page.locator('.cfg-preview').boundingBox();
    const form = await page.locator('.cfg-form').boundingBox();
    assert.ok(preview.x >= form.x + form.width, 'JSON preview must be beside the form on desktop');
    assert.ok(Math.abs(preview.y - form.y) < 5, 'JSON preview must start beside the first block');
    await page.screenshot({ path: path.join(process.env.TEMP || '/tmp', 'untouch-admin-desktop.png'), fullPage: false });
    await page.setViewportSize({ width: 390, height: 844 });
    assert.equal(await page.evaluate(() => document.documentElement.scrollWidth > innerWidth), false);
    await page.screenshot({ path: path.join(process.env.TEMP || '/tmp', 'untouch-admin-mobile.png'), fullPage: false });
    await page.locator('[data-view="monetize"]').click();
    if (defaults.economy.energy) {
    await page.locator('[data-calc-jumps]').selectOption('3');
    await page.locator('[data-calc-shield]').check();
    await page.locator('[data-calc-impulse]').check();
    const expectedCost = defaults.economy.energy.roundCost + defaults.economy.energy.jump3Cost + defaults.economy.energy.shieldCost + defaults.economy.energy.impulseCost;
    assert.ok((await page.locator('[data-energy-metrics]').innerText()).includes(`${expectedCost} энергии`));
    assert.deepEqual(JSON.parse(await page.locator('[data-energy-json]').inputValue()), defaults.economy.energy);
    }
    assert.deepEqual(errors, []);
    console.log('PASS: browser login, form editing, live JSON, save, APK block export, mobile layout, no browser errors');
  } finally { await browser.close(); await new Promise(resolve => server.close(resolve)); }
}
php.exit();

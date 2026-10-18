import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
const code = await fs.readFile(new URL('./telegram-api-proxy.worker.js', import.meta.url), 'utf8');
const worker = (await import('data:text/javascript;base64,' + Buffer.from(code).toString('base64'))).default;
const update = { update_id: 7, message: { successful_payment: { invoice_payload: 'test' } } };
const request = () => new Request('https://example.test/webhook', { method: 'POST', body: JSON.stringify(update) });
const ctx = { waitUntil() { assert.fail('Critical delivery must be awaited'); } };
let finish;
globalThis.fetch = () => new Promise(resolve => { finish = resolve; });
let completed = false;
const pending = worker.fetch(request(), {}, ctx).then(r => { completed = true; return r; });
await new Promise(resolve => setImmediate(resolve));
assert.equal(completed, false);
finish(new Response('ok'));
assert.equal((await pending).status, 200);
for (const response of [new Response('bad', { status: 500 }), new Response('retry'), new Response('nginx error')]) {
  globalThis.fetch = async () => response;
  assert.equal((await worker.fetch(request(), {}, ctx)).status, 503);
}
globalThis.fetch = async () => { throw new Error('offline'); };
assert.equal((await worker.fetch(request(), {}, ctx)).status, 503);
assert.equal((await worker.fetch(request(), { WEBHOOK_SECRET: 'test-secret' }, ctx)).status, 403);
globalThis.fetch = async () => new Response('ok');
const checkout = new Request('https://example.test/webhook', { method: 'POST', body: JSON.stringify({ pre_checkout_query: { id: 'test' } }) });
assert.equal((await worker.fetch(checkout, {}, ctx)).status, 200);
console.log('PASS: Worker waits for persistence, retries HTTP/body/network errors, validates configured secret and handles checkout');

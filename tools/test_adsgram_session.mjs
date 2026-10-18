import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
const root = process.env.UNTOUCH_WEB_ROOT || new URL('../telegram-web/', import.meta.url);
const source = (await fs.readFile(new URL('js/adsgram.js', typeof root === 'string' ? new URL(`file:///${root.replaceAll('\\','/')}/`) : root), 'utf8')).replace(/import \{ RU \} from '\.\/strings-ru\.js(?:\?[^']*)?';/, 'const RU = {};');
let seq = 0;
const load = () => import(`data:text/javascript;base64,${Buffer.from(source + `\n// isolated ${seq++}`).toString('base64')}`);
function sdk(event, result) {
  const listeners = new Map(); let shows = 0, alerts = 0, inits = 0;
  globalThis.window = { Adsgram: { init() {
    inits++;
    return { addEventListener(name, callback) { listeners.set(name, callback); }, async show() {
      shows++;
      if (event) { if (listeners.has(event)) listeners.get(event)(); else alerts++; throw { description: event }; }
      return result;
    } };
  } } };
  return () => ({ shows, alerts, inits, listeners });
}
let state = sdk('onTooLongSession');
let ads = await load();
await assert.rejects(ads.showInterstitialAd('int-123'), e => e.adFail === 'session');
await assert.rejects(ads.showInterstitialAd('int-123'), e => e.adFail === 'session');
await assert.rejects(ads.showRewardedAd('456'), e => e.adFail === 'session');
assert.equal(ads.adUnavailableReason(), 'session');
assert.deepEqual({...state(),listeners:undefined},{shows:1,alerts:0,inits:1,listeners:undefined});
for (const event of ['onBannerNotFound', 'onNonStopShow']) {
  state = sdk(event); ads = await load();
  await assert.rejects(ads.showInterstitialAd('int-123'));
  await assert.rejects(ads.showInterstitialAd('int-123'), e => e.adFail === 'cooldown');
  assert.equal(state().alerts,0); assert.equal(state().shows,1);
}
state = sdk(null, {done:true}); ads = await load();
assert.deepEqual(await ads.showRewardedAd('456'),{done:true});
assert.deepEqual(await ads.showRewardedAd('456'),{done:true});
assert.equal(state().inits,1); assert.equal(state().shows,2);
assert.equal(ads.classifyAdFail('session is too long'), 'session');
assert.equal(ads.classifyAdFail('user skipped'), 'skip');
delete globalThis.window;
console.log('PASS: SDK session/no-fill/rate-limit events replace blocking alerts; session expiry prevents further SDK calls, cooldown backs off, controller reused, completed rewarded response preserved. No real ads or rewards.');

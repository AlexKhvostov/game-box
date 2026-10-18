/** Isolated local preview. Serves fixtures only; never proxies player APIs. */
import http from 'node:http';
import fs from 'node:fs/promises';
import path from 'node:path';

const project = path.resolve(import.meta.dirname, '..');
const web = path.join(project, 'telegram-web');
const assets = path.join(project, 'assets');
const config = JSON.parse(await fs.readFile(path.join(web, 'config/gameplay-config.json'), 'utf8'));
config.yandexMetrikaId = 0;
config.economy.installBonusAutoClaim = false;
for (const key of Object.keys(config.economy)) {
  if (/adsgram.*(id|block)/i.test(key)) config.economy[key] = '';
}
const fixtureScore = {
  id: 'neon_preview_score', userId: 'neon_preview_peer', playerName: 'Тестовый игрок',
  timeMs: 21349, createdAt: Date.now(), runDistance: 435, riskCount: 8,
  hadJump: true, hadHelmet: false,
};
const types = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript; charset=utf-8',
  '.json': 'application/json', '.css': 'text/css; charset=utf-8', '.svg': 'image/svg+xml',
  '.png': 'image/png', '.jpg': 'image/jpeg', '.webp': 'image/webp', '.wav': 'audio/wav' };
const fixtureBoot = `<script>
  localStorage.setItem('untouch_tg_economy', JSON.stringify({lives:8,tokens:15,bestTimeMs:18019,
    musicEnabled:false,hapticEnabled:false,lightTheme:new URLSearchParams(location.search).get('theme')==='light'}));
  window.Telegram={WebApp:{platform:'tdesktop',initData:'isolated-neon-preview',initDataUnsafe:{},isFullscreen:false,
    safeAreaInset:{top:0,right:0,bottom:0,left:0},contentSafeAreaInset:{top:44,right:0,bottom:0,left:0},
    ready(){},expand(){},disableVerticalSwipes(){},requestFullscreen(){},lockOrientation(){},onEvent(){},
    setHeaderColor(){},setBackgroundColor(){},HapticFeedback:{impactOccurred(){},notificationOccurred(){},selectionChanged(){}}}};
  window.Adsgram={init(){return {show(){return Promise.reject(new Error('isolated-preview-ad-disabled'))}}}};
  addEventListener('load',()=>{const timer=setInterval(()=>{
    const boot=document.getElementById('boot-loader');
    if(!window.app?.economy||!window.app?.world||(boot&&!boot.classList.contains('hidden')))return;
    clearInterval(timer); const app=window.app;
    app.economy.musicEnabled=false;app.audio.userMusicEnabled=false;app.audio.stopMusic?.();
    if(new URLSearchParams(location.search).get('state')==='zero')app.economy.lives=0;
    const state=new URLSearchParams(location.search).get('state');
    app._updateHud();app._updateOverlay();
    if(state==='profile')app.sheets.open('profile');
    if(state==='result'||state==='share') {
      app.aliveMs=21349;app.world.playerDistance=435*.1*app.world.playerSize;
      app.world.nearMissCount=8;app.runHadJump=false;app.runHadHelmet=false;
      app._finishImpact();
      if(state==='share')app.sheets.open('share',{timeMs:app.resultMs,run:app.resultRun,risk:app.resultRisk});
    }
    if(state==='leaderboard'||state==='player') {
      app.sheets.open('leaderboard');
      if(state==='player') {
        const playerTimer=setInterval(()=>{
          if(app.sheets._lbLoading)return;
          clearInterval(playerTimer);
          const entry=app.economy.getAttemptsForPeriod('day')[0];
          if(entry)app.sheets._showPlayerModal(entry,'🥇 1 место','day');
        },50);
      }
    }
    },50)});
</script>`;
const server = http.createServer(async (req, res) => {
  try {
    const url = new URL(req.url, 'http://127.0.0.1');
    res.setHeader('Cache-Control', 'no-store');
    if (url.pathname.startsWith('/api/')) {
      res.setHeader('Content-Type', types['.json']);
      if (url.pathname === '/api/launch.php' && req.method === 'POST') {
        let body = '';
        for await (const part of req) {
          body += part;
          if (body.length > 4096) { res.writeHead(413); res.end('{}'); return; }
        }
        let input;
        try { input = JSON.parse(body); } catch { input = null; }
        const verified = input?.platform === 'tdesktop' && input?.initData === 'isolated-neon-preview';
        res.writeHead(verified ? 200 : 403);
        res.end(JSON.stringify({ok:verified,verified})); return;
      }
      const fixture = url.pathname === '/api/config.php'
        ? { ok: true, config, revision: 'isolated-neon-preview' }
        : url.pathname === '/api/scores.php' && req.method === 'GET'
          ? { scores: [fixtureScore] }
          : { ok: false, reason: 'isolated-preview-no-remote-actions', scores: [fixtureScore] };
      res.end(JSON.stringify(fixture)); return;
    }
    if (url.pathname === '/config/gameplay-config.json') {
      res.setHeader('Content-Type', types['.json']); res.end(JSON.stringify(config)); return;
    }
    const relative = url.pathname === '/' ? 'index.html' : decodeURIComponent(url.pathname.slice(1));
    let file = path.resolve(web, relative);
    if (!file.startsWith(web + path.sep)) { res.writeHead(403); res.end(); return; }
    if (relative.startsWith('assets/')) {
      const candidate = path.resolve(assets, relative.slice(7));
      if (!candidate.startsWith(assets + path.sep)) { res.writeHead(403); res.end(); return; }
      try { await fs.access(candidate); file = candidate; } catch {}
    }
    let data = await fs.readFile(file);
    if (relative === 'index.html') {
      let html = data.toString('utf8').replace(/<script\b[^>]*\bsrc=["']https?:\/\/[^"']+["'][^>]*>\s*<\/script>/gi, '');
      html = html.replace('<title>Untouch</title>', '<title>Untouch — тестовое превью</title>');
      html = html.replace('<head>', '<head>' + fixtureBoot);
      data = Buffer.from(html);
      res.setHeader('Content-Security-Policy', "default-src 'self' data: blob:; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; connect-src 'self'; img-src 'self' data: blob:; media-src 'self' blob:; font-src 'self' data:");
    }
    res.setHeader('Content-Type', types[path.extname(file)] || 'application/octet-stream');
    res.end(data);
  } catch { res.writeHead(404); res.end('Not found'); }
});
await new Promise(resolve => server.listen(Number(process.env.UNTOUCH_PREVIEW_PORT || 8766), '127.0.0.1', resolve));
console.log(`Isolated preview: http://127.0.0.1:${server.address().port}/ (state=zero, theme=light). All APIs are fixtures.`);
for (const signal of ['SIGINT', 'SIGTERM']) process.on(signal, () => server.close(() => process.exit(0)));

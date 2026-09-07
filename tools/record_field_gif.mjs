/**
 * Capture BotFather demo GIF from the real field renderer via Chrome CDP.
 */
import { spawn, spawnSync } from 'node:child_process';
import { mkdir } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = join(fileURLToPath(new URL('.', import.meta.url)), '..');
const OUT_GIF = join(ROOT, 'telegram-web', 'assets', 'branding', 'botfather_demo.gif');
const CHROME = 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';
const PORT = 9224;
const PAGE = 'http://127.0.0.1:8765/tools/botfather-demo/index.html?still=1';

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function waitJson(url, tries = 50) {
  for (let i = 0; i < tries; i++) {
    try {
      const res = await fetch(url);
      if (res.ok) return await res.json();
    } catch {
      /* retry */
    }
    await sleep(120);
  }
  throw new Error('Chrome CDP not ready: ' + url);
}

class Cdp {
  constructor(ws) {
    this.ws = ws;
    this.id = 0;
    this.pending = new Map();
    ws.onmessage = (ev) => {
      const msg = JSON.parse(ev.data);
      if (msg.id && this.pending.has(msg.id)) {
        const { resolve, reject } = this.pending.get(msg.id);
        this.pending.delete(msg.id);
        if (msg.error) reject(new Error(JSON.stringify(msg.error)));
        else resolve(msg.result);
      }
    };
  }

  send(method, params = {}) {
    const id = ++this.id;
    return new Promise((resolve, reject) => {
      this.pending.set(id, { resolve, reject });
      this.ws.send(JSON.stringify({ id, method, params }));
    });
  }
}

async function main() {
  const profile = join(tmpdir(), 'untouch-gif-chrome');
  await mkdir(profile, { recursive: true });
  const chrome = spawn(
    CHROME,
    [
      '--headless=new',
      '--disable-gpu',
      '--hide-scrollbars',
      '--window-size=780,800',
      `--remote-debugging-port=${PORT}`,
      `--user-data-dir=${profile}`,
      PAGE,
    ],
    { stdio: 'ignore' },
  );

  try {
    await waitJson(`http://127.0.0.1:${PORT}/json/version`);
    await sleep(500);
    const pages = await waitJson(`http://127.0.0.1:${PORT}/json/list`);
    const tab = pages.find((p) => p.webSocketDebuggerUrl && p.url.includes('botfather-demo'))
      || pages.find((p) => p.webSocketDebuggerUrl);
    if (!tab) throw new Error('No Chrome tab');
    const ws = new WebSocket(tab.webSocketDebuggerUrl);
    await new Promise((resolve, reject) => {
      ws.onopen = resolve;
      ws.onerror = reject;
    });
    const cdp = new Cdp(ws);
    await cdp.send('Runtime.enable');
    await cdp.send('Page.enable');
    await sleep(600);

    const ready = await cdp.send('Runtime.evaluate', {
      expression: 'Boolean(window.DEMO && window.DEMO.frames)',
      returnByValue: true,
    });
    if (!ready.result.value) throw new Error('DEMO API missing — check the module page');

    const countRes = await cdp.send('Runtime.evaluate', {
      expression: 'window.DEMO.frames',
      returnByValue: true,
    });
    const frames = countRes.result.value;
    const pngs = [];
    for (let i = 0; i < frames; i++) {
      const res = await cdp.send('Runtime.evaluate', {
        expression: `window.DEMO.png(${i})`,
        returnByValue: true,
      });
      if (!res.result || !res.result.value) {
        throw new Error('Empty frame ' + i + ' ' + JSON.stringify(res));
      }
      pngs.push(res.result.value);
      process.stdout.write(`frame ${i + 1}/${frames}\r`);
    }
    ws.close();

    const py = [
      'from pathlib import Path',
      'from PIL import Image',
      'import io, sys, base64',
      'raw = sys.stdin.read().splitlines()',
      'frames = []',
      'for line in raw:',
      '    if not line.strip():',
      '        continue',
      '    b64 = line.split(",", 1)[1]',
      '    img = Image.open(io.BytesIO(base64.b64decode(b64))).convert("RGBA")',
      '    scale = min(640 / img.width, 360 / img.height)',
      '    nw, nh = max(1, int(round(img.width * scale))), max(1, int(round(img.height * scale)))',
      '    img = img.resize((nw, nh), Image.Resampling.LANCZOS)',
      '    canvas = Image.new("RGB", (640, 360), (14, 20, 25))',
      '    canvas.paste(img.convert("RGB"), ((640 - nw) // 2, (360 - nh) // 2))',
      '    frames.append(canvas.convert("P", palette=Image.ADAPTIVE, colors=96))',
      `out = Path(r"${OUT_GIF.replace(/\\/g, '/')}")`,
      'out.parent.mkdir(parents=True, exist_ok=True)',
      'frames[0].save(out, save_all=True, append_images=frames[1:], duration=70, loop=0, optimize=True, disposal=2)',
      'print(out, out.stat().st_size)',
    ].join('\n');

    const result = spawnSync('python', ['-c', py], {
      input: pngs.join('\n'),
      encoding: 'utf-8',
      maxBuffer: 120 * 1024 * 1024,
    });
    if (result.status !== 0) {
      throw new Error(result.stderr || result.stdout || 'python gif failed');
    }
    process.stdout.write('\n' + result.stdout);
  } finally {
    chrome.kill();
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});

// Render builds the client only. Authentication and player state stay in Supabase.
import fs from 'node:fs/promises';
import path from 'node:path';
import {spawnSync} from 'node:child_process';
const root=path.resolve(import.meta.dirname,'..');
const api=process.env.VITE_TELEGRAM_API_URL??'';
const app=process.env.VITE_TELEGRAM_APP_URL??'';
if(api!=='https://exinizzxqtjnysgibide.supabase.co/functions/v1/telegram-api'
  ||app!=='https://t.me/TestUntouch_bot'||process.env.VITE_QA_MODE!=='true'){
  throw Error('Render client configuration invalid; expected the accepted test-bot deployment.');
}
const npm=process.platform==='win32'?'npm.cmd':'npm';
const build=spawnSync(npm,['run','build'],{cwd:root,stdio:'inherit',shell:process.platform==='win32'});
if(build.status!==0)process.exit(build.status??1);
const {version}=JSON.parse(await fs.readFile(path.join(root,'package.json'),'utf8'));
const commit=process.env.RENDER_GIT_COMMIT??'local';
if(!/^(?:local|[a-f0-9]{40})$/.test(commit))throw Error('Invalid deployment commit');
await fs.writeFile(path.join(root,'dist/version.json'),JSON.stringify({version,
  buildId:`render-v${version}-${commit.slice(0,12)}`,artifact:'telegram-vue',qa:true,
  apiUrl:api,appUrl:app,commit,paymentsEnabled:false,createdAt:new Date().toISOString()},null,2)+'\n');

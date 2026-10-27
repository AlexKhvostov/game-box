import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {pathToFileURL} from 'node:url';
import {root} from './supabase_operator.mjs';
const stage=path.join(root,'.private/ad-formats-deploy');
const inventory=JSON.parse(fs.readFileSync(path.join(stage,'before-hosting.json'),'utf8'));
const script=inventory.files.find(f=>/^\/assets\/.*\.js$/.test(f.path));
const response=await fetch('https://untouch-admin-game-box-b30d4.web.app'+script.path);
if(!response.ok)throw Error('admin_public_source_unavailable');
const live=await response.text();fs.writeFileSync(path.join(stage,'before-admin.js'),live);
const local=fs.readFileSync(path.join(stage,'baseline-web/assets',fs.readdirSync(path.join(stage,'baseline-web/assets')).find(n=>n.endsWith('.js'))),'utf8');
const {parseAst}=await import(pathToFileURL(path.join(root,'admin-console/node_modules/rollup/dist/es/parseAst.js')).href);
function strings(source){const out=new Set();function walk(v){if(!v||typeof v!=='object')return;if(v.type==='Literal'&&typeof v.value==='string')out.add(v.value);for(const x of Object.values(v))if(Array.isArray(x))x.forEach(walk);else if(x&&typeof x==='object')walk(x);}walk(parseAst(source));return out;}
const a=strings(live),b=strings(local);
const summary={hostingCreated:inventory.version.createTime,liveBytes:Buffer.byteLength(live),baselineBytes:Buffer.byteLength(local),liveHasAdSections:live.includes('ads-banner'),onlyLive:[...a].filter(v=>!b.has(v)),onlyBaseline:[...b].filter(v=>!a.has(v))};
fs.writeFileSync(path.join(stage,'admin-baseline-comparison.json'),JSON.stringify(summary,null,2));
console.log(JSON.stringify(summary));

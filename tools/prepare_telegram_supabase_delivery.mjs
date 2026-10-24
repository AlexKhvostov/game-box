import fs from 'node:fs/promises';
import path from 'node:path';
import {createHash} from 'node:crypto';
const root=path.resolve(import.meta.dirname,'..'),functions=path.join(root,'supabase/functions');
const slug=process.argv[2];
if(!['android-api','telegram-api','telegram-payment-webhook','play-reconcile','remote-config-admin','support-admin'].includes(slug))throw Error('Unknown delivery entrypoint');
const files=new Map();
async function visit(name){
  if(files.has(name))return;
  const absolute=path.resolve(functions,name);
  if(!absolute.startsWith(functions+path.sep))throw Error('External source dependency');
  const content=await fs.readFile(absolute,'utf8');files.set(name,content);
  for(const match of content.matchAll(/(?:from\s*|import\s*)['"]([^'"]+)['"]/g)){
    if(match[1].startsWith('.'))await visit(path.posix.normalize(path.posix.join(path.posix.dirname(name),match[1])));
  }
}
await visit(`${slug}/index.ts`);await visit('deno.json');
const payload={name:slug,project_id:'exinizzxqtjnysgibide',verify_jwt:false,
  entrypoint_path:`functions/${slug}/index.ts`,import_map_path:'functions/deno.json',
  files:[...files].map(([name,content])=>({name:`functions/${name}`,content}))};
if(process.argv.includes('--payload'))console.log(JSON.stringify(payload));
else console.log(JSON.stringify({name:slug,files:payload.files.map(f=>({name:f.name,sha256:createHash('sha256').update(f.content).digest('hex')}))},null,2));

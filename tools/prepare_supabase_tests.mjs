import fs from 'node:fs';
const original=fs.readFileSync('firebase-android/test/engine.test.js','utf8');
const start=original.indexOf("const runTag=");
if(start<0)throw Error('Test fixture boundary missing');
let tests=original.slice(start).replaceAll('firebase:','supabase:')
  .replaceAll('r.uid === uid','r.userId === `supabase:${uid}`');
const header=`// Behavioral suite reused against actual PostgreSQL (PGlite), not Firestore.\n// One PGlite connection serializes local tests; multi-connection isolation also\n// requires production PostgreSQL acceptance before release.\nimport {test,before,after} from 'node:test';\nimport assert from 'node:assert/strict';\nimport {createRequire} from 'node:module';\nimport {createEngine,codeFor} from '../functions/_shared/core/engine.mjs';\nimport {defaults,hash,validatePolicy} from '../functions/_shared/core/policy.mjs';\nimport {createPlayVerifier} from '../functions/_shared/core/play.mjs';\nimport {PostgresStore} from '../functions/_shared/postgres-store.mjs';\nimport {testDatabase} from './database.mjs';\nconst require=createRequire(import.meta.url);\nconst local=await testDatabase();\nconst db=new PostgresStore(local.pool);\nafter(()=>local.close());\n`;
fs.writeFileSync('supabase/test/game.test.mjs',header+tests);
console.log('PostgreSQL game behavior suite prepared.');

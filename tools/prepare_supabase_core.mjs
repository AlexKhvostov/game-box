// Validate the canonical core. Never overwrite reviewed fixes with a legacy generator.
import fs from 'node:fs';
import {fileURLToPath} from 'node:url';
import path from 'node:path';
const root=path.dirname(path.dirname(fileURLToPath(import.meta.url)));
for(const name of ['engine','policy','play']) {
 const source=fs.readFileSync(path.join(root,`supabase/functions/_shared/core/${name}.mjs`),'utf8');
 if(/require\(|module\.exports/.test(source))throw Error(`CommonJS in ${name}`);
 await import(new URL(`../supabase/functions/_shared/core/${name}.mjs`,import.meta.url));
}
console.log('Canonical Supabase core validated; source files preserved.');

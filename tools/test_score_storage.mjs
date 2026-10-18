import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import path from 'node:path';
import { pathToFileURL } from 'node:url';
import { execFileSync } from 'node:child_process';

const root = path.resolve(import.meta.dirname, '..');
const web = process.env.UNTOUCH_WEB_ROOT || path.join(root, 'telegram-web');
if (!process.env.UNTOUCH_PHP_MODULES) throw new Error('Set UNTOUCH_PHP_MODULES to the temporary php-wasm node_modules directory');
const modules = process.env.UNTOUCH_PHP_MODULES;
const { PHP } = await import(pathToFileURL(path.join(modules, '@php-wasm/universal/index.js')));
const { loadNodeRuntime } = await import(pathToFileURL(path.join(modules, '@php-wasm/node/index.js')));
const php = new PHP(await loadNodeRuntime('8.3', { emscriptenOptions: { processId: 1 } }));
php.mkdirTree('/www/api');
php.writeFile('/www/api/tg_common.php', await fs.readFile(path.join(web, 'api/tg_common.php')));
php.writeFile('/www/api/schema_migrations.php', await fs.readFile(path.join(web, 'api/schema_migrations.php')));
php.writeFile('/www/api/mobile_store.php', await fs.readFile(path.join(web, 'api/mobile_store.php')));
php.writeFile('/www/api/mobile_wallet.php', await fs.readFile(path.join(web, 'api/mobile_wallet.php')));
php.writeFile('/www/api/db_config.php', "<?php return ['database'=>'isolated-test','username'=>'test'];");
const source = await fs.readFile(path.join(web, 'api/scores.php'), 'utf8');
const fixture = `
class AuditStatement {
    private $rows;
    function __construct($rows) { $this->rows = $rows; }
    function fetchAll($mode = null) { return $this->rows; }
}
class AuditPDO {
    static $rows = [
        ['id'=>1,'user_id'=>'101','username'=>'a','player_name'=>'One','score_day'=>'2026-10-04','time_ms'=>10000],
        ['id'=>2,'user_id'=>'102','username'=>'b','player_name'=>'Two','score_day'=>'2026-10-04','time_ms'=>9000]
    ];
    function __construct(...$args) {}
    function query($sql) { return new AuditStatement(self::$rows); }
    function exec($sql) { if (preg_match('/^\\s*TRUNCATE/i', $sql)) self::$rows = []; return 0; }
}
`;
async function check(code, flagPresent) {
  const bootstrap = code.slice(code.indexOf('<?php') + 5, code.indexOf('// 2. Файловый резерв')).replaceAll('new PDO(', 'new AuditPDO(').replace('tg_ensure_score_tables($pdo);', '/* One-time schema changes have their own MySQL checks. */');
  assert.ok(bootstrap.length > 1000, 'Real database bootstrap must be exercised');
  php.writeFile('/www/api/bootstrap.php', '<?php' + fixture + bootstrap + `
echo json_encode(['rows'=>count(AuditPDO::$rows), 'file'=>@file_get_contents(__DIR__.'/scores.json'), 'flag'=>is_file(__DIR__.'/scores_steps_v1.flag')]);`);
  php.writeFile('/www/api/scores.json', 'existing-score-history');
  if (flagPresent) php.writeFile('/www/api/scores_steps_v1.flag', 'existing-flag');
  else if (php.fileExists('/www/api/scores_steps_v1.flag')) php.unlink('/www/api/scores_steps_v1.flag');
  const result = await php.run({ scriptPath: '/www/api/bootstrap.php' });
  return JSON.parse(result.text);
}
// Show that the regression scenario detects the destructive original behavior.
const original = execFileSync('git', ['-c', `safe.directory=${root.replaceAll('\\', '/')}`, 'show', 'ef6baba:telegram-web/api/scores.php'], { cwd: root, encoding: 'utf8' });
const before = await check(original, false);
assert.equal(before.rows, 0);
assert.equal(before.file, false);
for (const flag of [false, true]) {
  const after = await check(source, flag);
  assert.equal(after.rows, 2, 'Database history must survive missing marker');
  assert.equal(after.file, 'existing-score-history', 'Fallback history must remain intact');
  assert.equal(after.flag, flag, 'A normal request must not create/delete migration markers');
}
console.log('PASS: original regression reproduced; actual database bootstrap preserves SQL and fallback history with and without marker');
console.log('Database transport isolated with a test double; no production database accessed');
php.exit();

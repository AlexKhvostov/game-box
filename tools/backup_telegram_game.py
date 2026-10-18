"""Dated rollback snapshot of game code; credentials stay on stdin/in memory."""
import concurrent.futures
from datetime import datetime, timezone
import ftplib
import hashlib
import io
import json
import pathlib
import re
import ssl
import subprocess
import urllib.error
import urllib.parse
import urllib.request
import zipfile

ORIGIN = 'https://untouch.ballaball.xyz/'
ROOT_FILES = {'.htaccess', 'index.html', 'release.json', 'version.json', 'manifest.json', 'favicon.png', 'i.php'}
GAME_DIRS = {'js', 'css', 'config', 'assets', 'icons'}
PROFILE_FILES = {'api/scores.php', 'api/tg_common.php', 'api/mobile_store.php'}
DENY = b'Options -Indexes\n<IfModule mod_authz_core.c>\n  Require all denied\n</IfModule>\n<IfModule !mod_authz_core.c>\n  Order allow,deny\n  Deny from all\n</IfModule>\n'

def run(credentials, root, destination, label, retrieve_private, resume_local=False):
    if root != '/' or not re.fullmatch(r'\d{4}-\d{2}-\d{2}', label):
        raise ValueError('Game backup requires verified root / and a requested date')
    datetime.strptime(label, '%Y-%m-%d')
    target = pathlib.Path(destination).resolve()
    workspace = pathlib.Path(__file__).resolve().parent.parent
    if not target.is_relative_to(workspace / 'releases') or (target.exists() and not resume_local):
        raise ValueError('Backup must be a new directory under project releases')
    started = datetime.now(timezone.utc)
    nonce = started.strftime('%Y%m%d_%H%M%S_%f')
    remote_dir = f'.backups/telegram-before-neon-{label}_{nonce}'
    previous = None
    if resume_local:
        previous = json.loads((target / 'manifest.json').read_text(encoding='utf-8'))
        if previous.get('state') != 'local-complete' or previous.get('requestedDate') != label or previous.get('remoteRoot') != root:
            raise ValueError('Only an incomplete local snapshot can resume before FTP upload')
    else: target.mkdir(parents=True, exist_ok=False)
    site = target / 'site'
    if not resume_local: site.mkdir()

    def connect():
        context = ssl.create_default_context()
        context.maximum_version = ssl.TLSVersion.TLSv1_2
        client = ftplib.FTP_TLS(context=context, timeout=30)
        client.connect(credentials['host'], int(credentials.get('port', 21)))
        client.auth(); client.login(credentials['user'], credentials['password']); client.prot_p(); client.cwd(root)
        return client

    def entries(directory):
        for attempt in range(3):
            client = connect()
            try:
                result = list(client.mlsd(directory))
                return result
            except (OSError, EOFError, ftplib.error_temp):
                if attempt == 2: raise
            finally: client.close()

    def file_fact(relative, facts):
        if not str(facts.get('size', '')).isdigit() or not re.fullmatch(r'\d{14}(?:\.\d+)?', facts.get('modify', '')):
            raise ValueError('FTP size/modify facts missing: ' + relative)
        return {'path': relative, 'bytes': int(facts['size']), 'modify': facts['modify']}
    def walk(directory, result):
        for name, facts in entries(directory):
            if facts.get('type') in ('cdir', 'pdir'): continue
            if '/' in name or '\\' in name or name in ('.', '..'): raise ValueError('Unsafe FTP inventory entry')
            relative = directory.rstrip('/') + '/' + name if directory else name
            if facts.get('type') == 'dir':
                walk(relative, result)
            elif facts.get('type') == 'file':
                result.append(file_fact(relative, facts))
            else: raise ValueError('Unsupported FTP entry type: ' + relative)
    def collect_inventory():
        result = []
        top_map = {name: facts for name, facts in entries('') if facts.get('type') not in ('cdir', 'pdir')}
        for name in sorted(ROOT_FILES):
            if name in top_map:
                facts = top_map[name]
                if facts.get('type') != 'file': raise ValueError('Expected game entry file')
                result.append(file_fact(name, facts))
        for name in sorted(GAME_DIRS):
            if name in top_map:
                if top_map[name].get('type') != 'dir': raise ValueError('Expected game directory')
                walk(name, result)
        api = {name: facts for name, facts in entries('api') if facts.get('type') == 'file'}
        for name in sorted(PROFILE_FILES):
            facts = api.get(pathlib.PurePosixPath(name).name)
            if not facts: raise ValueError('Required profile file missing: ' + name)
            result.append(file_fact(name, facts))
        return result
    inventory = collect_inventory()
    if previous:
        old_facts = sorted((row['path'], row['bytes'], row['modify']) for row in previous['files'])
        new_facts = sorted((row['path'], row['bytes'], row['modify']) for row in inventory)
        if new_facts != old_facts: raise ValueError('Published code changed before local snapshot resumed')
    if not {'index.html', 'release.json'}.issubset({row['path'] for row in inventory}):
        raise ValueError('Game identity missing')
    (target / 'inventory.json').write_text(json.dumps(inventory, indent=2), encoding='utf-8')
    print(f'Game backup inventory: {len(inventory)} files / {sum(x["bytes"] for x in inventory)} bytes', flush=True)

    def http_bytes(name, length, start=None, end=None):
        headers = {'Accept-Encoding': 'identity', 'Cache-Control': 'no-cache'}
        if start is not None: headers['Range'] = f'bytes={start}-{end}'
        url = ORIGIN + urllib.parse.quote(name) + '?snapshot=' + nonce
        for attempt in range(3):
            try:
                request = urllib.request.Request(url, headers=headers)
                with urllib.request.urlopen(request, timeout=25) as response:
                    expected = length if start is None else end - start + 1
                    if start is not None and (response.status != 206 or response.headers.get('Content-Range') != f'bytes {start}-{end}/{length}'):
                        raise ValueError('Invalid HTTPS snapshot range: ' + name)
                    content = response.read(expected + 1)
                if len(content) != expected: raise ValueError('Incomplete HTTPS snapshot: ' + name)
                return content
            except (OSError, urllib.error.URLError):
                if attempt == 2: raise

    def download(row):
        name, length = row['path'], row['bytes']
        local = site.joinpath(*pathlib.PurePosixPath(name).parts)
        local.parent.mkdir(parents=True, exist_ok=True)
        if length > 16384:
            # Bounded reads avoid this host's long-response TLS stalls.
            content = b''.join(http_bytes(name, length, start, min(length - 1, start + 16383)) for start in range(0, length, 16384))
        else: content = http_bytes(name, length)
        local.write_bytes(content)
        return {**row, 'sha256': hashlib.sha256(content).hexdigest(), 'transport': 'HTTPS from verified FTP inventory'}
    public = [row for row in inventory if row['path'] not in PROFILE_FILES and row['path'] != 'release.json' and not row['path'].endswith('.php') and not row['path'].startswith('.')]
    private = [row for row in inventory if row not in public]
    records = []
    if previous:
        for row in previous['files']:
            local = site.joinpath(*pathlib.PurePosixPath(row['path']).parts)
            if len(local.read_bytes()) != row['bytes'] or hashlib.sha256(local.read_bytes()).hexdigest() != row['sha256']:
                raise ValueError('Local snapshot cannot resume: '+row['path'])
        records = previous['files']
        public = []; private = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        futures = [pool.submit(download, row) for row in public]
        for future in concurrent.futures.as_completed(futures):
            records.append(future.result())
            if len(records) % 20 == 0: print(f'Snapshotted {len(records)}/{len(inventory)} game files', flush=True)
    for row in private:
        local = site.joinpath(*pathlib.PurePosixPath(row['path']).parts)
        local.parent.mkdir(parents=True, exist_ok=True)
        retrieve_private(row['path'], local)
        content = local.read_bytes()
        if len(content) != row['bytes']: raise ValueError('FTP snapshot size mismatch: ' + row['path'])
        records.append({**row, 'sha256': hashlib.sha256(content).hexdigest(), 'transport': 'verified FTPS'})
    # Check that none of the listed code files changed while the snapshot ran.
    after = sorted((row['path'], row['bytes'], row['modify']) for row in collect_inventory())
    before = sorted((row['path'], row['bytes'], row['modify']) for row in inventory)
    if after != before: raise ValueError('Published code changed during game backup')
    old_identity = json.loads((site / 'release.json').read_text(encoding='utf-8-sig'))
    published_identity = json.loads(http_bytes('release.json', (site / 'release.json').stat().st_size).decode('utf-8-sig'))
    if published_identity != old_identity: raise ValueError('FTP and public HTTPS game identity differ')
    record = {'requestedDate': label, 'startedAt': started.isoformat(), 'completedAt': datetime.now(timezone.utc).isoformat(), 'timezone': 'Europe/Minsk', 'remoteRoot': root, 'remoteDirectory': '/' + remote_dir, 'oldIdentity': old_identity, 'state': 'local-complete', 'files': sorted(records, key=lambda row: row['path']), 'preservedInPlace': ['all other API/admin/landing files', 'server secrets', 'database and player data', 'published admin configuration'], 'notes': 'Complete prior game client plus every server-code path overwritten by this release. Not a database/server-secret snapshot; restoring code preserves current player state.'}
    record.update(buildId=old_identity['buildId'], version=old_identity['version'], artifact='telegram-rollback')
    if previous:
        record['startedAt'] = previous['startedAt']
        record['resumedAt'] = started.isoformat()
    groups = {}
    for row in records: groups.setdefault(row['path'].casefold(), []).append(row)
    aliases = [rows for rows in groups.values() if len(rows) > 1]
    for rows in aliases:
        if len({row['sha256'] for row in rows}) != 1: raise ValueError('Distinct case-sensitive files need separate local storage')
    record['identicalCaseAliases'] = [[row['path'] for row in rows] for rows in aliases]
    (target / 'manifest.json').write_text(json.dumps(record, ensure_ascii=False, indent=2), encoding='utf-8')
    (target / 'RESTORE.md').write_text(f'# Возврат предыдущей Telegram игры\n\nОтметка запроса: {label}; точное время снимкаUTC: {started.isoformat()}. Предыдущая версия: {old_identity.get("buildId")}.\n\nАрхив содержит весь старый клиент игры и три заменяемых файлаAPI профиля. Секреты, текущие игроки/БД, опубликованные настройки, прочиеAndroidAPI/лендинг остаются на сервере и не откатываются.\n\nДля возврата подготовить новый релиз из site/ и manifest файловых SHA, затем загрузить через tools/deploy_telegram_web.ps1 после нового backup. Ничего не удалять и не зеркалировать; добавленные новой версией файлы без старых ссылок можно оставить. Перед возвратом перечитать журнал нового релиза и подтвердить целостность.\n', encoding='utf-8')
    archive = target / f'telegram-before-neon-{label}{"-verified-"+nonce if previous else ""}.zip'
    with zipfile.ZipFile(archive, 'x', zipfile.ZIP_DEFLATED) as zipped:
        # FTP names are case-sensitive; Windows physical files can have identical
        # case aliases. Preserve every original name explicitly after SHA checks.
        for row in records:
            data = site.joinpath(*pathlib.PurePosixPath(row['path']).parts).read_bytes()
            if hashlib.sha256(data).hexdigest() != row['sha256']: raise ValueError('Backup source hash changed')
            zipped.writestr('site/'+row['path'], data)
        for name in ['inventory.json', 'manifest.json', 'RESTORE.md']: zipped.write(target/name, name)
    with zipfile.ZipFile(archive) as zipped:
        if zipped.testzip() is not None: raise ValueError('Backup ZIP CRC failure')
        for row in records:
            if hashlib.sha256(zipped.read('site/'+row['path'])).hexdigest() != row['sha256']: raise ValueError('Backup ZIP hash failure')
    archive_hash = hashlib.sha256(archive.read_bytes()).hexdigest()

    def curl(name, upload=None, byte_range=None):
        url = 'ftp://' + credentials['host'] + ':' + str(credentials.get('port', 21)) + urllib.parse.quote(root.rstrip('/')+'/'+name)
        config = 'url = ' + json.dumps(url) + '\nuser = ' + json.dumps(credentials['user']+':'+credentials['password']) + '\n'
        command = ['curl.exe', '--config', '-', '--ssl-reqd', '--tls-max', '1.2', '--disable-epsv', '--silent', '--show-error', '--connect-timeout', '20', '--max-time', '90', '--retry', '2', '--retry-all-errors']
        if upload is not None: command += ['--upload-file', str(upload)]
        if byte_range: command += ['--range', byte_range]
        result = subprocess.run(command, input=config.encode(), capture_output=True)
        if result.returncode:
            message = result.stderr.decode(errors='replace')
            for value in [credentials['password'], credentials['user']]: message = message.replace(value, '[redacted]') if value else message
            raise RuntimeError('Verified backup FTPS transfer failed: '+name+': '+message)
        return result.stdout
    client = connect()
    try:
        try: client.mkd('.backups')
        except ftplib.error_perm:
            client.cwd('.backups'); client.cwd(root)
        client.mkd(remote_dir)
        # Deny HTTP access before any source ZIP is uploaded.
        client.storbinary('STOR '+remote_dir+'/.htaccess', io.BytesIO(DENY))
    finally: client.close()
    if curl(remote_dir+'/.htaccess') != DENY: raise ValueError('Remote backup protection differs')
    probe = target / 'protection-check.txt'
    probe.write_text('Private previous-game backup. No public access.\n', encoding='utf-8')
    curl(remote_dir+'/protection-check.txt', upload=probe)
    try: urllib.request.urlopen(ORIGIN+remote_dir+'/protection-check.txt?proof='+nonce, timeout=25)
    except urllib.error.HTTPError as error:
        if error.code != 403: raise
    else: raise ValueError('Private backup directory is publicly accessible')
    print('Private FTP directory prepared; uploading dated previous-game ZIP...', flush=True)
    remote_archive = remote_dir+'/'+archive.name
    curl(remote_archive, upload=archive)
    length = archive.stat().st_size
    def verify(start):
        end = min(length-1, start+16383)
        content = curl(remote_archive, byte_range=f'{start}-{end}')
        if len(content) != end-start+1: raise ValueError('Incomplete FTP backup ZIP readback')
        return content
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        parts = list(pool.map(verify, range(0, length, 16384)))
    if hashlib.sha256(b''.join(parts)).hexdigest() != archive_hash: raise ValueError('Remote backup ZIP hash mismatch')
    try: urllib.request.urlopen(ORIGIN+remote_archive+'?proof='+nonce, timeout=25)
    except urllib.error.HTTPError as error:
        if error.code != 403: raise
    else: raise ValueError('Backup ZIP is publicly accessible')
    record.update(state='local-and-FTP-complete', archive=archive.name, archiveBytes=length, archiveSha256=archive_hash, ftpArchive='/'+remote_archive, ftpArchiveVerified=True, httpAccessDenied=True, finishedAt=datetime.now(timezone.utc).isoformat())
    (target / 'manifest.json').write_text(json.dumps(record, ensure_ascii=False, indent=2), encoding='utf-8')
    for name in ['manifest.json', 'RESTORE.md']:
        curl(remote_dir+'/'+name, upload=target/name)
        size = (target/name).stat().st_size
        remote = b''.join(curl(remote_dir+'/'+name, byte_range=f'{start}-{min(size-1,start+16383)}') for start in range(0,size,16384)) if size > 16384 else curl(remote_dir+'/'+name)
        if hashlib.sha256(remote).digest() != hashlib.sha256((target/name).read_bytes()).digest(): raise ValueError('Remote backup metadata mismatch')
    print('Previous game preserved locally and on private FTP:', '/'+remote_dir, flush=True)
    print('Backup ZIP SHA256:', archive_hash, flush=True)

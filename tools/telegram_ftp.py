"""FTP release helper. Credentials arrive on stdin from the DPAPI wrapper."""
import argparse
import ftplib
import hashlib
import subprocess
import urllib.parse
import json
import pathlib
import ssl
import sys
import zipfile
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone

def ftp_context():
    context = ssl.create_default_context()
    # Use verified TLS 1.2 for this server's FTP data-channel compatibility.
    context.maximum_version = ssl.TLSVersion.TLSv1_2
    return context

parser = argparse.ArgumentParser()
parser.add_argument('mode', choices=['inspect', 'backup-landing', 'backup-game', 'finish-game-backup', 'prepare-game-deploy', 'deploy', 'commerce-test', 'energy-test', 'schema-test', 'mobile-test', 'mobile-migrate', 'migrate', 'webhook-setup', 'google-config-prepare', 'google-config-apply', 'ui-life-refund'])
parser.add_argument('--root', default='/')
parser.add_argument('--release', type=pathlib.Path)
parser.add_argument('--resume-backup', type=pathlib.Path)
parser.add_argument('--changed-only', action='store_true')
parser.add_argument('--google-web-client-id', default='')
parser.add_argument('--prepared-config', type=pathlib.Path)
parser.add_argument('--backup-label', default='')
args = parser.parse_args()
credentials = json.load(sys.stdin)
ftp = ftplib.FTP_TLS(context=ftp_context(), timeout=30)
ftp.connect(credentials['host'], int(credentials.get('port', 21)))
ftp.auth()
ftp.login(credentials['user'], credentials['password'])
ftp.prot_p()
ftp.cwd(args.root)
print('Connected with verified FTPS; remote root:', ftp.pwd(), flush=True)

def retrieve_backup(name, destination):
    """Restart an interrupted backup download on a fresh verified TLS session."""
    global ftp
    # This host drops reused data/control sessions. Reconnect proactively,
    # retaining certificate verification and avoiding a 30s timeout per file.
    ftp.close()
    ftp = ftplib.FTP_TLS(context=ftp_context(), timeout=30)
    ftp.connect(credentials['host'], int(credentials.get('port', 21)))
    ftp.auth()
    ftp.login(credentials['user'], credentials['password'])
    ftp.prot_p()
    ftp.cwd(args.root)
    for attempt in range(3):
        try:
            ftp.voidcmd('TYPE I')
            byte_count = ftp.size(name)
            if byte_count and byte_count > 16384:
                url = 'ftp://' + credentials['host'] + ':' + str(credentials.get('port',21)) + urllib.parse.quote(args.root.rstrip('/') + '/' + name)
                cfg = 'url = ' + json.dumps(url) + '\nuser = ' + json.dumps(credentials['user'] + ':' + credentials['password']) + '\n'
                def read_range(start):
                    end = min(byte_count-1, start+16383)
                    result = subprocess.run(['curl.exe','--config','-','--ssl-reqd','--tls-max','1.2','--disable-epsv','--silent','--show-error','--connect-timeout','20','--max-time','40','--range',f'{start}-{end}'],input=cfg.encode(),capture_output=True)
                    if result.returncode or len(result.stdout) != end-start+1:
                        raise OSError('Incomplete verified FTPS backup range: ' + name)
                    return result.stdout
                with ThreadPoolExecutor(max_workers=4) as pool:
                    parts = list(pool.map(read_range, range(0, byte_count, 16384)))
                destination.write_bytes(b''.join(parts))
            else:
                with destination.open('wb') as output:
                    ftp.retrbinary('RETR ' + name, output.write)
            return
        except (OSError, EOFError, ftplib.error_temp):
            if attempt == 2:
                raise
            print('Retrying backup download after connection interruption:', name, flush=True)
            ftp.close()
            ftp = ftplib.FTP_TLS(context=ftp_context(), timeout=30)
            ftp.connect(credentials['host'], int(credentials.get('port', 21)))
            ftp.auth()
            ftp.login(credentials['user'], credentials['password'])
            ftp.prot_p()
            ftp.cwd(args.root)


def listing():
    try:
        return [name for name, facts in ftp.mlsd() if facts.get('type') not in ('cdir', 'pdir')]
    except ftplib.error_perm:
        return ftp.nlst()

if args.mode in ('google-config-prepare', 'google-config-apply'):
    from configure_mobile_google import run
    run(ftp, args.google_web_client_id, apply=args.mode == 'google-config-apply', prepared=args.prepared_config)
elif args.mode in ('migrate', 'mobile-migrate', 'webhook-setup'):
    from maintain_telegram_schema import run
    run(ftp, webhook=args.mode == 'webhook-setup', mobile=args.mode == 'mobile-migrate')
elif args.mode == 'ui-life-refund':
    from refund_ui_test_life import run
    run(ftp)
elif args.mode == 'mobile-test':
    from test_mobile_host import run
    def reconnect_test():
        fresh = ftplib.FTP_TLS(context=ftp_context(), timeout=30)
        fresh.connect(credentials['host'], int(credentials.get('port', 21)))
        fresh.auth()
        fresh.login(credentials['user'], credentials['password'])
        fresh.prot_p()
        fresh.cwd(args.root)
        return fresh
    run(ftp, reconnect=reconnect_test)
elif args.mode == 'schema-test':
    from test_schema_host import run
    run(ftp)
elif args.mode == 'energy-test':
    from test_energy_host import run
    run(ftp)
elif args.mode == 'commerce-test':
    from test_commerce_host import run
    run(ftp)
elif args.mode == 'finish-game-backup':
    from finish_telegram_game_backup import finish
    finish(credentials, args.root, args.release)
elif args.mode == 'prepare-game-deploy':
    from prepare_telegram_game_deploy import prepare
    ftp.close()  # The readonly preparer owns its verified metadata connection.
    prepare(credentials, args.root, args.release, args.resume_backup)
elif args.mode == 'backup-game':
    from backup_telegram_game import run
    if args.resume_backup and args.resume_backup.resolve() != args.release.resolve():
        raise ValueError('Local backup resume must name the same incomplete snapshot')
    run(credentials, args.root, args.release, args.backup_label, retrieve_backup, resume_local=bool(args.resume_backup))
elif args.mode == 'inspect':
    try:
        print('FTPS capabilities:', ftp.sendcmd('FEAT'), flush=True)
    except ftplib.error_perm:
        print('FTPS capability discovery unsupported', flush=True)
    print('Entries:', json.dumps(listing(), ensure_ascii=False))
elif args.mode == 'backup-landing':
    # Public landing only. Exclude hosting CGI, ACME and any server credentials.
    backup = args.release.resolve()
    backup.mkdir(parents=True, exist_ok=False)
    origin = ftp.pwd()
    names = []
    def walk_public(directory=''):
        global ftp
        ftp.close()
        ftp = ftplib.FTP_TLS(context=ftp_context(), timeout=30)
        ftp.connect(credentials['host'], int(credentials.get('port', 21)))
        ftp.auth()
        ftp.login(credentials['user'], credentials['password'])
        ftp.prot_p()
        ftp.cwd(origin + ('/' + directory if directory else ''))
        entries = list(ftp.mlsd())
        for name, facts in entries:
            if name in ('.', '..') or '/' in name or '\\' in name:
                continue
            relative = directory + '/' + name if directory else name
            if facts.get('type') == 'dir':
                if directory or name in ('assets', 'demo-engine', 'privacy', 'delete-account'):
                    walk_public(relative)
            elif facts.get('type') == 'file':
                if pathlib.Path(name).suffix.lower() in ('.html','.htm','.css','.js','.json','.png','.webp','.jpg','.jpeg','.svg','.ico'):
                    names.append(relative)
    walk_public()
    ftp.close()
    ftp = ftplib.FTP_TLS(context=ftp_context(), timeout=30)
    ftp.connect(credentials['host'], int(credentials.get('port', 21)))
    ftp.auth()
    ftp.login(credentials['user'], credentials['password'])
    ftp.prot_p()
    ftp.cwd(origin)
    records = []
    for index, name in enumerate(sorted(names), 1):
        dest = backup / 'site' / name
        dest.parent.mkdir(parents=True, exist_ok=True)
        retrieve_backup(name, dest)
        records.append({'path':name,'bytes':dest.stat().st_size,'sha256':hashlib.sha256(dest.read_bytes()).hexdigest()})
        print(f'Archived {index}/{len(names)}: {name}', flush=True)
    record = {'remoteRoot':args.root,'createdAt':datetime.now(timezone.utc).isoformat(),'state':'backup-complete','files':records,'excluded':['cgi-bin','.well-known','server secrets']}
    (backup / 'manifest.json').write_text(json.dumps(record, ensure_ascii=False, indent=2), encoding='utf-8')
    archive_path = backup.with_suffix('.zip')
    with zipfile.ZipFile(archive_path, 'x', zipfile.ZIP_DEFLATED) as archive:
        for source in backup.rglob('*'):
            if source.is_file(): archive.write(source, source.relative_to(backup).as_posix())
    with zipfile.ZipFile(archive_path) as archive:
        for item in records:
            if hashlib.sha256(archive.read('site/'+item['path'])).hexdigest() != item['sha256']:
                raise RuntimeError('Backup ZIP hash mismatch')
    archive_path.with_suffix('.zip.sha256').write_text(hashlib.sha256(archive_path.read_bytes()).hexdigest()+'\n', encoding='ascii')
    print('Public landing backup and ZIP hashes verified:', archive_path, flush=True)
else:
    release = args.release.resolve()
    manifest = json.loads((release / 'manifest.json').read_text(encoding='utf-8-sig'))
    site = release / 'site'
    protected = {'bot_config.php', 'db_config.php', 'mobile_config.php', 'scores.json', 'scores_steps_v1.flag', 'rc_economy_cache.json', 'webhook_last.json', 'admin_guard.json', 'invite_photo_file_id.json'}
    files = []
    for item in manifest['files']:
        relative = pathlib.PurePosixPath(item['path'])
        if relative.is_absolute() or '..' in relative.parts or relative.name in protected:
            raise RuntimeError('Invalid/protected release path')
        if relative.parts[:2] == ('api', 'config-data') and relative.name != '.htaccess':
            raise RuntimeError('Runtime publication in release')
        local = site.joinpath(*relative.parts)
        if hashlib.sha256(local.read_bytes()).hexdigest() != item['sha256']:
            raise RuntimeError('Release hash mismatch: ' + str(relative))
        files.append((str(relative), local))
    # A landing patch may leave known baseline files completely untouched.
    # Only changed paths require backup/precondition checks for overwrite.
    untouched = []
    if args.changed_only:
        expected = manifest.get('expectedBeforeHashes', {})
        if args.mode != 'deploy' or manifest.get('artifact') != 'landing' or not expected:
            raise RuntimeError('Changed-only requires a verified landing baseline')
        hashes = {item['path']:item['sha256'] for item in manifest['files']}
        if any(name not in expected for name, _ in files):
            raise RuntimeError('Incomplete baseline for landing patch')
        untouched = [name for name, _ in files if expected[name] == hashes[name]]
        files = [(name, local) for name, local in files if name not in untouched]
        print('Landing patch scope:',len(files),'changed paths;',len(untouched),'baseline paths left untouched',flush=True)
    # Prerequisites first, entry points last. No delete/mirror command is used.
    files.sort(key=lambda f: (3 if f[0] == 'api/mobile-release.json' else 2 if f[0] in ('index.html', 'admin/index.html', 'release.json', 'api/mobile-release.json', 'api/mobile.php', 'api/scores.php', 'api/admin.php')
                            else 1 if f[0] in ('api/mobile-closed-test.enabled','api/gameplay_config.php') else 0, f[0]))
    if args.resume_backup:
        backup = args.resume_backup.resolve()
        if backup.parent != release or not backup.name.startswith('predeploy-'):
            raise RuntimeError('Backup must be inside the same release')
        record_path = backup / 'deployment.json'
        record = json.loads(record_path.read_text(encoding='utf-8'))
        if record['buildId'] != manifest['buildId'] or record['remoteRoot'] != args.root:
            raise RuntimeError('Backup release/root mismatch')
        if record['state'] not in ('backup-complete', 'failed-restoring', 'previous-files-restored; new files retained'):
            raise RuntimeError('Backup cannot be resumed in this state')
        existing, absent = record['existing'], record['absent']
        for name in existing:
            if not (backup / name).is_file():
                raise RuntimeError('Incomplete backup: ' + name)
        unchanged = [name for name in record['unchanged'] if name not in record['uploaded']]
        def save_record():
            record_path.write_text(json.dumps(record, ensure_ascii=False, indent=2), encoding='utf-8')
        print('Resuming with completed backup:', backup, flush=True)
    else:
        backup = release / ('predeploy-' + datetime.now(timezone.utc).strftime('%Y%m%d_%H%M%S_%f'))
        backup.mkdir()
        existing, absent = [], []
        print('Backing up files before upload...', flush=True)
        unchanged = []
        confirmed_absent_directories = set()
        def backup_one(name, dest):
            parent = str(pathlib.PurePosixPath(name).parent)
            if any(parent == directory or parent.startswith(directory + '/') for directory in confirmed_absent_directories):
                return False
            try:
                retrieve_backup(name, dest)
                return True
            except ftplib.error_perm as error:
                if not str(error).startswith('550'):
                    raise
                dest.unlink(missing_ok=True)
                # Verify absence, never interpret a permission error as absence.
                original = ftp.pwd()
                try:
                    ftp.cwd(parent)
                except ftplib.error_perm as directory_error:
                    if not str(directory_error).startswith('550'):
                        raise
                    # Confirm directory absence from its existing parent; a 550
                    # permission failure must never be mistaken for absence.
                    grandparent = str(pathlib.PurePosixPath(parent).parent)
                    ftp.cwd(grandparent)
                    if pathlib.PurePosixPath(parent).name in listing():
                        raise RuntimeError('Cannot access existing backup directory: ' + parent)
                    confirmed_absent_directories.add(parent)
                else:
                    if pathlib.PurePosixPath(name).name in listing():
                        raise RuntimeError('Cannot back up existing file: ' + name)
                finally:
                    ftp.cwd(original)
                return False
    
        for index, (name, local) in enumerate(files, 1):
            dest = backup / name
            dest.parent.mkdir(parents=True, exist_ok=True)
            for attempt in range(3):
                try:
                    exists = backup_one(name, dest)
                    break
                except (OSError, EOFError, ftplib.error_temp):
                    if attempt == 2:
                        raise
                    print('Reconnecting to verify backup entry:', name, flush=True)
                    ftp.close()
                    ftp = ftplib.FTP_TLS(context=ftp_context(), timeout=30)
                    ftp.connect(credentials['host'], int(credentials.get('port', 21)))
                    ftp.auth()
                    ftp.login(credentials['user'], credentials['password'])
                    ftp.prot_p()
                    ftp.cwd(args.root)
            if exists:
                existing.append(name)
                if hashlib.sha256(dest.read_bytes()).digest() == hashlib.sha256(local.read_bytes()).digest():
                    unchanged.append(name)
            else:
                absent.append(name)
            if index % 20 == 0 or index == len(files):
                print(f'Backed up / checked {index}/{len(files)}', flush=True)
        record = {'buildId': manifest['buildId'], 'remoteRoot': args.root, 'existing': existing, 'absent': absent, 'unchanged': unchanged, 'uploaded': [], 'state': 'backup-complete', 'changedOnly':args.changed_only, 'untouchedBaselineFiles':untouched}
        for name, expected in manifest.get('expectedBeforeHashes', {}).items():
            if name in untouched:
                continue
            if name not in [f[0] for f in files]:
                raise RuntimeError('Expected baseline references a file outside release')
            actual = hashlib.sha256((backup / name).read_bytes()).hexdigest() if name in existing else None
            if actual != expected:
                raise RuntimeError('Published baseline changed before deployment: ' + name)
        record_path = backup / 'deployment.json'
        def save_record():
            record_path.write_text(json.dumps(record, ensure_ascii=False, indent=2), encoding='utf-8')
        save_record()
        with zipfile.ZipFile(backup.with_suffix('.zip'), 'w', zipfile.ZIP_DEFLATED) as archive:
            for old_file in backup.rglob('*'):
                if old_file.is_file():
                    archive.write(old_file, old_file.relative_to(backup).as_posix())
    created = set()
    def ensure_parent(name):
        parts = pathlib.PurePosixPath(name).parts[:-1]
        for i in range(1, len(parts) + 1):
            directory = '/'.join(parts[:i])
            if directory in created:
                continue
            try:
                ftp.mkd(directory)
            except ftplib.error_perm:
                original = ftp.pwd()
                ftp.cwd(directory)  # Fail if directory is neither existing nor creatable.
                ftp.cwd(original)
            created.add(directory)
    def reconnect():
        global ftp
        ftp.close()
        ftp = ftplib.FTP_TLS(context=ftp_context(), timeout=30)
        ftp.connect(credentials['host'], int(credentials.get('port', 21)))
        ftp.auth()
        ftp.login(credentials['user'], credentials['password'])
        ftp.prot_p()
        ftp.cwd(args.root)

    def curl_transfer(name, local=None, byte_range=None, expected_length=None):
        remote = args.root.rstrip('/') + '/' + name
        url = 'ftp://' + credentials['host'] + ':' + str(credentials.get('port', 21)) + urllib.parse.quote(remote)
        # Authentication is supplied only on stdin, never command-line arguments.
        config = 'url = ' + json.dumps(url) + '\nuser = ' + json.dumps(credentials['user'] + ':' + credentials['password']) + '\n'
        command = ['curl.exe', '--config', '-', '--ssl-reqd', '--silent', '--show-error',
                   '--tls-max', '1.2', '--disable-epsv', '--connect-timeout', '20', '--max-time', '90', '--retry', '0']
        if local is not None:
            command += ['--ftp-create-dirs', '--upload-file', str(local)]
        if byte_range is not None:
            command += ['--range', byte_range]
            start, end = [int(value) for value in byte_range.split('-')]
            range_length = end - start + 1
            if start < 0 or range_length <= 0 or (expected_length is not None and expected_length != range_length):
                raise ValueError('Invalid FTPS verification range length')
            expected_length = range_length
        # curl's internal retries cannot discard partial stdout in a PIPE. Each
        # attempt is a fresh process/buffer; accept only a complete final result.
        message = ''
        retry_note = ''
        for attempt in range(3):
            if attempt:
                mode = 'upload' if local is not None else byte_range or 'whole'
                print(f'Retrying verified FTPS transfer: {name}; range {mode}; attempt {attempt + 1}/3; {retry_note}', flush=True)
            try:
                result = subprocess.run(command, input=config.encode('utf-8'), stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            except OSError as error:
                message = str(error)
                retry_note = 'process start failed'
                continue
            if result.returncode:
                message = result.stderr.decode('utf-8', errors='replace')
                retry_note = f'curl exit {result.returncode}'
                continue
            if local is None and expected_length is not None and len(result.stdout) != expected_length:
                message = f'Incomplete FTPS readback: expected {expected_length} bytes, received {len(result.stdout)}'
                retry_note = f'expected {expected_length} bytes, received {len(result.stdout)}'
                continue
            return result.stdout
        for value in [credentials['password'], credentials['user']]:
            if value:
                message = message.replace(value, '[redacted]')
        raise RuntimeError('Verified FTPS transfer failed: ' + name + ': ' + message)

    def upload_verified(name, local):
        curl_transfer(name, local)
        length = local.stat().st_size
        # This host can stall after one TLS record on larger RETR responses.
        # Bounded FTP ranges still verify every byte of the completed upload.
        if length > 16384:
            def verify_range(start):
                end = min(length - 1, start + 16383)
                part = curl_transfer(name, byte_range=f'{start}-{end}')
                if len(part) != end - start + 1:
                    raise RuntimeError('Incomplete uploaded file range: ' + name)
                return part
            with ThreadPoolExecutor(max_workers=4) as pool:
                parts = list(pool.map(verify_range, range(0, length, 16384)))
            content = b''.join(parts)
        else:
            content = curl_transfer(name, expected_length=length)
        if hashlib.sha256(content).digest() != hashlib.sha256(local.read_bytes()).digest():
            raise RuntimeError('Uploaded file verification failed: ' + name)

    try:
        for i, (name, local) in enumerate(files, 1):
            if name in unchanged:
                continue
            for attempt in range(3):
                try:
                    reconnect()
                    ensure_parent(name)
                    break
                except (OSError, EOFError, ftplib.error_temp):
                    if attempt == 2:
                        raise
            if name not in record['uploaded']:
                record['uploaded'].append(name)
            save_record()
            upload_verified(name, local)
            if i % 20 == 0 or i == len(files):
                print(f'Uploaded and verified {i}/{len(files)}', flush=True)
        print(f"Changed files uploaded and verified: {len(record['uploaded'])}; unchanged: {len(unchanged)}", flush=True)
        record['state'] = 'uploaded-and-verified'
        save_record()
    except Exception:
        record['state'] = 'failed-restoring'
        save_record()
        for name in record['uploaded']:
            if name in existing:
                reconnect()
                upload_verified(name, backup / name)
        record['state'] = 'previous-files-restored; new files retained'
        save_record()
        raise
    print('Deployment complete. Backup:', backup, flush=True)
    if manifest.get('artifact') == 'landing':
        import urllib.request
        public_origin = 'https://untouch.fun/'
        with urllib.request.urlopen(public_origin + 'release.json?build=' + manifest['buildId'], timeout=25) as response:
            identity = json.load(response)
        if identity.get('buildId') != manifest['buildId']:
            raise RuntimeError('HTTPS landing version mismatch')
        for name in ('index.html','neon.css','hero.css','demo.js','stores.js','media.js'):
            local = site / name
            if not local.is_file():
                continue
            with urllib.request.urlopen(public_origin + name + '?build=' + manifest['buildId'], timeout=25) as response:
                remote = response.read()
            if hashlib.sha256(remote).digest() != hashlib.sha256(local.read_bytes()).digest():
                raise RuntimeError('HTTPS landing content mismatch: ' + name)
        record['httpsVerified'] = True
        save_record()
        print('HTTPS landing build and entry files verified:', identity['buildId'], flush=True)
    if manifest.get('artifact') == 'legal':
        import urllib.request
        with urllib.request.urlopen('https://untouch.fun/legal-release.json', timeout=25) as response:
            identity = json.load(response)
        if identity.get('buildId') != manifest['buildId']:
            raise RuntimeError('HTTPS legal release version mismatch')
        for name, local in files:
            public_path = name[:-10] if name.endswith('index.html') else name
            url = 'https://untouch.fun/' + public_path
            expected_bytes = local.stat().st_size
            if expected_bytes > 16384:
                chunks = []
                for start in range(0, expected_bytes, 16384):
                    end = min(expected_bytes - 1, start + 16383)
                    request = urllib.request.Request(url, headers={'Range':f'bytes={start}-{end}', 'Accept-Encoding':'identity', 'Cache-Control':'no-cache'})
                    with urllib.request.urlopen(request, timeout=25) as response:
                        expected_range = f'bytes {start}-{end}/{expected_bytes}'
                        if response.status != 206 or response.headers.get('Content-Range') != expected_range:
                            raise RuntimeError('HTTPS legal range mismatch: ' + public_path)
                        chunk = response.read(end - start + 1)
                    if len(chunk) != end - start + 1:
                        raise RuntimeError('Incomplete HTTPS legal range: ' + public_path)
                    chunks.append(chunk)
                remote = b''.join(chunks)
            else:
                with urllib.request.urlopen(url, timeout=25) as response:
                    remote = response.read()
            if hashlib.sha256(remote).digest() != hashlib.sha256(local.read_bytes()).digest():
                raise RuntimeError('HTTPS legal content mismatch: ' + public_path)
        record['httpsVerified'] = True
        save_record()
        print('HTTPS legal pages and build verified:', identity['buildId'], flush=True)
    if manifest.get('artifact') == 'mobile-api':
        import urllib.request
        with urllib.request.urlopen('https://untouch.ballaball.xyz/api/mobile.php', timeout=20) as response:
            health=json.load(response)
        if health.get('buildId') != manifest['buildId']:
            raise RuntimeError('HTTPS mobile API version mismatch')
        record['httpsVerified']=True
        save_record()
        print('HTTPS mobile API build verified:', health['buildId'], flush=True)
if ftp.sock is not None:
    try:
        ftp.quit()
    except (OSError, EOFError, ftplib.error_temp):
        ftp.close()

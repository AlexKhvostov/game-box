"""Read-only HTTPS verification after the scoped FTPS game deployment."""
import argparse
import concurrent.futures
from datetime import datetime, timezone
import hashlib
import json
import pathlib
import urllib.parse
import urllib.request
import urllib.error
import time
import zipfile

parser = argparse.ArgumentParser()
parser.add_argument('--release', type=pathlib.Path, required=True)
parser.add_argument('--deployment-record', type=pathlib.Path, required=True)
parser.add_argument('--output', type=pathlib.Path, required=True)
args = parser.parse_args()
release = args.release.resolve()
manifest = json.loads((release/'manifest.json').read_text(encoding='utf-8-sig'))
record = json.loads(args.deployment_record.read_text(encoding='utf-8-sig'))
if record['state'] != 'uploaded-and-verified' or record['buildId'] != manifest['buildId']:
    raise ValueError('FTPS deployment is not fully verified')
backup_proof=None
if manifest.get('artifact') == 'telegram-native-launch':
    paths={item['path'] for item in manifest['files']}
    expected=manifest.get('expectedBeforeHashes',{})
    if set(expected) != paths or set(record['existing']) | set(record['absent']) != paths or set(record['uploaded']) != paths:
        raise ValueError('Incomplete patch backup/upload inventory')
    backup=args.deployment_record.resolve().parent
    archive=backup.with_suffix('.zip')
    with zipfile.ZipFile(archive) as zipped:
        if zipped.testzip() is not None or set(zipped.namelist()) != set(record['existing']) | {'deployment.json'}:
            raise ValueError('Backup ZIP CRC/inventory mismatch')
        for name,digest in expected.items():
            if digest is None:
                if name not in record['absent']: raise ValueError('New path was not proven absent')
            elif name not in record['existing'] or hashlib.sha256((backup/name).read_bytes()).hexdigest()!=digest or hashlib.sha256(zipped.read(name)).hexdigest()!=digest:
                raise ValueError('Backup before-hash differs: '+name)
    backup_proof={'existingFiles':len(record['existing']),'newFiles':len(record['absent']),'archive':str(archive.relative_to(release)),'archiveSHA256':hashlib.sha256(archive.read_bytes()).hexdigest(),'status':'PASS'}
origin = 'https://untouch.ballaball.xyz/'
nonce = manifest['buildId'] + '-https-proof'

def get(name, size=None, start=None, end=None, host=origin):
    url = host + urllib.parse.quote(name) + '?verify=' + nonce
    headers = {'Cache-Control': 'no-cache', 'Accept-Encoding': 'identity'}
    if start is not None: headers['Range'] = f'bytes={start}-{end}'
    for attempt in range(3):
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers=headers), timeout=25) as response:
                expected = size if start is None else end-start+1
                if start is not None and (response.status != 206 or response.headers.get('Content-Range') != f'bytes {start}-{end}/{size}'):
                    raise ValueError('Unexpected HTTPS range: '+name)
                data = response.read() if expected is None else response.read(expected+1)
            if expected is not None and len(data) != expected: raise ValueError('HTTPS size mismatch: '+name)
            return data
        except OSError:
            if attempt == 2: raise

identity = json.loads(get('release.json').decode('utf-8-sig'))
if identity.get('buildId') != manifest['buildId'] or identity.get('version') != manifest['version']:
    raise ValueError('Published game version differs')
if json.loads(get('version.json').decode('utf-8-sig')).get('version') != manifest['version']:
    raise ValueError('Published game version file differs')
public = [row for row in manifest['files'] if not row['path'].startswith('api/') and row['path'] != 'i.php' and not any(part.startswith('.') for part in pathlib.PurePosixPath(row['path']).parts)]

def verify(row):
    name, size = row['path'], row['bytes']
    local = release/'site'/name
    if hashlib.sha256(local.read_bytes()).hexdigest() != row['sha256']: raise ValueError('Local release drift')
    if size > 16384:
        data = b''.join(get(name,size,start,min(size-1,start+16383)) for start in range(0,size,16384))
    else: data = get(name,size)
    actual = hashlib.sha256(data).hexdigest()
    if actual != row['sha256']: raise ValueError('Published HTTPS hash differs: '+name)
    return {'path':name,'bytes':size,'sha256':actual,'status':'PASS'}

checked=[]
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
    for future in concurrent.futures.as_completed([pool.submit(verify,row) for row in public]):
        checked.append(future.result())
        if len(checked)%20==0: print(f'HTTPS files verified {len(checked)}/{len(public)}',flush=True)
args.output.parent.mkdir(parents=True,exist_ok=True)
checkpoint={'buildId':manifest['buildId'],'status':'public-hashes-verified; remaining checks pending','publicFiles':sorted(checked,key=lambda row:row['path'])}
args.output.write_text(json.dumps(checkpoint,indent=2),encoding='utf-8')
launch_checks=[]
if manifest.get('artifact') == 'telegram-native-launch':
    fake = urllib.parse.urlencode({'auth_date':str(int(time.time())), 'user':json.dumps({'id':1}), 'hash':'0'*64})
    for label, payload, expected, reason in [('GET denied',None,405,'method_not_allowed'), ('Telegram Web denied',{'platform':'web','initData':fake},403,'unsupported_platform'), ('Unsigned native denied',{'platform':'android','initData':fake},403,'invalid_launch')]:
        body = None if payload is None else json.dumps(payload).encode()
        request=urllib.request.Request(origin+'api/launch.php', data=body, headers={'Content-Type':'application/json','Cache-Control':'no-cache'})
        try:
            with urllib.request.urlopen(request,timeout=25) as response:
                status=response.status; data=json.load(response); headers=response.headers
        except urllib.error.HTTPError as response:
            status=response.code; data=json.load(response); headers=response.headers
        if status != expected or data.get('ok') is not False or data.get('error') != reason or 'no-store' not in headers.get('Cache-Control',''):
            raise ValueError('Published launch restriction failed: '+label)
        launch_checks.append({'check':label,'status':status,'result':'PASS'})
config = json.loads(get('api/config.php').decode('utf-8-sig'))
if not config.get('ok') or config.get('revision') != 'ddcca375631890786720d18132de3068f35dfd7aac53a2e340cdbd9be02665ef':
    raise ValueError('Published administrator config changed; reconcile separately')
if config.get('config',{}).get('mobileEnemies') != {'startSpeedSteps':30,'accelerationSteps':5}:
    raise ValueError('Android administrator enemy pace differs')
mobile = json.loads(get('api/mobile.php').decode('utf-8-sig'))
if mobile.get('buildId') != 'mobile-api-v1.0.17_20261013_130903_785':
    raise ValueError('Native mobile API identity changed; reconcile separately')
landing = json.loads(get('release.json',host='https://untouch.fun/').decode('utf-8-sig'))
if landing.get('version') != '1.0.68' or landing.get('buildId') != 'v1.0.68_20261014_203149_313134':
    raise ValueError('Separate landing identity changed; reconcile separately')
result={'updated':datetime.now(timezone.utc).isoformat(),'origin':origin,'buildId':manifest['buildId'],'version':manifest['version'],'status':'published-and-HTTPS-verified','summary':{'publicFiles':len(checked),'fail':0},'backupProof':backup_proof,'publicFiles':sorted(checked,key=lambda row:row['path']),'launchChecks':launch_checks,'FTPSFiles':len(manifest['files']),'administratorConfigRevision':config['revision'],'mobileEnemies':config['config'].get('mobileEnemies'),'nativeMobileBuildId':mobile['buildId'],'separateLandingBuildId':landing['buildId'],'limits':['No real Telegram/device/FPS/keyboard/payment/message test','API code hashes verified by FTPS; public APIs read only, no player writes']}
args.output.parent.mkdir(parents=True,exist_ok=True)
args.output.write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
record['httpsVerified']=True;record['httpsBuildId']=manifest['buildId'];record['httpsPublicFilesVerified']=len(checked)
args.deployment_record.write_text(json.dumps(record,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({'published':identity,'HTTPSFiles':len(checked),'FTPSFiles':len(manifest['files']),'mobileEnemies':result['mobileEnemies']},ensure_ascii=False),flush=True)

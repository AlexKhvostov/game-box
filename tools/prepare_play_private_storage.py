"""Read-only host storage probe. No key read/upload or Play activation."""
import argparse
from datetime import datetime, timezone
import io
import json
from pathlib import Path
import secrets
import sys
import urllib.request
import android_host_tools as host


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--directory', type=Path, required=True)
    args = parser.parse_args()
    folder = args.directory.resolve()
    host.check(folder.is_relative_to((host.ROOT / '.private').resolve()), 'Probe output must be private')
    folder.mkdir(parents=True, exist_ok=True)
    host.check(not (folder / 'storage-inspection.json').exists(), 'Do not replace a storage inspection')
    host.CREDENTIALS = json.load(sys.stdin)
    token = secrets.token_hex(32)
    endpoint = 'api/_play_storage_probe_' + secrets.token_hex(12) + '.php'
    template = (host.ROOT / 'tools/play_private_storage_probe.php').read_text(encoding='utf-8-sig')
    source = template.replace('__TOKEN__', token).replace('__EXPIRES__', str(int(datetime.now(timezone.utc).timestamp()) + 1200)).encode()
    ftp = host.connect()
    uploaded = False
    try:
        uploaded = True
        ftp.storbinary('STOR ' + endpoint, io.BytesIO(source))
        host.check(host.remote(endpoint) == source, 'Storage probe readback failed')
        request = urllib.request.Request(host.ORIGIN + endpoint, data=b'{}', headers={'X-Untouch-Test': token,'Content-Type':'application/json'})
        with urllib.request.urlopen(request, timeout=30) as response:
            result = json.load(response)
        host.check(result.get('ok') and result.get('readOnly'), 'Storage inspection rejected')
        host.save(folder / 'storage-inspection.json', result)
        print(json.dumps({name:result[name] for name in ['ok','readOnly','safeCandidate','outsideDocumentRoot','outsideActualSiteRoot','candidateWritable','keyRead','keyTransferred','directoriesCreated','privateConfigChanged']}))
    finally:
        ftp.close()
        if uploaded:
            cleanup = host.connect()
            try:
                if endpoint.rsplit('/',1)[1] in host.inventory('api'):
                    cleanup.delete(endpoint)
                host.check(endpoint.rsplit('/',1)[1] not in host.inventory('api'), 'Storage probe cleanup not confirmed')
            finally:
                cleanup.close()


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        print(json.dumps({'ok':False,'errorType':type(error).__name__,'error':'Storage inspection failed; no key transferred'}))
        sys.exit(1)

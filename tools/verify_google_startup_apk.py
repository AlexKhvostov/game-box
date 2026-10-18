"""Read-only APK integrity and signing continuity for the Google startup change."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import struct
import subprocess
import zipfile

p = argparse.ArgumentParser()
p.add_argument('apk', type=Path)
p.add_argument('--previous', required=True, type=Path)
p.add_argument('--out', required=True, type=Path)
p.add_argument('--direct-chooser', action='store_true')
a = p.parse_args()
sdk = Path('C:/Users/alexe/AppData/Local/Android/Sdk/build-tools/36.0.0')
env = os.environ.copy()
jbr = Path('C:/Program Files/Android/Android Studio/jbr')
if jbr.exists():
    env['JAVA_HOME'] = str(jbr)


def run(name, *args):
    result = subprocess.run([str(sdk / name), *map(str, args)], env=env,
        capture_output=True, text=True, encoding='utf-8', errors='replace')
    assert result.returncode == 0, name + ': ' + result.stderr
    return result.stdout


certificate = r'Signer #1 certificate SHA-256 digest: ([0-9a-f]+)'
old_sig = run('apksigner.bat', 'verify', '--print-certs', a.previous)
new_sig = run('apksigner.bat', 'verify', '--verbose', '--print-certs', a.apk)
old_key = re.search(certificate, old_sig).group(1)
new_key = re.search(certificate, new_sig).group(1)
assert new_key == old_key
assert 'Verified using v2 scheme (APK Signature Scheme v2): true' in new_sig
badging = run('aapt.exe', 'dump', 'badging', a.apk)
package, code, version = re.search(r"package: name='([^']+)' versionCode='([^']+)' versionName='([^']+)'", badging).groups()
assert package == 'com.best4u.untouch' and 'application-debuggable' not in badging
assert "sdkVersion:'24'" in badging and "targetSdkVersion:'36'" in badging
run('zipalign.exe', '-c', '-P', '16', '-v', '4', a.apk)
libs = []
with zipfile.ZipFile(a.apk) as z, zipfile.ZipFile(a.previous) as before:
    assert z.testzip() is None
    id_pattern = rb'[0-9]+-[a-zA-Z0-9-]+[.]apps[.]googleusercontent[.]com'
    current = z.read('lib/arm64-v8a/libapp.so')
    old = before.read('lib/arm64-v8a/libapp.so')
    ids = set(re.findall(id_pattern, current))
    assert len(ids) == 1 and ids == set(re.findall(id_pattern, old))
    startup_markers = ([b'google_startup_seen_v1', b'google-startup-progress', b'google-startup-game-input']
                       if a.direct_chooser else
                       [b'google_startup_seen_v1', b'google-startup-dialog', b'google-startup-connect', b'google-startup-skip'])
    for marker in startup_markers:
        assert marker in current, marker
    if a.direct_chooser:
        for marker in [b'google-startup-dialog', b'google-startup-connect', b'google-startup-skip']:
            assert marker not in current, marker
    for name in z.namelist():
        if not name.endswith('.so') or not name.startswith('lib/'):
            continue
        data = z.read(name)
        if data[4] != 2:
            continue
        endian = '<' if data[5] == 1 else '>'
        phoff = struct.unpack_from(endian + 'Q', data, 32)[0]
        size, count = struct.unpack_from(endian + 'HH', data, 54)
        alignments = [struct.unpack_from(endian + 'Q', data, phoff + i * size + 48)[0]
            for i in range(count) if struct.unpack_from(endian + 'I', data, phoff + i * size)[0] == 1]
        assert alignments and min(alignments) >= 16384
        libs.append({'path': name, 'minimumLoadAlignment': min(alignments)})
metadata = json.loads((a.apk.parent / 'build.json').read_text(encoding='utf-8-sig'))
digest = hashlib.sha256(a.apk.read_bytes()).hexdigest()
assert metadata['sha256'] == digest and metadata['versionName'] == version and metadata['versionCode'] == int(code)
assert metadata['googleIdentityConfigured'] and not metadata['testTools'] and not metadata['googlePlayBilling']
result = {'ok': True, 'artifact': str(a.apk), 'package': package, 'versionName': version,
    'versionCode': int(code), 'sha256': digest, 'signatureV2': True, 'sameSigningKeyAsPrevious': True,
    'googleClientMatchesPrevious': True, 'startupStringsPresent': True, 'debuggable': False,
    'directNativeChooser': a.direct_chooser,
    'zipCRCVerified': True, 'zipAlign16KBVerified': True, 'elf64Libraries': libs,
    'deviceTested': False, 'playPublished': False}
a.out.parent.mkdir(parents=True, exist_ok=True)
a.out.write_text(json.dumps(result, indent=2), encoding='utf-8')
print('PASS: signed APK', version + '+' + code, 'CRC/16KB/OAuth/startup markers; physical acceptance pending')

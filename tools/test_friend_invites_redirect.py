"""Loopback PHP redirect + source/association checks. Never follows Location to Play."""
import json
import os
from pathlib import Path
import re
import socket
import subprocess
import time
import urllib.error
import urllib.parse
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
LANDING = ROOT / 'telegram-web/landing'
PHP = Path(os.environ.get('UNTOUCH_INVITES_PHP', 'C:/xampp/php/php.exe'))
CODE = 'ABCDEFGH2345'


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def run():
    checks = []

    def check(value, label):
        if not value:
            raise AssertionError(label)
        checks.append(label)

    with socket.socket() as listener:
        listener.bind(('127.0.0.1', 0))
        port = listener.getsockname()[1]
    process = subprocess.Popen(
        [str(PHP), '-S', f'127.0.0.1:{port}', '-t', str(LANDING)],
        stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        creationflags=subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0,
    )
    opener = urllib.request.build_opener(NoRedirect())

    def request(path):
        try:
            response = opener.open(f'http://127.0.0.1:{port}{path}', timeout=3)
        except urllib.error.HTTPError as error:
            response = error
        return response.code, response.headers, response.read()

    try:
        for _ in range(60):
            try:
                request('/invite.php')
                break
            except urllib.error.URLError:
                if process.poll() is not None:
                    raise RuntimeError('Local PHP server exited')
                time.sleep(0.05)
        else:
            raise RuntimeError('Local PHP server did not start')
        expected = ('https://play.google.com/store/apps/details?id=com.best4u.untouch&referrer='
                    + urllib.parse.quote('invite=' + CODE, safe=''))
        for value in [CODE, CODE.lower(), ' ' + CODE + ' ']:
            status, headers, body = request('/invite.php?code=' + urllib.parse.quote(value))
            check(status == 302 and headers['Location'] == expected, '302 fixed Play URL with encoded invitation ' + repr(value))
            check(headers['Cache-Control'] == 'no-store' and headers['Referrer-Policy'] == 'no-referrer', 'redirect cache/referrer privacy ' + repr(value))
            check('Set-Cookie' not in headers and body == b'', 'no cookie or mandatory HTML step ' + repr(value))
        status, headers, _ = request('/invite.php?code=' + CODE + '&url=https://evil.test&referrer=other')
        check(status == 302 and headers['Location'] == expected, 'untrusted target/referrer query cannot replace fixed destination')
        for query in ['', 'code=', 'code=short', 'code[]=x', 'code=' + 'A'*65, 'code=' + CODE + '%0DX', 'code=123456789234']:
            status, headers, _ = request('/invite.php?' + query)
            check(status == 404 and 'Location' not in headers, 'invalid input has no redirect: ' + query)
        status, headers, body = request('/.well-known/assetlinks.json')
        check(status == 200 and headers.get_content_type() == 'application/json', 'association JSON served locally with correct MIME')
        statement = json.loads(body)[0]
        check(statement['relation'] == ['delegate_permission/common.handle_all_urls'], 'association handle-all-urls relation')
        check(statement['target']['package_name'] == 'com.best4u.untouch', 'only production package associated; no probe/debug package')
        expected_fingerprints = [
            'A1:28:21:30:E3:01:EB:AB:B4:4F:88:04:F4:A6:F6:9A:E9:8D:3D:E9:E4:64:F5:6A:03:4C:9D:A0:F1:F0:D7:01',
            'D1:E6:C2:45:77:DE:48:70:86:09:38:C0:AC:F5:C8:4F:03:9F:2A:74:0D:AA:0C:02:A3:33:42:B2:3B:9E:CD:DE',
        ]
        check(statement['target']['sha256_cert_fingerprints'] == expected_fingerprints, 'recorded Play/install and local upload fingerprints kept distinct')
        for fingerprint in expected_fingerprints:
            check(re.fullmatch(r'(?:[A-F0-9]{2}:){31}[A-F0-9]{2}', fingerprint) is not None, 'fingerprint exact SHA256 format ' + fingerprint[:5])
        rewrite = (LANDING / '.htaccess').read_text(encoding='utf-8')
        rule = next(line.strip() for line in rewrite.splitlines() if line.strip().startswith('RewriteRule'))
        pattern, target, flags = rule.split()[1:]
        check(target == 'invite.php?code=$1' and flags == '[L,NC]', 'isolated route overwrites query without QSA or arbitrary destination')
        check(re.fullmatch(pattern, 'a/' + CODE, flags=re.IGNORECASE) is not None, 'scoped a/code rewrite pattern matches valid code')
        for path in ['i/' + CODE, 'privacy/', 'a/short', 'a/' + CODE + '/more']:
            check(re.fullmatch(pattern, path, flags=re.IGNORECASE) is None, 'rewrite excludes unrelated/invalid path ' + path)
        return {'ok': True, 'checks': len(checks), 'passed': checks,
                'localPhpHttp': True, 'actualApacheRewrite': False, 'publicDomainVerified': False,
                'actualAndroidAppLinks': False, 'realPlayInstallReferrer': False}
    finally:
        process.terminate()
        try:
            process.wait(timeout=3)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=3)


if __name__ == '__main__':
    print(json.dumps(run(), ensure_ascii=False, indent=2))

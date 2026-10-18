"""Shared FTPS/DPAPI helpers for Android maintenance; no resource grants."""
from concurrent.futures import ThreadPoolExecutor
import ctypes
import ftplib
import hashlib
import json
from pathlib import Path
import ssl
import subprocess
import tempfile
import urllib.error
import urllib.parse
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
ORIGIN = 'https://untouch.ballaball.xyz/'
CREDENTIALS = None


def check(condition, message):
    if not condition:
        raise RuntimeError(message)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def save(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


def read_json(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def connect():
    context = ssl.create_default_context()
    context.maximum_version = ssl.TLSVersion.TLSv1_2
    ftp = ftplib.FTP_TLS(context=context, timeout=30)
    try:
        ftp.connect(CREDENTIALS['host'], int(CREDENTIALS.get('port', 21)))
        ftp.auth()
        ftp.login(CREDENTIALS['user'], CREDENTIALS['password'])
        ftp.prot_p()
        ftp.cwd('/')
        return ftp
    except Exception:
        ftp.close()
        raise


def inventory(folder):
    ftp = connect()
    try:
        return {name: facts for name, facts in ftp.mlsd(folder)
                if facts.get('type') not in ('cdir', 'pdir')}
    finally:
        ftp.close()


def download(name, length):
    check(not name.startswith('/') and '..' not in name.split('/'), 'Remote path invalid')
    if not length:
        return b''
    cfg = ('url = ' + json.dumps('ftp://' + CREDENTIALS['host'] + '/' + urllib.parse.quote(name)) +
           '\nuser = ' + json.dumps(CREDENTIALS['user'] + ':' + CREDENTIALS['password']) + '\n')

    def chunk(start):
        end = min(length - 1, start + 16383)
        command = ['curl.exe', '--config', '-', '--ssl-reqd', '--tls-max', '1.2',
                   '--disable-epsv', '--silent', '--show-error', '--connect-timeout', '15',
                   '--max-time', '45', '--range', f'{start}-{end}']
        for _ in range(3):
            result = subprocess.run(command, input=cfg.encode(), capture_output=True)
            if result.returncode == 0 and len(result.stdout) == end - start + 1:
                return result.stdout
        raise RuntimeError('Incomplete verified FTPS read: ' + name)

    try:
        with ThreadPoolExecutor(max_workers=2) as pool:
            content = b''.join(pool.map(chunk, range(0, length, 16384)))
    except RuntimeError:
        # Some host sessions reject REST ranges; a complete fresh read is safe.
        ftp = connect()
        try:
            chunks = []
            ftp.retrbinary('RETR ' + name, chunks.append)
            content = b''.join(chunks)
        finally:
            ftp.close()
    check(len(content) == length, 'Incomplete FTPS file: ' + name)
    return content


def remote(name):
    parent, base = name.rsplit('/', 1)
    row = inventory(parent).get(base)
    check(row is not None and row.get('type') == 'file', 'Remote file missing: ' + name)
    return download(name, int(row['size']))


class Blob(ctypes.Structure):
    _fields_ = [('size', ctypes.c_ulong), ('data', ctypes.POINTER(ctypes.c_ubyte))]


def crypt(data, decrypt=False):
    buffer = ctypes.create_string_buffer(data)
    source = Blob(len(data), ctypes.cast(buffer, ctypes.POINTER(ctypes.c_ubyte)))
    target = Blob()
    api = ctypes.windll.crypt32
    if decrypt:
        ok = api.CryptUnprotectData(ctypes.byref(source), None, None, None, None, 1, ctypes.byref(target))
    else:
        ok = api.CryptProtectData(ctypes.byref(source), None, None, None, None, 1, ctypes.byref(target))
    if not ok:
        raise ctypes.WinError()
    try:
        return ctypes.string_at(target.data, target.size)
    finally:
        ctypes.windll.kernel32.LocalFree(target.data)


def backup_bytes(path, data):
    check(not path.exists(), 'Do not overwrite a backup')
    encrypted = crypt(data)
    check(crypt(encrypted, True) == data, 'DPAPI roundtrip failed')
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(encrypted)
    return {'bytes': len(data), 'sha256': sha(data), 'encryptedSha256': sha(encrypted),
            'dpapiRoundtripVerified': True}


def public(name):
    request = urllib.request.Request(ORIGIN + name, headers={'Cache-Control': 'no-cache'})
    with urllib.request.urlopen(request, timeout=30) as response:
        return json.load(response)


def denied(name):
    try:
        with urllib.request.urlopen(ORIGIN + name, timeout=20) as response:
            return response.status in (403, 404)
    except urllib.error.HTTPError as error:
        return error.code in (403, 404)


class CurlFTPS:
    """Verified Schannel client for hosts whose TLS handshake stalls in OpenSSL."""
    def request(self, name, arguments=()):
        return self.request_batch([(name, arguments)])

    def request_batch(self, transfers):
        sections = []
        for name, arguments in transfers:
            check(not name.startswith('/') and '..' not in name.split('/'), 'Remote path invalid')
            section = ['ssl-reqd', 'tls-max = "1.2"', 'disable-epsv', 'silent', 'show-error',
                'connect-timeout = 12', 'max-time = 45',
                'url = ' + json.dumps('ftp://' + CREDENTIALS['host'] + '/' + urllib.parse.quote(name)),
                'user = ' + json.dumps(CREDENTIALS['user'] + ':' + CREDENTIALS['password'])]
            index = 0
            while index < len(arguments):
                option = arguments[index].removeprefix('--')
                if option in ('range', 'request', 'upload-file', 'quote'):
                    section.append(option + ' = ' + json.dumps(arguments[index + 1]))
                    index += 2
                else:
                    check(option == 'list-only', 'Unsupported FTPS option')
                    section.append(option)
                    index += 1
            sections.append('\n'.join(section))
        cfg = '\nnext\n'.join(sections) + '\n'
        command = ['curl.exe', '--fail-early', '--config', '-']
        result = subprocess.run(command, input=cfg.encode(), capture_output=True)
        check(result.returncode == 0, f'FTPS request failed (curl {result.returncode}, received {len(result.stdout)} bytes)')
        return result.stdout

    def mlsd(self, folder):
        data = self.request(folder.rstrip('/') + '/', ('--request', 'MLSD'))
        for line in data.decode('utf-8').splitlines():
            facts, name = line.split(' ', 1)
            yield name, dict(pair.split('=', 1) for pair in facts.split(';') if '=' in pair)

    def storbinary(self, command, stream):
        check(command.startswith('STOR '), 'Only explicit STOR supported')
        directory = ROOT / '.private/ftps-transfer'
        directory.mkdir(exist_ok=True)
        with tempfile.NamedTemporaryFile(dir=directory, suffix='.bin', delete=False) as file:
            path = Path(file.name)
            file.write(stream.read())
        try:
            self.request(command[5:], ('--upload-file', str(path)))
        finally:
            path.unlink()

    def delete(self, name):
        check(name.startswith(('api/_simple_energy_operator_', 'api/config-data/_sb_stage_')),
              'Delete is limited to this operator temporary files')
        self.request('', ('--quote', 'DELE ' + name, '--list-only'))

    def close(self):
        pass


def curl_download(name, length):
    # Bounded ranges avoid this host's large-transfer data socket issue.
    client = CurlFTPS()
    transfers = []
    for start in range(0, length, 8192):
        end = min(length - 1, start + 8191)
        transfers.append((name, ('--range', f'{start}-{end}')))
    if not transfers:
        return b''
    content = client.request_batch(transfers)
    check(len(content) == length, 'FTPS file length mismatch: ' + name)
    return content

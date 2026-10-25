"""Local-only QA receiver and DPAPI key handoff. Never prints a key or request body."""
import argparse
import ctypes
import ctypes.wintypes
import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs


def protect(data: bytes) -> bytes:
    class Blob(ctypes.Structure):
        _fields_ = [('size', ctypes.wintypes.DWORD), ('data', ctypes.POINTER(ctypes.c_byte))]
    memory = ctypes.create_string_buffer(data)
    source = Blob(len(data), ctypes.cast(memory, ctypes.POINTER(ctypes.c_byte)))
    target = Blob()
    if not ctypes.windll.crypt32.CryptProtectData(
        ctypes.byref(source), 'Untouch AppMetrica QA', None, None, None, 0, ctypes.byref(target)
    ):
        raise ctypes.WinError()
    try:
        return ctypes.string_at(target.data, target.size)
    finally:
        ctypes.windll.kernel32.LocalFree(target.data)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--port', type=int, default=8883)
    parser.add_argument('--secret-path', required=True)
    parser.add_argument('--evidence', required=True)
    args = parser.parse_args()
    secret = Path(args.secret_path)
    evidence = Path(args.evidence)
    events = []

    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *unused):
            pass

        def reply(self, body, content_type='application/json'):
            payload = body.encode('utf-8') if isinstance(body, str) else json.dumps(body).encode('utf-8')
            self.send_response(200)
            self.send_header('Content-Type', content_type)
            self.send_header('Cache-Control', 'no-store')
            self.end_headers()
            self.wfile.write(payload)

        def do_GET(self):
            if self.path == '/key':
                self.reply('<html><body><h1>Untouch QA key storage</h1>'
                           '<form method="post" action="/key"><label>SDK API key '
                           '<input type="password" name="key" autocomplete="off"></label>'
                           '<button>Save encrypted locally</button></form></body></html>', 'text/html; charset=utf-8')
            elif self.path == '/state':
                self.reply({'keyStored': secret.exists(), 'events': events})
            else:
                self.send_error(404)

        def do_POST(self):
            size = int(self.headers.get('Content-Length', '0'))
            if size > 65536:
                self.send_error(413)
                return
            raw = self.rfile.read(size)
            if self.path == '/key':
                key = parse_qs(raw.decode('utf-8')).get('key', [''])[0].strip()
                import re
                if not re.fullmatch(r'[0-9a-fA-F-]{36}', key):
                    self.send_error(400)
                    return
                secret.parent.mkdir(parents=True, exist_ok=True)
                secret.write_bytes(protect(key.encode('utf-8')))
                self.reply('<h1>QA key stored with Windows DPAPI</h1>', 'text/html; charset=utf-8')
            elif self.path == '/events':
                event = json.loads(raw)
                if len(events) < 2000:
                    events.append(event)
                    evidence.parent.mkdir(parents=True, exist_ok=True)
                    evidence.write_text(json.dumps(events, indent=2), encoding='utf-8')
                self.reply({'received': True})
            else:
                self.send_error(404)

    print('QA receiver ready on loopback; API keys are never logged', flush=True)
    ThreadingHTTPServer(('127.0.0.1', args.port), Handler).serve_forever()


if __name__ == '__main__':
    main()

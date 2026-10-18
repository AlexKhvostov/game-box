"""Prepare/apply one Google audience setting; preserve the host's private config."""
import hashlib
import io
import pathlib
import re
from datetime import datetime, timezone


def candidate_config(original, client_id):
    if not re.fullmatch(r'[A-Za-z0-9.-]+\.apps\.googleusercontent\.com', client_id):
        raise ValueError('Invalid Google Web client ID')
    if original is None:
        return ("<?php\nreturn ['google_web_client_id' => '" + client_id + "'];\n").encode()
    text = original.decode('utf-8-sig')
    pattern = r"(['\"])google_web_client_id\1\s*=>\s*(['\"])[^'\"\r\n]*\2"
    matches = list(re.finditer(pattern, text))
    if len(matches) != 1:
        raise ValueError('Expected one literal google_web_client_id; manual review required')
    match = matches[0]
    replacement = "'google_web_client_id' => '" + client_id + "'"
    return (text[:match.start()] + replacement + text[match.end():]).encode('utf-8')


def read_config(ftp):
    data = io.BytesIO()
    try:
        ftp.retrbinary('RETR api/mobile_config.php', data.write)
    except Exception as error:
        # Never treat a permission/connection error as a missing file.
        import ftplib
        if isinstance(error, ftplib.error_perm) and str(error).startswith('550'):
            names = ftp.nlst('api')
            if not any(pathlib.PurePosixPath(name).name == 'mobile_config.php' for name in names):
                return None
        raise
    return data.getvalue()


def run(ftp, client_id, apply=False, prepared=None):
    root = pathlib.Path(__file__).resolve().parent.parent
    private_root = (root / '.private/google-signin').resolve()
    protection = io.BytesIO()
    ftp.retrbinary('RETR api/.htaccess', protection.write)
    protection_bytes = protection.getvalue()
    protection_text = protection_bytes.decode('utf-8-sig')
    deny_patterns = re.findall(r'<FilesMatch\s+"([^"]+)">\s*Require all denied\s*</FilesMatch>', protection_text)
    if not any(re.fullmatch(pattern, 'mobile_config.php') for pattern in deny_patterns):
        raise ValueError('Host private config access protection is not verified')
    original = read_config(ftp)
    proposed = candidate_config(original, client_id)
    old_hash = hashlib.sha256(original).hexdigest() if original is not None else None
    if not apply:
        import json
        stamp = datetime.now(timezone.utc).strftime('%Y%m%d_%H%M%S_%f')
        folder = private_root / stamp
        folder.mkdir(parents=True)
        if original is not None:
            (folder / 'mobile_config.before.php').write_bytes(original)
        (folder / 'mobile_config.candidate.php').write_bytes(proposed)
        (folder / 'plan.json').write_text(json.dumps({
            'beforeSha256': old_hash,
            'candidateSha256': hashlib.sha256(proposed).hexdigest(),
            'googleWebClientId': client_id,
            'createdAt': stamp,
            'protectionSha256': hashlib.sha256(protection_bytes).hexdigest(),
        }, indent=2), encoding='utf-8')
        print('Prepared private Google setting:', folder, flush=True)
        print('Existing config:', original is not None, '; production changed: false', flush=True)
        return
    import json
    if prepared is None:
        raise ValueError('Apply requires the reviewed preparation directory')
    folder = pathlib.Path(prepared).resolve()
    if not folder.is_relative_to(private_root):
        raise ValueError('Preparation must be inside the private Google directory')
    plan = json.loads((folder / 'plan.json').read_text(encoding='utf-8'))
    saved = (folder / 'mobile_config.candidate.php').read_bytes()
    if plan['beforeSha256'] != old_hash or plan['googleWebClientId'] != client_id:
        raise ValueError('Host configuration changed after preparation; prepare again')
    if plan['protectionSha256'] != hashlib.sha256(protection_bytes).hexdigest():
        raise ValueError('Host access protection changed after preparation')
    if saved != proposed or hashlib.sha256(saved).hexdigest() != plan['candidateSha256']:
        raise ValueError('Prepared configuration integrity mismatch')
    # The before image remains private on this computer. Never upload .before.php
    # or other backup filenames that could expose PHP source through HTTP.
    ftp.storbinary('STOR api/mobile_config.php', io.BytesIO(saved))
    if read_config(ftp) != saved:
        raise RuntimeError('Private setting verification failed; use reviewed backup to restore')
    print('Private Google setting applied and read-back verified; other settings preserved', flush=True)

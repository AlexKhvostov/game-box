"""Offline tests only: no credential read, FTPS, Google calls or real keys."""
import base64
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import setup_play_verifier as setup


class PlaySetupTests(unittest.TestCase):
    def test_metadata_valid(self):
        data = json.dumps(dict(type='service_account', project_id='game-box-b30d4', token_uri='https://oauth2.googleapis.com/token',
                     client_email='untouch-play-verifier@game-box-b30d4.iam.gserviceaccount.com', private_key='-----BEGIN PRIVATE KEY-----' + 'X' * 1400)).encode()
        setup.validate_key(data)

    def test_foreign_project_and_oauth_rejected(self):
        for field, value in [('project_id', 'foreign'), ('token_uri', 'https://evil.invalid'), ('client_email', 'test@foreign.invalid'), ('client_email', 'other@game-box-b30d4.iam.gserviceaccount.com')]:
            data = dict(type='service_account', project_id='game-box-b30d4', token_uri='https://oauth2.googleapis.com/token',
                        client_email='untouch-play-verifier@game-box-b30d4.iam.gserviceaccount.com', private_key='-----BEGIN PRIVATE KEY-----' + 'X' * 1400)
            data[field] = value
            with self.assertRaises(RuntimeError):
                setup.validate_key(json.dumps(data).encode())

    def test_no_activation_action(self):
        source = (setup.host.ROOT / 'tools/play_verifier_setup_operator.php').read_text()
        self.assertNotIn("$action==='activate'", source)
        self.assertNotIn('var_export(', source)
        self.assertNotIn('file_put_contents(', source)
        self.assertIn("empty($private['play_service_account_path'])", source)

    def test_atomic_no_clobber_and_private_permissions(self):
        source = (setup.host.ROOT / 'tools/play_verifier_setup_operator.php').read_text()
        self.assertIn('@link($temporary,$target)', source)
        self.assertIn("fopen($temporary,'x+b')", source)
        self.assertIn('@chmod($temporary,0600)', source)
        self.assertIn('@chmod($path,0700)', source)
        self.assertIn('finally{if(is_resource($handle))', source)
        self.assertNotIn('rename(', source)

    def test_catalog_readonly_fixed_scope(self):
        source = (setup.host.ROOT / 'tools/play_verifier_setup_operator.php').read_text()
        self.assertIn('oneTimeProducts/', source)
        self.assertIn('subscriptions/', source)
        self.assertNotIn('CURLOPT_POST', source)
        self.assertNotIn('mobile_play_verify(', source)
        self.assertNotIn('tg_connect_pdo(', source)

    def test_partial_stor_is_cleaned(self):
        with tempfile.TemporaryDirectory(prefix='play-setup-offline-') as directory:
            folder = Path(directory)
            template = (setup.host.ROOT / 'tools/play_verifier_setup_operator.php').read_bytes()
            baseline = {'files': {name.removeprefix('api/'): setup.host.sha(b'baseline') for name in setup.FILES}, 'keySha256': setup.host.sha(b'fake')}
            (folder / 'prepared.json').write_text(json.dumps({'baseline': baseline, 'operatorSha256': setup.host.sha(template)}))
            (folder / 'service-account.dpapi').write_bytes(b'encryptedfake')
            calls = []
            class FTP:
                def storbinary(self, command, stream):
                    calls.append('partial-STOR')
                    raise OSError('partial write')
                def close(self): pass
                def delete(self, name): calls.append('DELETE')
            def inventory(name):
                # Name is dynamic; capture it from mocked secrets.
                return {'_play_setup_' + 'a' * 24 + '.php': {}} if 'DELETE' not in calls else {}
            with patch.object(setup.host, 'remote', return_value=b'baseline'), patch.object(setup.host, 'crypt', return_value=b'fake'), \
                 patch.object(setup, 'validate_key'), patch.object(setup.host, 'connect', return_value=FTP()), \
                 patch.object(setup.host, 'inventory', side_effect=inventory), patch.object(setup.secrets, 'token_hex', side_effect=lambda size: 'a' * (size * 2)):
                with self.assertRaises(OSError):
                    setup.run_endpoint(folder, 'verify_key', False)
            self.assertEqual(calls, ['partial-STOR', 'DELETE'])

    def test_install_requires_explicit_gate_before_upload(self):
        with tempfile.TemporaryDirectory(prefix='play-setup-offline-') as directory:
            folder = Path(directory)
            template = (setup.host.ROOT / 'tools/play_verifier_setup_operator.php').read_bytes()
            baseline = {'files': {name.removeprefix('api/'): setup.host.sha(b'baseline') for name in setup.FILES}, 'keySha256': setup.host.sha(b'fake')}
            (folder / 'prepared.json').write_text(json.dumps({'baseline': baseline, 'operatorSha256': setup.host.sha(template)}))
            (folder / 'service-account.dpapi').write_bytes(b'encryptedfake')
            with patch.object(setup.host, 'remote', return_value=b'baseline'), patch.object(setup.host, 'crypt', return_value=b'fake'), \
                 patch.object(setup, 'validate_key'), patch.object(setup.host, 'connect') as connect:
                with self.assertRaises(RuntimeError): setup.run_endpoint(folder, 'install_key', False)
                connect.assert_not_called()

    def test_baseline_change_rejects_before_key_upload(self):
        with tempfile.TemporaryDirectory(prefix='play-setup-offline-') as directory:
            folder = Path(directory)
            template = (setup.host.ROOT / 'tools/play_verifier_setup_operator.php').read_bytes()
            baseline = {'files': {name.removeprefix('api/'): setup.host.sha(b'original') for name in setup.FILES}}
            (folder / 'prepared.json').write_text(json.dumps({'baseline': baseline, 'operatorSha256': setup.host.sha(template)}))
            with patch.object(setup.host, 'remote', return_value=b'changed'), patch.object(setup.host, 'connect') as connect:
                with self.assertRaises(RuntimeError): setup.run_endpoint(folder, 'install_key', True)
                connect.assert_not_called()


if __name__ == '__main__':
    unittest.main()

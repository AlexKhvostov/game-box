import unittest
import contextlib
import ftplib
import io
import pathlib
import tempfile
from unittest.mock import patch
from configure_mobile_google import candidate_config, run


class HostFixture:
    def __init__(self):
        self.files = {'api/.htaccess': b'<FilesMatch "^(db_config|bot_config|mobile_config)\\.php$">\nRequire all denied\n</FilesMatch>'}
        self.writes = 0

    def retrbinary(self, command, callback):
        name = command.removeprefix('RETR ')
        if name not in self.files:
            raise ftplib.error_perm('550 File not found')
        callback(self.files[name])

    def nlst(self, directory):
        return list(self.files)

    def storbinary(self, command, data):
        self.writes += 1
        self.files[command.removeprefix('STOR ')] = data.read()


class GoogleConfigurationTests(unittest.TestCase):
    def test_prepare_is_read_only_and_apply_detects_host_changes(self):
        client_id = '123-test.apps.googleusercontent.com'
        with tempfile.TemporaryDirectory(prefix='untouch-google-config-test-') as directory:
            host = HostFixture()
            root = pathlib.Path(directory)
            with patch('configure_mobile_google.__file__', str(root / 'tools/configure_mobile_google.py')), contextlib.redirect_stdout(io.StringIO()):
                run(host, client_id)
                self.assertEqual(host.writes, 0)
                prepared = next((root / '.private/google-signin').iterdir())
                host.files['api/mobile_config.php'] = b"<?php return ['google_web_client_id'=>'changed.apps.googleusercontent.com'];"
                with self.assertRaises(ValueError):
                    run(host, client_id, apply=True, prepared=prepared)
                self.assertEqual(host.writes, 0)
                del host.files['api/mobile_config.php']
                host.files['api/.htaccess'] += b'\n# changed\n'
                with self.assertRaises(ValueError):
                    run(host, client_id, apply=True, prepared=prepared)
                self.assertEqual(host.writes, 0)
                host.files['api/.htaccess'] = host.files['api/.htaccess'].removesuffix(b'\n# changed\n')
                run(host, client_id, apply=True, prepared=prepared)
                self.assertEqual(host.writes, 1)
                self.assertEqual(host.files['api/mobile_config.php'], candidate_config(None, client_id))

    def test_missing_private_file_protection_prevents_preparation(self):
        host = HostFixture()
        host.files['api/.htaccess'] = b'# no file protection'
        with self.assertRaises(ValueError):
            run(host, '123-test.apps.googleusercontent.com')
        self.assertEqual(host.writes, 0)

    def test_new_config_contains_only_the_google_setting(self):
        self.assertEqual(candidate_config(None, '123-test.apps.googleusercontent.com'),
                         b"<?php\nreturn ['google_web_client_id' => '123-test.apps.googleusercontent.com'];\n")

    def test_preserves_unrelated_host_settings(self):
        original = b"<?php\nreturn ['google_web_client_id' => '', 'play_service_account_path' => '/private/existing', 'custom' => 42];\n"
        candidate = candidate_config(original, '123-test.apps.googleusercontent.com')
        self.assertEqual(candidate, original.replace(b"'google_web_client_id' => ''", b"'google_web_client_id' => '123-test.apps.googleusercontent.com'"))

    def test_duplicate_or_dynamic_configuration_requires_review(self):
        for original in [b"<?php return [];", b"<?php return ['google_web_client_id'=>getenv('ID')];",
                         b"<?php return ['google_web_client_id'=>'', 'google_web_client_id'=>''];"]:
            with self.subTest(original=original):
                with self.assertRaises(ValueError):
                    candidate_config(original, '123-test.apps.googleusercontent.com')

    def test_client_id_cannot_inject_php(self):
        for client_id in ["'; phpinfo(); //", 'invalid', 'test.apps.googleusercontent.com\n']:
            with self.assertRaises(ValueError):
                candidate_config(None, client_id)


if __name__ == '__main__':
    unittest.main()

"""Offline FTPS transport and delivery guards. No host or wallet mutations."""
from datetime import datetime, timezone, timedelta
import io
import json
from pathlib import Path
import subprocess
import sys
import unittest
from unittest.mock import patch
import android_host_tools as host
import deploy_simple_energy as op


class DeliveryTests(unittest.TestCase):
    def setUp(self):
        self.credentials = patch.object(host, 'CREDENTIALS', {
            'host': 'example.invalid', 'user': 'fixture-user', 'password': 'fixture-secret'})
        self.credentials.start()
        self.addCleanup(self.credentials.stop)

    def test_verified_batch_keeps_credentials_off_command_line(self):
        with patch.object(host.subprocess, 'run', return_value=subprocess.CompletedProcess([], 0, b'abc', b'')) as run:
            self.assertEqual(host.CurlFTPS().request_batch([
                ('api/a.php', ('--range', '0-0')), ('api/a.php', ('--range', '1-2'))]), b'abc')
        args, kwargs = run.call_args
        self.assertNotIn('fixture-secret', ' '.join(args[0]))
        config = kwargs['input'].decode()
        self.assertEqual(config.count('ssl-reqd'), 2)
        self.assertEqual(config.count('tls-max = "1.2"'), 2)
        self.assertEqual(config.count('\nnext\n'), 1)
        self.assertNotIn('insecure', config)
        self.assertIn('--fail-early', args[0])

    def test_range_download_is_one_reused_control_session(self):
        with patch.object(host.CurlFTPS, 'request_batch', return_value=b'a' * 17000) as request:
            self.assertEqual(len(host.curl_download('api/example.php', 17000)), 17000)
        self.assertEqual(request.call_args.args[0], [
            ('api/example.php', ('--range', '0-8191')),
            ('api/example.php', ('--range', '8192-16383')),
            ('api/example.php', ('--range', '16384-16999'))])

    def test_truncated_transfer_is_rejected(self):
        with patch.object(host.CurlFTPS, 'request_batch', return_value=b'short'):
            with self.assertRaisesRegex(RuntimeError, 'length mismatch'):
                host.curl_download('api/example.php', 20)

    def test_mlsd_uses_exact_names_and_sizes(self):
        raw = b'type=file;size=123;modify=20261016000000; mobile_store.php\r\ntype=dir;size=0; config-data\r\n'
        with patch.object(host.CurlFTPS, 'request', return_value=raw):
            rows = dict(host.CurlFTPS().mlsd('api'))
        self.assertEqual(rows['mobile_store.php']['size'], '123')
        self.assertEqual(rows['config-data']['type'], 'dir')

    def test_private_settings_cannot_be_deleted(self):
        with patch.object(host.CurlFTPS, 'request', side_effect=AssertionError('No network')):
            for name in ('api/mobile_config.php', 'api/config-data/published.json', 'api/mobile.php'):
                with self.assertRaisesRegex(RuntimeError, 'Delete is limited'):
                    host.CurlFTPS().delete(name)

    def test_invalid_path_rejected_before_transfer(self):
        with patch.object(host.subprocess, 'run', side_effect=AssertionError('No network')):
            for name in ('/api/a.php', '../api/a.php', 'api/../a.php'):
                with self.assertRaisesRegex(RuntimeError, 'path invalid'):
                    host.CurlFTPS().request(name)

    def test_network_error_does_not_print_credentials(self):
        with patch.object(host.subprocess, 'run', return_value=subprocess.CompletedProcess([], 28, b'', b'fixture-secret')):
            with self.assertRaises(RuntimeError) as caught:
                host.CurlFTPS().request('api/')
        self.assertNotIn('fixture-secret', str(caught.exception))

    def test_expired_and_future_baselines_rejected(self):
        for date in (datetime.now(timezone.utc) - timedelta(minutes=31), datetime.now(timezone.utc) + timedelta(minutes=1)):
            with self.assertRaisesRegex(RuntimeError, 'Baseline expired'):
                op.fresh({'createdAtUtc': date.isoformat()})

    def test_no_write_without_explicit_switch(self):
        for mode in ('apply', 'activate'):
            with patch.object(sys, 'argv', ['operator', mode, '--directory', '.private/fixture', '--package', 'releases/fixture']), \
                 patch.object(sys, 'stdin', io.StringIO('invalid')), \
                 patch.object(host, 'connect', side_effect=AssertionError('No network')):
                with self.assertRaisesRegex(RuntimeError, 'Explicit --allow-write'):
                    op.main()


if __name__ == '__main__':
    unittest.main(verbosity=2)

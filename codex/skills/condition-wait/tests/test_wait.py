import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import threading
import time
import unittest

SCRIPT = Path(__file__).parents[1] / 'scripts/wait.py'
spec = importlib.util.spec_from_file_location('condition_wait', SCRIPT)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class WaitTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.path = Path(self.directory.name) / 'status.json'

    def wait(self, **extra):
        return module.wait_for_file(dict(path=str(self.path), mode='exists',
                                        timeout_seconds=0.5, interval_seconds=0.1, **extra))

    def test_delayed_creation(self):
        timer = threading.Timer(0.05, lambda: self.path.write_text('ready'))
        timer.start()
        self.assertEqual(self.wait()['reason'], 'matched')
        timer.join()

    def test_timeout(self):
        result = self.wait()
        self.assertEqual(result['reason'], 'timeout')
        self.assertGreaterEqual(result['elapsed_seconds'], 0.49)

    def test_exact_nested_json_and_cli_required_expected(self):
        self.assertFalse(module.json_equal({'x': [True]}, {'x': [1]}))
        self.assertTrue(module.json_equal({'x': [True]}, {'x': [True]}))
        self.path.write_text('null')
        result = subprocess.run([sys.executable, str(SCRIPT), '--path', str(self.path),
                                 '--mode', 'json_equals', '--timeout-seconds', '0'], capture_output=True, text=True)
        self.assertEqual(result.returncode, 2)

    def test_no_matching_after_deadline(self):
        real_wait = threading.Event.wait
        event = threading.Event()
        def late_wait(seconds):
            real_wait(event, seconds + 0.03)
            self.path.write_text('late')
        event.wait = late_wait
        result = module.wait_for_file(dict(path=str(self.path), mode='exists',
                                          timeout_seconds=0.02, interval_seconds=0.1), event)
        self.assertEqual(result['reason'], 'timeout')

    def test_json_retry_and_privacy(self):
        self.path.write_text('{')
        timer = threading.Timer(0.05, lambda: self.path.write_text('{"state":"ready","secret":"do-not-return"}'))
        timer.start()
        result = module.wait_for_file(dict(path=str(self.path), mode='json_equals', keys=['state'],
                         expected='ready', timeout_seconds=1, interval_seconds=0.1))
        timer.join()
        self.assertEqual(result['reason'], 'matched')
        self.assertNotIn('do-not-return', json.dumps(result))

    def test_changed_and_cancel(self):
        self.path.write_text('old')
        timer = threading.Timer(0.05, lambda: self.path.write_text('new-value'))
        timer.start()
        result = module.wait_for_file(dict(path=str(self.path), mode='changed', timeout_seconds=1, interval_seconds=0.1))
        timer.join()
        self.assertEqual(result['reason'], 'matched')
        event = threading.Event()
        event.set()
        self.assertEqual(module.wait_for_file(dict(path=str(self.path), mode='exists', timeout_seconds=1), event)['reason'], 'cancelled')

    def test_reject_symlink_and_large_json(self):
        target = self.path.with_name('target')
        target.write_text('private')
        self.path.symlink_to(target)
        with self.assertRaises(OSError):
            self.wait()
        self.path.unlink()
        self.path.write_bytes(b' ' * 65537)
        with self.assertRaises(ValueError):
            module.wait_for_file(dict(path=str(self.path), mode='json_equals', expected=None, timeout_seconds=0))

    def test_mcp_cancel(self):
        process = subprocess.Popen([sys.executable, str(SCRIPT), '--mcp'], stdin=subprocess.PIPE,
                                   stdout=subprocess.PIPE, text=True)
        try:
            def send(value):
                process.stdin.write(json.dumps(value) + '\n')
                process.stdin.flush()
            send(dict(jsonrpc='2.0', id=1, method='initialize', params={}))
            self.assertIn('serverInfo', json.loads(process.stdout.readline())['result'])
            send(dict(jsonrpc='2.0', id=2, method='tools/call', params=dict(name='wait_for_file',
                      arguments=dict(path=str(self.path), mode='exists', timeout_seconds=30))))
            send(dict(jsonrpc='2.0', method='notifications/cancelled', params=dict(requestId=2)))
            response = json.loads(process.stdout.readline())
            self.assertEqual(json.loads(response['result']['content'][0]['text'])['reason'], 'cancelled')
            process.stdin.close()
            self.assertEqual(process.wait(timeout=2), 0)
        finally:
            if process.poll() is None:
                process.kill()
                process.wait()
            process.stdout.close()


if __name__ == '__main__':
    unittest.main()

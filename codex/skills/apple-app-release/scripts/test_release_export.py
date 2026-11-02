import contextlib
import hashlib
import importlib.util
import io
import pathlib
import tempfile
import unittest
from unittest import mock

spec=importlib.util.spec_from_file_location('release_export',pathlib.Path(__file__).with_name('release-export.py'))
release=importlib.util.module_from_spec(spec)
spec.loader.exec_module(release)


class ExportCleanupTests(unittest.TestCase):
    def test_auto_added_keychain_and_interrupted_export(self):
        with tempfile.TemporaryDirectory(dir='/private/tmp') as tmp:
            root=pathlib.Path(tmp); cert=root/'cert'; cert.write_bytes(b'fixture'); key=root/'key'; key.write_bytes(b'fixture')
            current=['/first path/login.keychain-db']; calls=[]
            def fake_run(args,capture=False):
                if args[1]=='pkcs12': pathlib.Path(args[args.index('-out')+1]).write_bytes(b'p12')
                if args[1]=='create-keychain': current.insert(0,args[-1])
                if args[1]=='find-identity': return hashlib.sha1(cert.read_bytes()).hexdigest().upper()
                calls.append(args[1]); return '' if capture else None
            def fake_set(paths): current[:]=paths
            def interrupt(command):
                self.assertEqual(len(current),2)
                self.assertEqual(len(set(current)),2)
                current.append('/concurrent path/new.keychain-db')
                raise KeyboardInterrupt()
            output=io.StringIO()
            with mock.patch.object(release,'BASE',tmp), mock.patch.object(release,'run',side_effect=fake_run), mock.patch.object(release,'search_list',side_effect=lambda:current.copy()), mock.patch.object(release,'set_search',side_effect=fake_set), mock.patch.object(release,'run_child',side_effect=interrupt), contextlib.redirect_stderr(output):
                with self.assertRaises(KeyboardInterrupt): release.workflow(key,cert,[])
            self.assertEqual(current,['/first path/login.keychain-db','/concurrent path/new.keychain-db'])
            self.assertIn('delete-keychain',calls)
            self.assertIn('stage: export',output.getvalue())
            self.assertNotIn('fixture',output.getvalue())
            self.assertEqual(sorted(p.name for p in root.iterdir()),['cert','key'])


if __name__=='__main__': unittest.main()

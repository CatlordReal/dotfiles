import contextlib
import io
import pathlib
import plistlib
import tempfile
import unittest
import zipfile
from unittest import mock
import release_preflight as preflight


class PreflightTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = pathlib.Path(self.tmp.name)
        self.app = self.root / 'Sample.app'
        self.app.mkdir()
        self.info = {'CFBundleIdentifier':'test.example', 'CFBundleShortVersionString':'1.2', 'CFBundleVersion':'3', 'CFBundleIconFile':'Icon.icns'}
        (self.app/'Icon.icns').write_bytes(b'icon')
        self.write_info()
        self.args = ['--bundle','test.example','--version','1.2','--build','3','--metadata-only']

    def tearDown(self): self.tmp.cleanup()
    def write_info(self):
        with (self.app/'Info.plist').open('wb') as f: plistlib.dump(self.info,f)
    def call(self, path, *args):
        with mock.patch('sys.argv',['preflight',str(path),*args]), contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
            return preflight.main()
    def test_metadata_and_mismatch(self):
        self.assertEqual(self.call(self.app,*self.args),0)
        self.assertNotEqual(self.call(self.app,*self.args,'--version','2'),0)
    def test_icon_cannot_escape_or_follow_symlink(self):
        (self.root/'outside.icns').write_bytes(b'icon')
        (self.app/'Icon.icns').unlink()
        for name in ('../outside.icns', str(self.root/'outside.icns')):
            self.info['CFBundleIconFile']=name; self.write_info()
            self.assertNotEqual(self.call(self.app,*self.args),0)
        (self.app/'link.icns').symlink_to(self.root/'outside.icns')
        self.info['CFBundleIconFile']='link.icns'; self.write_info()
        self.assertNotEqual(self.call(self.app,*self.args),0)
    def test_resources_and_info_symlink_cannot_escape_bundle(self):
        external=self.root/'external'; external.mkdir()
        (external/'Icon.icns').write_bytes(b'icon')
        contents=self.app/'Contents'; contents.mkdir()
        (contents/'Resources').symlink_to(external, target_is_directory=True)
        self.assertNotEqual(self.call(self.app,*self.args),0)
        (contents/'Resources').unlink()
        (self.app/'Info.plist').unlink()
        outside=self.root/'outside.plist'
        with outside.open('wb') as f: plistlib.dump(self.info,f)
        (self.app/'Info.plist').symlink_to(outside)
        self.assertNotEqual(self.call(self.app,*self.args),0)
    def test_ipa_and_traversal(self):
        ipa=self.root/'test.ipa'
        with zipfile.ZipFile(ipa,'w') as z:
            for f in self.app.iterdir(): z.write(f,'Payload/Sample.app/'+f.name)
        self.assertEqual(self.call(ipa,*self.args),0)
        with zipfile.ZipFile(ipa,'a') as z: z.writestr('../escape','x')
        self.assertNotEqual(self.call(ipa,*self.args),0)
    def test_reject_oversized_declared_contents(self):
        ipa=self.root/'test.ipa'
        with zipfile.ZipFile(ipa,'w') as z: z.writestr('x','x')
        real=zipfile.ZipFile.infolist
        def huge(z):
            result=real(z); result[0].file_size=4*1024**3+1; return result
        with mock.patch.object(zipfile.ZipFile,'infolist',huge): self.assertNotEqual(self.call(ipa,*self.args),0)
    def test_unsigned_fails_signature_check(self):
        args=self.args[:-1]
        with mock.patch.object(preflight.subprocess,'run',return_value=mock.Mock(returncode=1,stderr='unsigned')):
            self.assertNotEqual(self.call(self.app,*args),0)


if __name__=='__main__': unittest.main()

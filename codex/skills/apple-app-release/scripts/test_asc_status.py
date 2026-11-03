import base64
import contextlib
import importlib.util
import io
import json
import os
import pathlib
import tempfile
import unittest
from unittest import mock
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives.asymmetric.utils import encode_dss_signature

spec=importlib.util.spec_from_file_location('asc_status',pathlib.Path(__file__).with_name('asc-status.py'))
asc=importlib.util.module_from_spec(spec); spec.loader.exec_module(asc)


class StatusTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory(dir='/private/tmp'); self.root=pathlib.Path(self.tmp.name)
        self.key=ec.generate_private_key(ec.SECP256R1()); self.keypath=self.root/'key.p8'
        self.keypath.write_bytes(self.key.private_bytes(serialization.Encoding.PEM,serialization.PrivateFormat.PKCS8,serialization.NoEncryption())); os.chmod(self.keypath,0o600)
        self.config={'key_id':'SYNTHETIC_KEY','issuer_id':'SYNTHETIC_ISSUER','private_key_path':str(self.keypath)}
        self.cfg=self.root/'config.json'; self.cfg.write_text(json.dumps(self.config)); os.chmod(self.cfg,0o600)
    def tearDown(self): self.tmp.cleanup()
    def test_token_signature_claims(self):
        token=asc.make_token(self.config,now=1000); h,p,s=token.split('.')
        decode=lambda x:base64.urlsafe_b64decode(x+'='*(-len(x)%4))
        header=json.loads(decode(h)); payload=json.loads(decode(p)); signature=decode(s)
        self.assertEqual(header['alg'],'ES256'); self.assertEqual(payload['exp']-payload['iat'],300)
        self.assertEqual(payload['aud'],'appstoreconnect-v1'); self.assertEqual(payload['iss'],'SYNTHETIC_ISSUER')
        self.key.public_key().verify(encode_dss_signature(int.from_bytes(signature[:32],'big'),int.from_bytes(signature[32:],'big')),(h+'.'+p).encode(),ec.ECDSA(hashes.SHA256()))
    def test_permissions_and_symlinks(self):
        os.chmod(self.keypath,0o644)
        with self.assertRaises(ValueError): asc.make_token(self.config)
        os.chmod(self.keypath,0o600)
        link=self.root/'link'; link.symlink_to(self.keypath)
        with self.assertRaises(OSError): asc.private_file(link)
        directory=self.root/'linkdir'; directory.symlink_to(self.root, target_is_directory=True)
        with self.assertRaises(ValueError): asc.private_file(directory/'key.p8')
        os.chmod(self.cfg,0o644)
        with self.assertRaises(ValueError): asc.private_file(self.cfg)
    def test_request_fixed_host_get_filter_timeout(self):
        response=mock.MagicMock(); response.__enter__.return_value.read.return_value=b'{"data":[]}'
        opener=mock.Mock(); opener.open.return_value=response
        with mock.patch.object(asc.urllib.request,'build_opener',return_value=opener): self.assertEqual(asc.request_builds('123','synthetic-token'),{'data':[]})
        req=opener.open.call_args.args[0]
        self.assertEqual(req.get_method(),'GET'); self.assertTrue(req.full_url.startswith(asc.HOST+'/v1/builds?'))
        self.assertEqual(asc.urllib.parse.parse_qs(asc.urllib.parse.urlparse(req.full_url).query)['filter[app]'],['123'])
        self.assertEqual(opener.open.call_args.kwargs['timeout'],30)
        self.assertIsNone(asc.NoRedirect().redirect_request(None,None,None,None,None,None))
    def test_redaction_on_failure(self):
        err=io.StringIO(); out=io.StringIO()
        with mock.patch('sys.argv',['asc-status','--config',str(self.cfg),'--app-id','123']), mock.patch.object(asc,'request_builds',side_effect=RuntimeError('SYNTHETIC_SECRET bearer fake')),contextlib.redirect_stderr(err),contextlib.redirect_stdout(out):
            self.assertEqual(asc.main(),1)
        self.assertNotIn('SYNTHETIC',err.getvalue()+out.getvalue()); self.assertNotIn('bearer',err.getvalue()+out.getvalue())
    def test_reject_malformed_success_and_nested_output(self):
        invalid=[{}, {'errors':[{'detail':'hidden'}]}, {'data':{}}, {'data':[{}]},
                 {'data':[{'type':'builds','id':{'secret':'x'},'attributes':{}}]},
                 {'data':[{'type':'builds','id':'b','attributes':{'version':{'secret':'x'}}}]},
                 {'data':[{'type':'builds','id':'b','attributes':{},'relationships':{'betaGroups':{'data':[{'type':'users','id':'u'}]}}}]},
                 {'data':[{'type':'builds','id':'b','attributes':{},'relationships':{'betaGroups':{'data':[{'type':'betaGroups','id':'g'}]}}}], 'included':[{'type':'betaGroups','id':'g','attributes':{'name':{'secret':'x'}}}]}]
        for response in invalid:
            with self.subTest(response=response), self.assertRaises(ValueError): asc.statuses(response)

    def test_output_whitelist(self):
        data={'data':[{'type':'builds','id':'build','attributes':{'version':'1','processingState':'VALID','secret':'hidden'},'relationships':{'betaGroups':{'data':[{'type':'betaGroups','id':'group'}]}}}], 'included':[{'type':'betaGroups','id':'group','attributes':{'name':'Test','isInternalGroup':True,'secret':'hidden'}}]}
        output=json.dumps(asc.statuses(data)); self.assertIn('Test',output); self.assertNotIn('hidden',output)


if __name__=='__main__': unittest.main()

#!/usr/bin/env python3
"""Read recent App Store Connect build statuses using a locally held API key."""
import argparse
import base64
import json
import os
import pathlib
import stat
import sys
import time
import urllib.parse
import urllib.request

from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives.asymmetric.utils import decode_dss_signature
from cryptography.hazmat.primitives.serialization import load_pem_private_key

HOST = 'https://api.appstoreconnect.apple.com'
MAX_RESPONSE = 2 * 1024 * 1024
TIMEOUT = 30


def private_file(path):
    """Reject symlinks, unsafe ancestors, and files accessible to other users."""
    p = pathlib.Path(path)
    if not p.is_absolute() or '..' in p.parts:
        raise ValueError('credential paths must be absolute')
    for parent in reversed(p.parents):
        st = parent.lstat()
        if not stat.S_ISDIR(st.st_mode) or st.st_uid not in (0, os.getuid()):
            raise ValueError('unsafe credential directory')
        # System temporary directories are allowed only with sticky bit.
        if st.st_mode & 0o022 and not (st.st_mode & stat.S_ISVTX and st.st_uid == 0):
            raise ValueError('writable credential directory')
    fd = os.open(p, os.O_RDONLY | os.O_NOFOLLOW)
    try:
        st = os.fstat(fd)
        if not stat.S_ISREG(st.st_mode) or st.st_uid != os.getuid() or stat.S_IMODE(st.st_mode) != 0o600:
            raise ValueError('credential file must be user-owned mode 0600')
        with os.fdopen(fd, 'rb') as f:
            fd = -1
            data = f.read(1024 * 1024 + 1)
        if len(data) > 1024 * 1024:
            raise ValueError('credential file too large')
        return data
    finally:
        if fd != -1: os.close(fd)


def b64(data):
    return base64.urlsafe_b64encode(data).rstrip(b'=').decode('ascii')


def make_token(config, now=None):
    key = load_pem_private_key(private_file(config['private_key_path']), password=None)
    if not isinstance(key, ec.EllipticCurvePrivateKey) or not isinstance(key.curve, ec.SECP256R1):
        raise ValueError('expected an ES256 private key')
    now = int(time.time()) if now is None else int(now)
    def part(value): return b64(json.dumps(value, separators=(',', ':')).encode())
    message = part({'alg':'ES256','kid':config['key_id'],'typ':'JWT'}) + '.' + part({'iss':config['issuer_id'],'iat':now,'exp':now+300,'aud':'appstoreconnect-v1'})
    r, s = decode_dss_signature(key.sign(message.encode(), ec.ECDSA(hashes.SHA256())))
    return message + '.' + b64(r.to_bytes(32, 'big') + s.to_bytes(32, 'big'))


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *args, **kwargs): return None


def request_builds(app_id, token):
    if not app_id.isascii() or not app_id.isdigit(): raise ValueError('app ID must be numeric')
    query = urllib.parse.urlencode({'filter[app]':app_id,'include':'preReleaseVersion,buildBetaDetail,betaAppReviewSubmission,betaGroups','limit':'20','sort':'-uploadedDate'})
    req = urllib.request.Request(HOST + '/v1/builds?' + query, headers={'Authorization':'Bearer '+token,'Accept':'application/json'}, method='GET')
    opener = urllib.request.build_opener(NoRedirect())
    with opener.open(req, timeout=TIMEOUT) as response:
        data = response.read(MAX_RESPONSE + 1)
    if len(data) > MAX_RESPONSE: raise ValueError('response too large')
    return json.loads(data)


def statuses(response):
    if not isinstance(response, dict) or 'errors' in response or not isinstance(response.get('data'), list):
        raise ValueError('invalid API response')
    included_raw=response.get('included', [])
    if not isinstance(included_raw, list): raise ValueError('invalid included data')
    mapping={'preReleaseVersion':('preReleaseVersions',{'version':str}), 'buildBetaDetail':('buildBetaDetails',{'internalBuildState':str,'externalBuildState':str}), 'betaAppReviewSubmission':('betaAppReviewSubmissions',{'betaReviewState':str}), 'betaGroups':('betaGroups',{'name':str,'isInternalGroup':bool,'publicLinkEnabled':bool})}
    expected_types={v[0] for v in mapping.values()}
    def identity(obj, expected=None):
        if not isinstance(obj,dict) or not isinstance(obj.get('type'),str) or not isinstance(obj.get('id'),str) or not obj['id']:
            raise ValueError('invalid resource identifier')
        if expected is not None and obj['type'] != expected: raise ValueError('unexpected resource type')
        return obj['type'],obj['id']
    def fields(attrs, allowed):
        if not isinstance(attrs,dict): raise ValueError('invalid attributes')
        output={}
        for key,typ in allowed.items():
            if key in attrs:
                val=attrs[key]
                if val is not None and type(val) is not typ: raise ValueError('invalid attribute')
                output[key]=val
        return output
    included={}
    for obj in included_raw:
        key=identity(obj)
        if key[0] not in expected_types or key in included: raise ValueError('unexpected included resource')
        included[key]=obj
    result=[]
    for obj in response['data']:
        _,ident=identity(obj,'builds')
        attrs=fields(obj.get('attributes'),{'version':str,'processingState':str,'buildAudienceType':str})
        rels=obj.get('relationships',{})
        if not isinstance(rels,dict): raise ValueError('invalid relationships')
        row={'id':ident,'build':attrs.get('version'),'processing':attrs.get('processingState'),'audience':attrs.get('buildAudienceType')}
        for name,(resource_type,allowed) in mapping.items():
            relationship=rels.get(name,{})
            if not isinstance(relationship,dict): raise ValueError('invalid relationship')
            linked=relationship.get('data'); refs=linked if isinstance(linked,list) else ([linked] if linked is not None else [])
            row[name]=[]
            for ref in refs:
                key=identity(ref,resource_type)
                other=included.get(key)
                values=fields(other.get('attributes',{}),allowed) if other is not None else {}
                row[name].append({'id':key[1],**values})
        result.append(row)
    return result


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--config',required=True, help='mode-0600 JSON: key_id, issuer_id, private_key_path')
    parser.add_argument('--app-id',required=True, help='numeric App Store Connect app ID')
    args=parser.parse_args()
    try:
        config=json.loads(private_file(args.config))
        token=make_token(config)
        print(json.dumps({'builds':statuses(request_builds(args.app_id,token)),'scope':'Most recent 20 builds; additional pages are not fetched.'},indent=2))
        return 0
    except Exception:
        # Neither HTTP response bodies nor exceptions are safe to print.
        print('Status request failed; check credential permissions, API access, app ID, and network.',file=sys.stderr)
        return 1


if __name__ == '__main__': sys.exit(main())

#!/usr/bin/env python3
"""Export using a temporary signing keychain. Execute only with explicit user consent.

Passwords are passed in security argv as required by its noninteractive CLI and
can be observed by local process inspection. Never log argv or tool output.
SIGKILL or machine failure can leave the keychain, search-list entry, and recovery
directory. Recover manually using the mode-600 original-search-list.json. Serialize
all signing work: concurrent search-list changes can race with this wrapper.
"""
import argparse
import fcntl
import hashlib
import json
import os
import pathlib
import secrets
import shlex
import shutil
import signal
import stat
import subprocess
import sys
import tempfile

SECURITY='/usr/bin/security'
OPENSSL='/usr/bin/openssl'
XCODEBUILD='/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild'
BASE='/private/tmp'


def run(args, capture=False):
    p=subprocess.run(args, stdout=subprocess.PIPE if capture else subprocess.DEVNULL, stderr=subprocess.DEVNULL, text=True, timeout=120)
    if p.returncode: raise RuntimeError('temporary keychain operation failed')
    return p.stdout if capture else None


def checked_file(path, private=False):
    p=pathlib.Path(path)
    if not p.is_absolute() or p.resolve() != p:
        raise ValueError('input path must be absolute and contain no symlinks')
    st=p.lstat()
    if not stat.S_ISREG(st.st_mode) or st.st_uid != os.getuid() or st.st_mode & (0o077 if private else 0o022):
        raise ValueError('input must be user-owned regular file with safe permissions')
    return p


def search_list():
    out=run([SECURITY,'list-keychains','-d','user'], True)
    result=[]
    for line in out.splitlines():
        words=shlex.split(line)
        if len(words)!=1: raise RuntimeError('unrecognized search list')
        result.append(words[0])
    return result


def set_search(paths): run([SECURITY,'list-keychains','-d','user','-s',*paths])


def run_child(command):
    child=subprocess.Popen(command, start_new_session=True)
    try:
        return child.wait()
    except BaseException:
        try:
            os.killpg(child.pid, signal.SIGTERM)
            try: child.wait(timeout=10)
            except subprocess.TimeoutExpired:
                os.killpg(child.pid, signal.SIGKILL)
                child.wait(timeout=10)
        except ProcessLookupError: pass
        raise


def workflow(key, cert, command):
    directory=pathlib.Path(tempfile.mkdtemp(prefix='codex-release-signing-',dir=BASE))
    os.chmod(directory,0o700)
    kc=str(directory/'release.keychain-db'); p12=directory/'identity.p12'; pem=directory/'certificate.pem'; passfile=directory/'password'; recovery=directory/'original-search-list.json'
    password=secrets.token_hex(32)
    inserted=False; created=False; errors=[]; stage='record search list'
    try:
        passfile.write_text(password,encoding='ascii'); os.chmod(passfile,0o600)
        old=search_list()
        recovery.write_text(json.dumps(old),encoding='utf-8'); os.chmod(recovery,0o600)
        stage='convert certificate'
        run([OPENSSL,'x509','-inform','DER','-in',str(cert),'-out',str(pem)])
        stage='package identity'
        run([OPENSSL,'pkcs12','-export','-inkey',str(key),'-in',str(pem),'-out',str(p12),'-passout','file:'+str(passfile)])
        passfile.unlink()
        created=True
        # create-keychain can add itself to the shared search list.
        inserted=True
        stage='create keychain'
        run([SECURITY,'create-keychain','-p',password,kc])
        stage='unlock keychain'
        run([SECURITY,'unlock-keychain','-p',password,kc])
        stage='import identity'
        run([SECURITY,'import',str(p12),'-k',kc,'-f','pkcs12','-P',password,'-T','/usr/bin/codesign'])
        p12.unlink()
        # Scope partition change to our new keychain only, never the login keychain.
        stage='configure temporary key access'
        run([SECURITY,'set-key-partition-list','-S','apple:','-s','-k',password,kc])
        identity=hashlib.sha1(cert.read_bytes()).hexdigest().upper()
        stage='verify imported identity'
        ids=run([SECURITY,'find-identity','-p','codesigning','-v',kc],True)
        if identity not in ids.upper(): raise RuntimeError('expected signing identity unavailable')
        # Verify this exact identity can sign before touching the search list.
        stage='test signature'
        probe=directory/'signing-probe'
        shutil.copy('/usr/bin/true',probe)
        run(['/usr/bin/codesign','--force','--sign',identity,'--keychain',kc,str(probe)])
        run(['/usr/bin/codesign','--verify','--strict',str(probe)])
        probe.unlink()
        # Start from fresh state; callers must serialize search-list mutations.
        stage='configure search list'
        current=search_list()
        set_search([kc,*[entry for entry in current if entry != kc]])
        stage='export'
        result=run_child(command)
        if result: print('Release export failed at stage: export',file=sys.stderr)
        return result
    except BaseException:
        print('Release export failed or interrupted at stage: '+stage,file=sys.stderr)
        raise
    finally:
        previous_handlers={sig:signal.signal(sig,signal.SIG_IGN) for sig in (signal.SIGINT,signal.SIGTERM)}
        if inserted:
            try:
                current=search_list()
                set_search([entry for entry in current if entry != kc])
            except Exception: errors.append('search list restoration')
        if created:
            try: run([SECURITY,'delete-keychain',kc])
            except Exception: errors.append('keychain deletion')
        for secret_file in (p12, passfile):
            try: secret_file.unlink(missing_ok=True)
            except OSError: errors.append('secret file removal')
        if errors:
            print('CLEANUP FAILED: '+', '.join(errors)+'. Recovery directory: '+str(directory)+'; original search list: '+str(recovery)+'; temporary keychain: '+kc, file=sys.stderr)
        else:
            try: shutil.rmtree(directory)
            except OSError:
                errors.append('recovery directory removal')
                print('CLEANUP FAILED: recovery directory removal: '+str(directory), file=sys.stderr)
        for sig, handler in previous_handlers.items(): signal.signal(sig,handler)
        if errors: raise RuntimeError('cleanup incomplete')


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--key'); p.add_argument('--cert'); p.add_argument('--cert-sha256'); p.add_argument('--consent',action='store_true')
    p.add_argument('command',nargs=argparse.REMAINDER)
    a=p.parse_args()
    if not a.consent: p.error('explicit consent required')
    lockpath=pathlib.Path(BASE)/f'codex-release-signing-{os.getuid()}.lock'
    fd=os.open(lockpath,os.O_CREAT|os.O_RDWR|os.O_NOFOLLOW,0o600)
    st=os.fstat(fd)
    if not stat.S_ISREG(st.st_mode) or st.st_uid!=os.getuid() or st.st_mode&0o077: raise ValueError('unsafe lock')
    fcntl.flock(fd,fcntl.LOCK_EX|fcntl.LOCK_NB)
    def stop(signum,frame): raise KeyboardInterrupt()
    signal.signal(signal.SIGTERM,stop)
    if not a.key or not a.cert or not a.cert_sha256 or not a.command or a.command[0]!='--': p.error('key, certificate, SHA-256 and command after -- required')
    command=a.command[1:]
    if not command or command[0]!=XCODEBUILD or '-exportArchive' not in command or '-archivePath' not in command or '-exportPath' not in command or '-exportOptionsPlist' not in command:
        p.error('exact Xcode xcodebuild -exportArchive command and archive, export, options paths required')
    key=checked_file(a.key,True); cert=checked_file(a.cert)
    if hashlib.sha256(cert.read_bytes()).hexdigest()!=a.cert_sha256.replace(':','').lower(): raise ValueError('certificate SHA-256 mismatch')
    return workflow(key,cert,command)


if __name__=='__main__':
    try: sys.exit(main())
    except (Exception,KeyboardInterrupt):
        print('Temporary signing failed or interrupted; check cleanup messages.',file=sys.stderr); sys.exit(1)

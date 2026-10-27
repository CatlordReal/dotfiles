#!/usr/bin/env python3
"""Task-scoped Codex inactivity watcher and passive lifecycle hook."""
from __future__ import annotations
import argparse, fcntl, hashlib, json, os, re, signal, subprocess, sys, threading, time, urllib.request, uuid, stat
from pathlib import Path

THREAD_RE=re.compile(r"^[A-Za-z0-9_-]{8,160}$"); TOOL_RE=re.compile(r"^[A-Za-z0-9_.:-]{1,100}$")
DEFAULT_STATE_DIR=Path("/private/tmp")/f"codex-watchdog-{os.getuid()}"

def session_key(value):
    if not isinstance(value,str) or not THREAD_RE.fullmatch(value): raise ValueError("invalid session id")
    return hashlib.sha256(value.encode()).hexdigest()[:24]

def discover_session(thread_id,root):
    session_key(thread_id); matches=list(root.rglob(f"rollout-*-{thread_id}.jsonl"))
    if not matches: raise FileNotFoundError(f"no rollout found for thread {thread_id}")
    return max(matches,key=lambda p:p.stat().st_mtime_ns)

def within(path,root):
    try: path.resolve().relative_to(root.resolve()); return True
    except ValueError: return False

def atomic_json(path,value):
    path.parent.mkdir(parents=True,exist_ok=True,mode=0o700); tmp=path.with_name(f".{path.name}.{os.getpid()}.tmp")
    with tmp.open("w",encoding="utf-8") as out:
        json.dump(value,out,separators=(",",":"),sort_keys=True); out.flush(); os.fsync(out.fileno())
    os.chmod(tmp,0o600); os.replace(tmp,path)

def read_json(path):
    try:
        value=json.loads(path.read_text(encoding="utf-8")); return value if isinstance(value,dict) else None
    except (OSError,json.JSONDecodeError): return None

def marker_fresh(marker,now,excluded):
    pid=marker.get("owner_pid")
    if not isinstance(pid,int) or pid in excluded:return False
    beat=marker.get("heartbeat")
    return isinstance(beat,(int,float)) and now-beat<=30

def secure_state_dir(path):
    if path.exists() and path.is_symlink():raise ValueError("state directory must not be a symlink")
    path.mkdir(parents=True,exist_ok=True,mode=0o700);info=path.stat()
    if info.st_uid!=os.getuid() or not stat.S_ISDIR(info.st_mode):raise ValueError("state directory must be owned directory")
    os.chmod(path,0o700)

class Store:
    def __init__(self,root,session_id):
        secure_state_dir(root);self.root=root/session_key(session_id);self.commands=self.root/"commands";self.subagents=self.root/"subagents";self.notice=self.root/"permission-notified.json"
    def live_commands(self,now,excluded):
        for path in self.commands.glob("*.json") if self.commands.exists() else ():
            marker=read_json(path);lock_path=path.with_suffix(".lock");handle=None
            try:
                handle=lock_path.open("a+");fcntl.flock(handle.fileno(),fcntl.LOCK_EX|fcntl.LOCK_NB);locked=False
            except BlockingIOError:locked=True
            finally:
                if handle:handle.close()
            if locked and marker and marker_fresh(marker,now,excluded):return True
            if not locked:path.unlink(missing_ok=True);lock_path.unlink(missing_ok=True)
        return False
    def active_subagents(self,now):
        active=False
        for path in self.subagents.glob("*.json") if self.subagents.exists() else ():
            marker=read_json(path)
            if marker and isinstance(marker.get("expires"),(int,float)) and marker["expires"]>=now:active=True
            else:path.unlink(missing_ok=True)
        return active

class Tail:
    """EOF captured from one handle; appends after attach cannot fall between scan and tail."""
    def __init__(self,path):
        self.path=path; self.partial=b""
        with path.open("rb") as f:
            f.seek(0,os.SEEK_END); self.offset=f.tell(); st=os.fstat(f.fileno()); self.identity=(st.st_dev,st.st_ino)
    def read(self):
        with self.path.open("rb") as f:
            st=os.fstat(f.fileno()); ident=(st.st_dev,st.st_ino)
            if ident!=self.identity or st.st_size<self.offset:self.identity=ident;self.offset=0;self.partial=b""
            f.seek(self.offset); chunk=f.read(); self.offset=f.tell()
        if not chunk:return []
        lines=(self.partial+chunk).splitlines(keepends=True); self.partial=b""
        if lines and not lines[-1].endswith((b"\n",b"\r")):self.partial=lines.pop()
        records=[]
        for line in lines:
            try:value=json.loads(line)
            except (json.JSONDecodeError,UnicodeDecodeError):continue
            if isinstance(value,dict):records.append(value)
        return records

class Latch:
    def __init__(self,timeout,now):self.timeout=timeout;self.last=now;self.alerted=False
    def activity(self,now):self.last=now;self.alerted=False
    def alert(self,now,suppressed):
        if suppressed or self.alerted or now-self.last<self.timeout:return False
        self.alerted=True;return True

def send_ntfy(url,message,timeout):
    request=urllib.request.Request(url,data=message.encode(),headers={"Title":"Codex watchdog","Content-Type":"text/plain; charset=utf-8"},method="POST")
    with urllib.request.urlopen(request,timeout=timeout) as response:response.read(1)

def log(path,event,session):
    if not path:return
    path.parent.mkdir(parents=True,exist_ok=True)
    with path.open("a",encoding="utf-8") as out:out.write(f"{time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime())} event={event} session={session.name}\n")

def mtime_ns(path):
    try:return path.stat().st_mtime_ns
    except OSError:return 0

def validate_storage(args,session):
    if within(args.state_dir,args.sessions_root):raise ValueError("state directory must not be inside Codex sessions")
    if args.log_file and (args.log_file.resolve()==session.resolve() or within(args.log_file,args.sessions_root)):raise ValueError("log must not be rollout or inside Codex sessions")

def event_thread_id(event,sessions_root):
    transcript=event.get("transcript_path")
    if isinstance(transcript,str):
        path=Path(transcript)
        match=re.search(r"^rollout-.*-([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})\.jsonl$",path.name)
        if match and path.exists() and within(path,sessions_root):return match.group(1)
    return None

def acquire(path):
    path.parent.mkdir(parents=True,exist_ok=True,mode=0o700); handle=path.open("a+")
    try:fcntl.flock(handle.fileno(),fcntl.LOCK_EX|fcntl.LOCK_NB)
    except BlockingIOError:handle.close();raise RuntimeError("watchdog already running for this task")
    return handle

def watch(args):
    session=discover_session(args.thread_id,args.sessions_root);validate_storage(args,session);store=Store(args.state_dir,args.thread_id);lock=acquire(store.root/"watch.lock")
    atomic_json(store.root/"watcher.json",{"started":time.time(),"poll":args.poll})
    tail=Tail(session);latch=Latch(args.timeout,time.monotonic());excluded={os.getpid()};stopping=threading.Event();notice_mtime=mtime_ns(store.notice)
    def stop_signal(_signal,_frame):
        stopping.set()
    signal.signal(signal.SIGINT,stop_signal);signal.signal(signal.SIGTERM,stop_signal);log(args.log_file,"started",session)
    try:
        while not stopping.is_set():
            mono=time.monotonic();wall=time.time()
            if (store.root/"stop.request").exists():(store.root/"stop.request").unlink(missing_ok=True);break
            if tail.read():latch.activity(mono)
            suppressed=store.live_commands(wall,excluded) or store.active_subagents(wall)
            if suppressed:latch.activity(mono)
            current_notice=mtime_ns(store.notice)
            if current_notice>notice_mtime:notice_mtime=current_notice;latch.alerted=True
            if latch.alert(mono,suppressed):
                message=f"🔴 Codex task inactive for {int(mono-latch.last)}s; possibly waiting or stuck. No verified wrapped command or tracked subagent is active; unwrapped command state is unknown."
                if args.dry_run:print(message,flush=True);log(args.log_file,"dry-run-alert",session)
                else:
                    try:send_ntfy(args.ntfy_url,message,args.network_timeout);log(args.log_file,"alert-sent",session)
                    except Exception as error:print(f"watchdog notification outcome unknown: {type(error).__name__}",file=sys.stderr);log(args.log_file,"alert-outcome-unknown",session)
            stopping.wait(args.poll)
    finally:
        log(args.log_file,"stopped",session);(store.root/"watcher.json").unlink(missing_ok=True);lock.close()
    return 0

def run_command(args):
    if args.command and args.command[0]=="--":args.command=args.command[1:]
    if not args.command:raise ValueError("run-command requires executable and arguments")
    store=Store(args.state_dir,args.session_id);token=uuid.uuid4().hex;marker=store.commands/f"{token}.json";lock_path=store.commands/f"{token}.lock";lock=acquire(lock_path);read_fd,write_fd=os.pipe();pid=os.fork()
    if pid==0:
        try:
            lock.close();os.close(write_fd)
            if os.read(read_fd,1)!=b"1":os._exit(126)
            os.close(read_fd);os.chdir(args.cwd);os.execvpe(args.command[0],args.command,os.environ.copy())
        except BaseException:os._exit(127)
    os.close(read_fd)
    def refresh():atomic_json(marker,{"child_pid":pid,"owner_pid":os.getpid(),"heartbeat":time.time()})
    old={}
    def forward(signum,_frame):
        try:os.kill(pid,signum)
        except ProcessLookupError:pass
    try:
        refresh()
        for number in (signal.SIGINT,signal.SIGTERM,signal.SIGHUP):old[number]=signal.signal(number,forward)
        os.write(write_fd,b"1");os.close(write_fd);write_fd=-1
        while True:
            waited,status=os.waitpid(pid,os.WNOHANG)
            if waited==pid:
                code=os.waitstatus_to_exitcode(status);return 128+(-code) if code<0 else code
            refresh();time.sleep(1)
    finally:
        if write_fd>=0:os.close(write_fd)
        marker.unlink(missing_ok=True);lock.close();lock_path.unlink(missing_ok=True)
        for number,handler in old.items():signal.signal(number,handler)

def hook_input():
    raw=sys.stdin.buffer.read(1_048_577)
    if len(raw)>1_048_576:raise ValueError("hook input too large")
    value=json.loads(raw)
    if not isinstance(value,dict):raise ValueError("hook input must be object")
    return value

def hook(args):
    try:
        event=hook_input();name=event.get("hook_event_name");session_id=event.get("session_id");session_key(session_id);thread_id=event_thread_id(event,args.sessions_root)
        if name=="PermissionRequest":
            # This event precedes approval resolution, including automatic review.
            # It does not prove a human is waiting. Never notify speculatively or
            # mark the inactivity episode notified; the idle watcher is fallback.
            return 0
        if not thread_id:return 0
        store=Store(args.state_dir,thread_id)
        agent_id=event.get("agent_id")
        if isinstance(agent_id,str):
            path=store.subagents/f"{hashlib.sha256(agent_id.encode()).hexdigest()}.json"
            if name=="SubagentStart":atomic_json(path,{"expires":time.time()+args.subagent_max_seconds})
            elif name=="SubagentStop":path.unlink(missing_ok=True)
        return 0
    except Exception:return 0

def start(args):
    session=discover_session(args.thread_id,args.sessions_root)
    if args.log_file is None:args.log_file=args.state_dir/session_key(args.thread_id)/"watchdog.log"
    validate_storage(args,session)
    store=Store(args.state_dir,args.thread_id);launcher=acquire(store.root/"launch.lock")
    try:
        probe=acquire(store.root/"watch.lock");probe.close();(store.root/"watcher.json").unlink(missing_ok=True)
        command=[sys.executable,str(Path(__file__).resolve()),"watch","--thread-id",args.thread_id,"--sessions-root",str(args.sessions_root),"--state-dir",str(args.state_dir),"--timeout",str(args.timeout),"--poll",str(args.poll),"--ntfy-url",args.ntfy_url,"--network-timeout",str(args.network_timeout),"--log-file",str(args.log_file)]
        if args.dry_run:command.append("--dry-run")
        args.log_file.parent.mkdir(parents=True,exist_ok=True)
        with args.log_file.open("a",encoding="utf-8") as output:child=subprocess.Popen(command,stdin=subprocess.DEVNULL,stdout=output,stderr=output,start_new_session=True)
        marker=store.root/"watcher.json";deadline=time.monotonic()+2
        while time.monotonic()<deadline and not marker.exists() and child.poll() is None:time.sleep(.05)
        if child.poll() is not None or not marker.exists():raise RuntimeError("watchdog failed readiness check; inspect log")
        print(child.pid);return 0
    finally:launcher.close()

def stop(args):
    store=Store(args.state_dir,args.thread_id);path=store.root/"watcher.json";marker=read_json(path)
    if not marker:raise RuntimeError("no running watchdog marker")
    atomic_json(store.root/"stop.request",{"requested":time.time()});wait_bound=float(marker.get("poll",10))+2;deadline=time.monotonic()+wait_bound
    while time.monotonic()<deadline:
        if not path.exists():return 0
        time.sleep(.1)
    raise RuntimeError("watchdog did not stop within bounded wait")

def common(item):
    item.add_argument("--state-dir",type=Path,default=DEFAULT_STATE_DIR);item.add_argument("--ntfy-url",default="https://ntfy.sh/Catlord_Codex-Action_Request");item.add_argument("--network-timeout",type=float,default=10)
def parser():
    root=argparse.ArgumentParser(description=__doc__);subs=root.add_subparsers(dest="mode",required=True)
    for name in ("watch","start"):
        item=subs.add_parser(name);item.add_argument("--thread-id",required=True);item.add_argument("--sessions-root",type=Path,default=Path.home()/".codex"/"sessions");item.add_argument("--timeout",type=float,default=300);item.add_argument("--poll",type=float,default=10);item.add_argument("--log-file",type=Path);item.add_argument("--dry-run",action="store_true");common(item)
    item=subs.add_parser("stop");item.add_argument("--thread-id",required=True);item.add_argument("--state-dir",type=Path,default=DEFAULT_STATE_DIR)
    item=subs.add_parser("run-command");item.add_argument("--session-id",required=True);item.add_argument("--cwd",type=Path,required=True);item.add_argument("--state-dir",type=Path,default=DEFAULT_STATE_DIR);item.add_argument("command",nargs=argparse.REMAINDER)
    item=subs.add_parser("hook");item.add_argument("--subagent-max-seconds",type=float,default=3600);item.add_argument("--sessions-root",type=Path,default=Path.home()/".codex"/"sessions");common(item)
    return root
def main(argv=None):
    args=parser().parse_args(argv)
    if args.mode in {"watch","start"} and (args.timeout<=0 or not 0<args.poll<=10):raise ValueError("invalid timeout or poll")
    return {"watch":watch,"start":start,"stop":stop,"run-command":run_command,"hook":hook}[args.mode](args)
if __name__=="__main__":
    try:raise SystemExit(main())
    except (FileNotFoundError,RuntimeError,ValueError) as error:print(f"watchdog: {error}",file=sys.stderr);raise SystemExit(2)

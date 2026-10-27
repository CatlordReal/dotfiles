import io, json, os, subprocess, sys, tempfile, time, unittest
from contextlib import redirect_stdout
from pathlib import Path
from types import SimpleNamespace
from unittest import mock
import codex_watchdog as w

class LatchTests(unittest.TestCase):
    def test_timeout_latch_resets_only_on_activity(self):
        latch=w.Latch(5,0);self.assertFalse(latch.alert(4,False));self.assertTrue(latch.alert(5,False));self.assertFalse(latch.alert(20,False));latch.activity(21);self.assertTrue(latch.alert(26,False))
    def test_verified_activity_suppresses(self):
        latch=w.Latch(5,0);self.assertFalse(latch.alert(10,True))
    def test_suppression_refreshes_timer_before_marker_disappears(self):
        latch=w.Latch(5,0);latch.activity(100);self.assertFalse(latch.alert(104,False));self.assertTrue(latch.alert(105,False))

class TailTests(unittest.TestCase):
    def test_attach_boundary_does_not_skip_append(self):
        with tempfile.TemporaryDirectory() as d:
            path=Path(d)/"rollout-x-thread123.jsonl";path.write_text('{"type":"old"}\n');tail=w.Tail(path)
            with path.open("a") as out:out.write('{"type":"new"}\n')
            self.assertEqual(tail.read(),[{"type":"new"}])
    def test_pending_generic_tool_is_activity_not_suppression(self):
        with tempfile.TemporaryDirectory() as d:
            path=Path(d)/"rollout-x-thread123.jsonl";path.write_text("");tail=w.Tail(path)
            fixture={"type":"response_item","payload":{"type":"custom_tool_call","name":"js","call_id":"c1","status":"completed"}}
            with path.open("a") as out:out.write(json.dumps(fixture)+"\n")
            self.assertEqual(len(tail.read()),1) # No pending-call state exists to suppress later alerts.
            completed={"type":"event_msg","payload":{"type":"item_completed","item":{"type":"CommandExecution","status":"completed","process_id":"55561","exit_code":0}}}
            with path.open("a") as out:out.write(json.dumps(completed)+"\n")
            self.assertEqual(len(tail.read()),1) # Unified handle is data only, never queried as an OS PID.

class MarkerTests(unittest.TestCase):
    def test_stale_heartbeat_rejected(self):
        marker={"owner_pid":42,"heartbeat":100}
        self.assertTrue(w.marker_fresh(marker,101,set()))
        self.assertFalse(w.marker_fresh(marker,131,set()))
    def test_self_or_ancestor_excluded(self):
        marker={"owner_pid":42,"heartbeat":100}
        self.assertFalse(w.marker_fresh(marker,101,{42}))
    def test_subagent_marker_is_bounded(self):
        with tempfile.TemporaryDirectory() as d:
            store=w.Store(Path(d),"thread123");w.atomic_json(store.subagents/"a.json",{"expires":10})
            self.assertTrue(store.active_subagents(9));self.assertFalse(store.active_subagents(11))

class HookTests(unittest.TestCase):
    def invoke(self,event,state,sessions,send):
        args=SimpleNamespace(state_dir=state,sessions_root=sessions,ntfy_url="https://ntfy.invalid/topic",network_timeout=1,subagent_max_seconds=60)
        fake=io.TextIOWrapper(io.BytesIO(json.dumps(event).encode()))
        with mock.patch.object(sys,"stdin",fake),mock.patch.object(w,"send_ntfy",side_effect=send):return w.hook(args)
    def test_unresolved_permission_event_does_not_notify(self):
        event={"hook_event_name":"PermissionRequest","session_id":"thread123","turn_id":"turn1","tool_name":"Bash","tool_input":{"command":"SECRET"}}
        sent=[]
        with tempfile.TemporaryDirectory() as d:
            self.assertEqual(self.invoke(event,Path(d)/"state",Path(d)/"sessions",lambda u,m,t:sent.append(m)),0)
        self.assertEqual(sent,[])
    def test_unresolved_permission_never_contacts_network(self):
        event={"hook_event_name":"PermissionRequest","session_id":"thread123","turn_id":"turn1","tool_name":"apply_patch","tool_input":{"command":"private"}}
        calls=[]
        with tempfile.TemporaryDirectory() as d:self.assertEqual(self.invoke(event,Path(d)/"state",Path(d)/"sessions",lambda *a:(calls.append(a),(_ for _ in ()).throw(TimeoutError()))[1]),0)
        self.assertEqual(len(calls),0)
    def test_permission_burst_never_sends_or_latches(self):
        sent=[]
        with tempfile.TemporaryDirectory() as d:
            root=Path(d);sessions=root/"sessions";sessions.mkdir()
            thread_id="01a164a0-5c54-7503-abf2-9db080855287"
            transcript=sessions/f"rollout-now-{thread_id}.jsonl";transcript.write_text("")
            event={"hook_event_name":"PermissionRequest","session_id":"native-session","turn_id":"turn1","tool_name":"Bash","transcript_path":str(transcript),"tool_input":{"command":"SECRET"}}
            for _ in range(200):
                self.invoke(event,root/"state",sessions,lambda *a:sent.append(a))
            self.assertEqual(sent,[])
            self.assertFalse(w.Store(root/"state",thread_id).notice.exists())

    def test_subagent_start_stop(self):
        thread_id="01a164a0-5c54-7503-abf2-9db080855287";base={"session_id":"different-native-session","turn_id":"turn1","agent_id":"agent-private"}
        with tempfile.TemporaryDirectory() as d:
            root=Path(d);sessions=root/"sessions";sessions.mkdir();transcript=sessions/f"rollout-now-{thread_id}.jsonl";transcript.write_text("");event={**base,"transcript_path":str(transcript)}
            self.invoke({**event,"hook_event_name":"SubagentStart"},root/"state",sessions,lambda *a:None);self.assertTrue(w.Store(root/"state",thread_id).active_subagents(time.time()))
            self.invoke({**event,"hook_event_name":"SubagentStop"},root/"state",sessions,lambda *a:None);self.assertFalse(w.Store(root/"state",thread_id).active_subagents(time.time()))
    def test_permission_hook_fake_http_transport_no_stdout_or_decision(self):
        requests=[]
        class Response:
            def __enter__(self):return self
            def __exit__(self,*_):return False
            def read(self,_):return b"x"
        event={"hook_event_name":"PermissionRequest","session_id":"native-session","turn_id":"turn1","tool_name":"Bash","tool_input":{"command":"PRIVATE"}}
        with tempfile.TemporaryDirectory() as d:
            args=SimpleNamespace(state_dir=Path(d)/"state",sessions_root=Path(d)/"sessions",ntfy_url="http://127.0.0.1:1/topic",network_timeout=1,subagent_max_seconds=60)
            fake=io.TextIOWrapper(io.BytesIO(json.dumps(event).encode()));stdout=io.StringIO()
            with mock.patch.object(sys,"stdin",fake),mock.patch.object(w.urllib.request,"urlopen",side_effect=lambda request,timeout:(requests.append(request),Response())[1]),redirect_stdout(stdout):self.assertEqual(w.hook(args),0)
        self.assertEqual(stdout.getvalue(),"");self.assertEqual(requests,[]);self.assertNotIn("decision",stdout.getvalue())
    def test_unresolved_permission_does_not_suppress_idle_fallback(self):
        thread_id="01a164a0-5c54-7503-abf2-9db080855287"
        with tempfile.TemporaryDirectory() as d:
            root=Path(d);sessions=root/"sessions";sessions.mkdir();transcript=sessions/f"rollout-now-{thread_id}.jsonl";transcript.write_text("")
            event={"hook_event_name":"PermissionRequest","session_id":"different-native-session","turn_id":"turn1","tool_name":"Bash","transcript_path":str(transcript),"tool_input":{"command":"PRIVATE"}}
            self.invoke(event,root/"state",sessions,lambda *a:None)
            self.assertFalse(w.Store(root/"state",thread_id).notice.exists());self.assertFalse(w.Store(root/"state","different-native-session").notice.exists())

class WrapperTests(unittest.TestCase):
    def test_wrapper_preserves_exit_and_marker_contains_no_command(self):
        with tempfile.TemporaryDirectory() as d:
            root=Path(d);session="thread123";script=Path(w.__file__)
            proc=subprocess.Popen([sys.executable,str(script),"run-command","--session-id",session,"--cwd",d,"--state-dir",d,"/bin/sh","-c","sleep 0.4; exit 7"])
            marker_dir=w.Store(root,session).commands;marker=None
            for _ in range(30):
                files=list(marker_dir.glob("*.json")) if marker_dir.exists() else []
                if files:marker=files[0];break
                time.sleep(.02)
            self.assertIsNotNone(marker);text=marker.read_text();self.assertNotIn("sleep",text);self.assertNotIn("/bin/sh",text)
            self.assertEqual(proc.wait(),7);self.assertEqual(list(marker_dir.glob("*.json")),[])
    def test_wrapper_normalizes_signal_exit(self):
        with tempfile.TemporaryDirectory() as d:
            result=subprocess.run([sys.executable,w.__file__,"run-command","--session-id","thread123","--cwd",d,"--state-dir",d,"--","/bin/sh","-c","kill -TERM $$"])
            self.assertEqual(result.returncode,143)

class GuardTests(unittest.TestCase):
    def test_private_tmp_default_is_consistent(self):
        expected=Path("/private/tmp")/f"codex-watchdog-{os.getuid()}";parser=w.parser()
        self.assertEqual(parser.parse_args(["start","--thread-id","thread123"]).state_dir,expected)
        self.assertEqual(parser.parse_args(["stop","--thread-id","thread123"]).state_dir,expected)
        self.assertEqual(parser.parse_args(["run-command","--session-id","thread123","--cwd","/tmp","--","/bin/true"]).state_dir,expected)
        self.assertEqual(parser.parse_args(["hook"]).state_dir,expected)
    def test_duplicate_lock_rejected(self):
        with tempfile.TemporaryDirectory() as d:
            path=Path(d)/"lock";first=w.acquire(path)
            try:
                with self.assertRaises(RuntimeError):w.acquire(path)
            finally:first.close()
    def test_log_inside_sessions_rejected(self):
        with tempfile.TemporaryDirectory() as d:
            root=Path(d);session=root/"rollout-x-thread123.jsonl";session.write_text("")
            args=SimpleNamespace(state_dir=root.parent/"state",sessions_root=root,log_file=root/"watch.log")
            with self.assertRaises(ValueError):w.validate_storage(args,session)
    def test_state_symlink_rejected(self):
        with tempfile.TemporaryDirectory() as d:
            root=Path(d);real=root/"real";real.mkdir();link=root/"link";link.symlink_to(real,target_is_directory=True)
            with self.assertRaises(ValueError):w.secure_state_dir(link)
    def test_discovery_exact_thread(self):
        with tempfile.TemporaryDirectory() as d:
            root=Path(d);wanted=root/"rollout-now-thread123.jsonl";other=root/"rollout-now-other123.jsonl";wanted.write_text("");other.write_text("")
            self.assertEqual(w.discover_session("thread123",root),wanted)
    def test_start_duplicate_and_stop_integration(self):
        thread_id="01a164a0-5c54-7503-abf2-9db080855287"
        with tempfile.TemporaryDirectory() as d:
            root=Path(d);sessions=root/"sessions";sessions.mkdir();(sessions/f"rollout-now-{thread_id}.jsonl").write_text("");state=root/"state";script=Path(w.__file__)
            base=[sys.executable,str(script),"start","--thread-id",thread_id,"--sessions-root",str(sessions),"--state-dir",str(state),"--timeout","60","--poll","0.1","--dry-run"]
            first=subprocess.run(base,text=True,capture_output=True,timeout=5);self.assertEqual(first.returncode,0,first.stderr)
            second=subprocess.run(base,text=True,capture_output=True,timeout=5);self.assertEqual(second.returncode,2)
            stopped=subprocess.run([sys.executable,str(script),"stop","--thread-id",thread_id,"--state-dir",str(state)],text=True,capture_output=True,timeout=5);self.assertEqual(stopped.returncode,0,stopped.stderr)
    def test_stale_permission_notice_does_not_suppress_new_watcher(self):
        thread_id="01a164a0-5c54-7503-abf2-9db080855287"
        with tempfile.TemporaryDirectory() as d:
            root=Path(d);sessions=root/"sessions";sessions.mkdir();(sessions/f"rollout-now-{thread_id}.jsonl").write_text("");state=root/"state";store=w.Store(state,thread_id);w.atomic_json(store.notice,{"notified":time.time()-100});log=root/"watch.log";script=Path(w.__file__)
            started=subprocess.run([sys.executable,str(script),"start","--thread-id",thread_id,"--sessions-root",str(sessions),"--state-dir",str(state),"--timeout","0.2","--poll","0.05","--log-file",str(log),"--dry-run"],text=True,capture_output=True,timeout=5);self.assertEqual(started.returncode,0,started.stderr)
            time.sleep(.4);subprocess.run([sys.executable,str(script),"stop","--thread-id",thread_id,"--state-dir",str(state)],check=True,timeout=5)
            self.assertIn("event=dry-run-alert",log.read_text())

if __name__=="__main__":unittest.main()

#!/usr/bin/env python3
"""Idempotent, private event publishing; no provider API key required."""
import argparse,json,os,sys,time,uuid,urllib.request
from pathlib import Path

class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *args, **kwargs): return None


def main():
 p=argparse.ArgumentParser();p.add_argument('kind',nargs='?',choices=['success','blocker','input','optional','progress','status']);p.add_argument('summary',nargs='?');p.add_argument('--body',default='');p.add_argument('--preview');p.add_argument('--title');p.add_argument('--flush',action='store_true');p.add_argument('--resolve');p.add_argument('--done',action='store_true');p.add_argument('--accept-decline',action='store_true');p.add_argument('--report',action='store_true');args=p.parse_args()
 if args.report and args.kind!='progress':p.error('--report requires progress')
 if args.done and args.kind!='success':p.error('--done requires success')
 if args.kind=='success' and not args.done:p.error('success requires --done')
 if args.accept_decline and args.kind not in ('input','optional'):p.error('--accept-decline requires input or optional')
 if args.preview is not None and not args.kind:p.error('--preview requires an event kind')
 config_path=Path(os.environ.get('CODEX_INBOX_CONFIG',str(Path.home()/'.config/codex-inbox/agent.json')))
 if not config_path.is_file():raise SystemExit('Inbox unavailable: host configuration missing; continue in original chat.')
 if config_path.stat().st_mode&0o077:raise SystemExit('Inbox configuration must be mode 0600.')
 config=json.loads(config_path.read_text());spool=config_path.parent/'outbox';spool.mkdir(mode=0o700,exist_ok=True)
 if args.resolve:
  request=urllib.request.Request(config['url'].rstrip('/')+'/api/inbox/events/'+str(uuid.UUID(args.resolve))+'/resolve',data=b'{}',headers={'Authorization':'Bearer '+config['agentToken'],'Content-Type':'application/json'})
  with urllib.request.build_opener(NoRedirect()).open(request,timeout=10) as response:
   if response.status!=200:raise SystemExit('Request resolution rejected')
  print('Inbox request resolved.');return
 if args.kind:
  chat=os.environ.get('CODEX_THREAD_ID')
  if not chat:raise SystemExit('CODEX_THREAD_ID unavailable; refusing to guess chat.')
  if not args.summary:raise SystemExit('Summary required.')
  if not args.summary.strip():raise SystemExit('Summary required.')
  if args.preview is not None and (not args.preview.strip() or len(args.preview.strip())>60):raise SystemExit('Preview must be 1–60 characters.')
  status=args.kind=='status' or (args.kind=='progress' and not args.report)
  if status:
   if args.kind=='status' and args.body: p.error('Status does not accept --body')
   summary=(args.preview or args.summary).strip()
   if len(summary)>60:raise SystemExit('Status must be 1–60 characters; provide --preview for a shorter status.')
   event=dict(id=str(uuid.uuid4()),chatId=chat,hostId=config['hostId'],summary=summary,reportedAt=time.time(),_endpoint='status')
  else:
   event=dict(id=str(uuid.uuid4()),chatId=chat,hostId=config['hostId'],kind=args.kind,summary=args.summary,body=args.body)
   if args.preview is not None:event['preview']=args.preview.strip()
   if args.accept_decline:event['responseType']='accept-decline'
   if args.done:event['lifecycle']='done'
   if args.report:event['report']=True
  if args.title:event['title']=args.title
  target=spool/(event['id']+'.json')
  with open(target,'x',opener=lambda path,flags:os.open(path,flags,0o600)) as f:json.dump(event,f)
 elif not args.flush: p.error('Provide a kind and summary or --flush')
 failures=0
 for path in sorted(spool.glob('*.json')):
  try:
   event=json.loads(path.read_text());endpoint=event.pop('_endpoint','events')
   if endpoint not in ('events','status'):raise ValueError('Invalid queued endpoint')
   payload=dict(event)
   if endpoint=='status':payload.pop('id',None)
   request=urllib.request.Request(config['url'].rstrip('/')+'/api/inbox/'+endpoint,data=json.dumps(payload).encode(),headers={'Authorization':'Bearer '+config['agentToken'],'Content-Type':'application/json'})
   with urllib.request.build_opener(NoRedirect()).open(request,timeout=10) as response:
    if response.status!=200:raise ValueError('Rejected')
   path.unlink()
  except Exception:failures+=1
 if failures:raise SystemExit(f'Inbox unavailable: {failures} event(s) queued privately; continue in original chat.')
 print('Inbox delivered'+(': '+event['id'] if args.kind else '')+'.')
if __name__=='__main__':main()

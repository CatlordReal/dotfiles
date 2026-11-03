#!/usr/bin/env python3
"""Idempotent, private event publishing; no provider API key required."""
import argparse,json,os,sys,uuid,urllib.request
from pathlib import Path

class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *args, **kwargs): return None


def main():
 p=argparse.ArgumentParser();p.add_argument('kind',nargs='?',choices=['success','blocker','input','optional','progress']);p.add_argument('summary',nargs='?');p.add_argument('--body',default='');p.add_argument('--title');p.add_argument('--flush',action='store_true');p.add_argument('--resolve');p.add_argument('--done',action='store_true');args=p.parse_args()
 if args.done and args.kind!='success':p.error('--done requires success')
 config_path=Path(os.environ.get('CODEX_INBOX_CONFIG',str(Path.home()/'.config/codex-inbox/agent.json')))
 if not config_path.is_file():raise SystemExit('Inbox unavailable: host configuration missing; keep ntfy active.')
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
  event=dict(id=str(uuid.uuid4()),chatId=chat,hostId=config['hostId'],kind=args.kind,summary=args.summary,body=args.body)
  if args.title:event['title']=args.title
  if args.done:event['lifecycle']='done'
  target=spool/(event['id']+'.json')
  with open(target,'x',opener=lambda path,flags:os.open(path,flags,0o600)) as f:json.dump(event,f)
 elif not args.flush: p.error('Provide a kind and summary or --flush')
 failures=0
 for path in sorted(spool.glob('*.json')):
  try:
   event=json.loads(path.read_text());request=urllib.request.Request(config['url'].rstrip('/')+'/api/inbox/events',data=json.dumps(event).encode(),headers={'Authorization':'Bearer '+config['agentToken'],'Content-Type':'application/json'})
   with urllib.request.build_opener(NoRedirect()).open(request,timeout=10) as response:
    if response.status!=200:raise ValueError('Rejected')
   path.unlink()
  except Exception:failures+=1
 if failures:raise SystemExit(f'Inbox unavailable: {failures} event(s) queued privately; keep ntfy active.')
 print('Inbox delivered'+(': '+event['id'] if args.kind else '')+'.')
if __name__=='__main__':main()

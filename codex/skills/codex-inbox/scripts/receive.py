#!/usr/bin/env python3
"""Receive replies for this active original chat without touching desktop IPC."""
import argparse,json,os,time,uuid,urllib.request,urllib.error
from pathlib import Path

def main():
 p=argparse.ArgumentParser();p.add_argument('--wait',type=int,default=0);p.add_argument('--ack');args=p.parse_args()
 if not 0<=args.wait<=60:p.error('Wait must be between 0 and 60 seconds')
 chat=os.environ.get('CODEX_THREAD_ID')
 if not chat:raise SystemExit('CODEX_THREAD_ID unavailable; refusing to guess chat.')
 # Current chat selection is a helper guard; the credential itself is host-scoped.
 uuid.UUID(chat)
 path=Path(os.environ.get('CODEX_INBOX_CONFIG',str(Path.home()/'.config/codex-inbox/agent.json')))
 if not path.is_file():raise SystemExit('Inbox unavailable: host configuration missing.')
 if path.stat().st_mode&0o077:raise SystemExit('Inbox configuration must be mode 0600.')
 c=json.loads(path.read_text());receipts=path.parent/'receipts'/chat;receipts.mkdir(mode=0o700,parents=True,exist_ok=True)
 def post(endpoint,data):
  req=urllib.request.Request(c['url'].rstrip('/')+'/api/inbox'+endpoint,data=json.dumps(data).encode(),headers={'Authorization':'Bearer '+c['agentToken'],'Content-Type':'application/json'})
  with urllib.request.urlopen(req,timeout=10) as response:return json.load(response)
 if args.ack:
  receipt=receipts/(str(uuid.UUID(args.ack))+'.json');data=json.loads(receipt.read_text())
  post('/agent/ack',dict(chatId=chat,id=data['id'],leaseToken=data['leaseToken']));receipt.unlink();print('Inbox reply acknowledged.');return
 end=time.monotonic()+args.wait
 while True:
  result=post('/agent/receive',{'chatId':chat})
  if result['messages']:
   for message in result['messages']:
    receipt=receipts/(str(uuid.UUID(message['id']))+'.json')
    with open(receipt,'w',opener=lambda path,flags:os.open(path,flags,0o600)) as f:json.dump(dict(id=message['id'],leaseToken=message.pop('leaseToken')),f)
    # The agent explicitly ACKs only after observing this tool result.
    print(json.dumps({'source':'Codex Inbox user reply','message':message,'acknowledgeWith':'receive.py --ack '+message['id']},ensure_ascii=False),flush=True)
   return
  if time.monotonic()>=end:print('No Inbox replies.');return
  time.sleep(min(3,max(0,end-time.monotonic())))
if __name__=='__main__':
 try:main()
 except urllib.error.HTTPError as exc:
  print(f'Inbox receive unavailable (HTTP {exc.code}); check host authorization and endpoint. No reply acknowledged.',file=__import__('sys').stderr);raise SystemExit(1)
 except (OSError,ValueError) as exc:
  print('Inbox receive unavailable: '+type(exc).__name__+'. No reply acknowledged.',file=__import__('sys').stderr);raise SystemExit(1)

"""Pure byte fixtures: not owned process, stack, Godot or callback proof."""
from pathlib import Path
import copy,hashlib,json,sys,argparse
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT/'tools'));sys.dont_write_bytecode=True
from campaign_callback_packets_v2 import CallbackPackets,json_value
from campaign_callback_snapshot_wire_v1 import CASES
from godot_debug_wire import encode,WireError

def main():
 p=argparse.ArgumentParser();p.add_argument('--output',type=Path,default=Path(__file__).with_suffix('.json'));a=p.parse_args();checks=[]
 identity={'save_eligible':True,'synthetic':True};user='D:/synthetic/appdata/Godot/app_userdata/game'
 def packet(name,data,thread=77):return encode([name,thread,data])
 def ready(case):return packet('lsh_callback19:ready',[12345,'a'*32,case,json.dumps({'campaign_id':101,'cloud_id':102,'identity':identity,'user_directory':user})])
 def value(case,seq):return {'schema':'campaign_callback_readonly_snapshot_v1','pid':12345,'nonce':'a'*32,'case':case,'sequence':seq,'identity':identity,'user_directory':user,'campaign_id':101,'cloud_id':102,'campaign_memory':{'records':{'level1':{'done_ids':['x']}},'unlocked':2,'owner':''},'cloud_state':{'dirty':False,'pending_upload':False,'revision':0,'applying':True,'owner':'123456789','shared_profile_pending':False},'campaign_persistence_busy':False,'time_scale':1.0,'physics_ticks':60,'original19_qualified':False,'SDK_reward_once_qualified':False,'overall_goal_qualified':False}
 def snapshot(case,seq,doc=None,thread=77):return packet('lsh_callback19:snapshot',[12345,'a'*32,case,seq,json.dumps(value(case,seq) if doc is None else doc)],thread)
 def consumer(case):return CallbackPackets(12345,'a'*32,case,identity,user)
 def passed(label):checks.append({'label':label,'passed':True})
 for case in CASES:
  c=consumer(case);raw=ready(case);result=c.consume_ready(raw);assert result['raw']==raw and not result['ownership_proven'];passed(case+' ready raw bytes')
  for seq in range(1,9):
   raw=snapshot(case,seq);result=c.consume_snapshot(raw,77,seq);assert result['sha256']==hashlib.sha256(raw).hexdigest() and result['raw']==raw and not result['native_qualified'];passed(case+' sequence '+str(seq))
 def refuse(label,action):
  try:action()
  except (WireError,UnicodeError):passed(label)
  else:raise AssertionError('Accepted '+label)
 case=CASES[0]
 refuse('snapshot before ready',lambda:consumer(case).consume_snapshot(snapshot(case,1),77,1))
 c=consumer(case);c.consume_ready(ready(case));refuse('duplicate ready',lambda:c.consume_ready(ready(case)))
 refuse('wrong thread',lambda:c.consume_snapshot(snapshot(case,1,thread=78),77,1))
 refuse('skipped sequence',lambda:c.consume_snapshot(snapshot(case,2),77,2))
 for key,bad in [('pid',True),('nonce','b'*32),('case',CASES[1]),('sequence',True),('campaign_id',103),('cloud_id',True),('identity',{'save_eligible':1,'synthetic':True}),('user_directory',user+'other'),('original19_qualified',True),('SDK_reward_once_qualified',0),('overall_goal_qualified',True),('time_scale',True),('physics_ticks',True),('campaign_persistence_busy',0)]:
  v=value(case,1);v[key]=bad;refuse('snapshot rejects '+key,lambda v=v:c.consume_snapshot(snapshot(case,1,v),77,1));assert c.sequence==0
 for group,key,bad in [('cloud_state','applying',1),('cloud_state','revision',True),('campaign_memory','unlocked',True),('campaign_memory','records',[]),('campaign_memory','owner',1)]:
  v=value(case,1);v[group][key]=bad;refuse(group+' rejects '+key,lambda v=v:c.consume_snapshot(snapshot(case,1,v),77,1));assert c.sequence==0
 v=value(case,1);v['extra']=False;refuse('unknown field',lambda:c.consume_snapshot(snapshot(case,1,v),77,1))
 c.consume_snapshot(snapshot(case,1),77,1);refuse('replayed snapshot',lambda:c.consume_snapshot(snapshot(case,1),77,1))
 for text,label in [('{"x":1,"x":2}','duplicate JSON'),('{"x":NaN}','NaN JSON'),('{"x":1e999}','overflow float JSON'),('['*40+'0'+']'*40,'deep JSON')]:refuse(label,lambda text=text:json_value(text))
 for text,label in [('\"\\ud800\"','surrogate string JSON'),('{\"\\udfff\":0}','surrogate key JSON')]:refuse(label,lambda text=text:json_value(text))
 refuse('trailing wire bytes',lambda:consumer(case).consume_ready(ready(case)+b'\0'))
 refuse('boolean binding PID',lambda:CallbackPackets(True,'a'*32,case,identity,user))
 result={'schema':'callback_packets_synthetic_host_checks_v2','script_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'checks':checks,'count':len(checks),'all_passed':True,'classification':'synthetic scalar-wire and JSON fixtures only','Popen_started':False,'socket_connected':False,'Godot_started':False,'actual_callback_qualified':False,'approved_stages':[]}
 with a.output.open('x',encoding='utf-8',newline='\n') as f:json.dump(result,f,ensure_ascii=False,indent=2);f.write('\n')
 print(json.dumps({'synthetic_checks':len(checks),'all_passed':True,'native_started':False}))
if __name__=='__main__':main()

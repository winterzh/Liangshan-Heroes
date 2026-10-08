"""Full synthetic snapshot Unicode regression; no actual native callback."""
from pathlib import Path
import ast,hashlib,json,sys
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT/'tools'));sys.dont_write_bytecode=True
from campaign_callback_packets_v2 import CallbackPackets
from godot_debug_wire import encode,WireError

def main():
 q=Path(__file__).parent;fixture_path=q/'CALLBACK_PACKETS_SYNTHETIC_HOST_CHECKS_V2.py';mod=ast.parse(fixture_path.read_bytes())
 mainfn=next(n for n in mod.body if isinstance(n,ast.FunctionDef) and n.name=='main');fn=next(n for n in mainfn.body if isinstance(n,ast.FunctionDef) and n.name=='value')
 identity={'save_eligible':True,'synthetic':True};user='D:/synthetic/appdata/Godot/app_userdata/game';ns={};exec(compile(ast.Module(body=[fn],type_ignores=[]),'synthetic-value','exec'),{'identity':identity,'user':user},ns)
 case='callback_sees_new_memory';checks=[]
 for bad,label in [({'text':'\ud800'},'surrogate value'),({'\udfff':0},'surrogate key'),({'text':'\x00'},'legal NUL value')]:
  c=CallbackPackets(12345,'a'*32,case,identity,user);ready={'campaign_id':101,'cloud_id':102,'identity':identity,'user_directory':user}
  c.consume_ready(encode(['lsh_callback19:ready',77,[12345,'a'*32,case,json.dumps(ready)]]));v=ns['value'](case,1);v['campaign_memory']['records']['future']=bad
  raw=encode(['lsh_callback19:snapshot',77,[12345,'a'*32,case,1,json.dumps(v)]])
  if label=='legal NUL value':
   result=c.consume_snapshot(raw,77,1);json.dumps(result['observation'],ensure_ascii=False).encode('utf-8');assert c.sequence==1
  else:
   try:c.consume_snapshot(raw,77,1)
   except WireError:assert c.sequence==0
   else:raise AssertionError('surrogate accepted')
  checks.append({'label':label,'passed':True})
 def pin(p):
  raw=p.read_bytes();return {'path':str(p),'bytes':len(raw),'sha256':hashlib.sha256(raw).hexdigest()}
 result={'schema':'callback_packets_unicode_regression_v2','source_pins':[pin(Path(__file__)),pin(fixture_path),pin(ROOT/'tools/campaign_callback_packets_v2.py')],'checks':checks,'all_passed':True,'synthetic_only':True,'native_started':False,'approved_stages':[]}
 with Path(__file__).with_suffix('.json').open('x',encoding='utf-8',newline='\n') as f:json.dump(result,f,ensure_ascii=False,indent=2);f.write('\n')
 print('Full snapshot Unicode regression 3 synthetic checks passed')
if __name__=='__main__':main()

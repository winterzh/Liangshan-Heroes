"""Synthetic stack contract and fake-owner refusal only; no native execution."""
from pathlib import Path
import argparse,copy,hashlib,json,sys
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT/'tools'));sys.dont_write_bytecode=True
from campaign_callback_controller_v2 import STACKS,matches_stack,CallbackController,expected_native_identity
from godot_debug_wire import WireError
from campaign_callback_packets_v2 import same

def main():
 parser=argparse.ArgumentParser();parser.add_argument('--output',type=Path,default=Path(__file__).with_suffix('.json'));args=parser.parse_args();checks=[]
 def passed(v):checks.append({'label':v,'passed':True})
 for case,frames in STACKS.items():
  assert matches_stack(case,copy.deepcopy(frames));passed(case+' exact prefix')
  assert matches_stack(case,copy.deepcopy(frames)+[{'source':'res://tools/future.gd','line':1,'function':'driver'}]);passed(case+' tail retained')
  for n in range(len(frames)):
   for key,badvalue in [('line',frames[n]['line']+1),('source','res://scripts/other.gd'),('function','fake_callback')]:
    bad=copy.deepcopy(frames);bad[n][key]=badvalue;assert not matches_stack(case,bad);passed(case+' wrong '+key+' '+str(n))
  assert not matches_stack(case,frames[:-1]);passed(case+' missing frame')
  try:CallbackController(None,object(),{},None,case,None,None,None,None)
  except WireError:passed(case+' fake owner refused')
  else:raise AssertionError('fake ownership accepted')
 try:matches_stack('legacy_real_cloud_apply_failure_boundary',[])
 except WireError:passed('fault case not silently treated as callback')
 else:raise AssertionError('fault case accepted')
 fields={'content_version':'source-v1:'+'a'*64,'rules_sha256':'b'*64,'file_count':2,'total_bytes':8,'engine_binary_sha256':'c'*64,'provider_sha256':'d'*64}
 installed={k:fields[k] for k in ['content_version','rules_sha256','file_count','total_bytes']};installed.update(files=[{'path':'scripts/run_content_identity.gd','bytes':5,'sha256':'d'*64},{'path':'content/units.json','bytes':3,'sha256':'e'*64}],directories={'scripts':True,'content':True})
 expected=expected_native_identity(fields,installed);assert len(expected)==15 and expected['source_mode'] is True and expected['source_sha256']=='a'*64;passed('full Provider identity shape/status/source')
 assert expected['optional_content']==[{'path':'content/units.json','present':True,'bytes':3,'sha256':'e'*64},{'path':'content/abilities.json','present':False,'bytes':0,'sha256':''}];passed('actual present and absent optional inventory binding')
 for key in expected:
  bad=copy.deepcopy(expected);del bad[key];assert not same(bad,expected);passed('missing native field '+key)
 for key,badvalue in [('ok',False),('identity_schema',True),('source_mode',1),('save_code','BAD'),('identity_scope','other'),('source_sha256','f'*64),('file_count',True),('total_bytes',True)]:
  bad=copy.deepcopy(expected);bad[key]=badvalue;assert not same(bad,expected);passed('wrong native field '+key)
 for key,badvalue in [('present',1),('bytes',True),('sha256','f'*64),('path','content/other.json')]:
  bad=copy.deepcopy(expected);bad['optional_content'][0][key]=badvalue;assert not same(bad,expected);passed('wrong optional native '+key)
 for key,badvalue in [('file_count',True),('total_bytes',9),('provider_sha256','f'*64),('content_version','source-v1:bad')]:
  bad=copy.deepcopy(fields);bad[key]=badvalue
  try:expected_native_identity(bad,installed)
  except WireError:passed('host binding rejects '+key)
  else:raise AssertionError('invalid original runtime fields accepted')
 source=ROOT/'tools/campaign_callback_controller_v2.py';result={'schema':'callback_controller_synthetic_host_checks_v2','checks':checks,'count':len(checks),'all_passed':True,'script_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'synthetic_only':True,'socket_connected':False,'Popen_started':False,'native_started':False,'controller_pipeline_proven':False,'approved_stages':[]}
 with args.output.open('x',encoding='utf-8',newline='\n') as stream:json.dump(result,stream,ensure_ascii=False,indent=2);stream.write('\n')
 print(json.dumps({'synthetic_checks':len(checks),'all_passed':True,'native_started':False}))
if __name__=='__main__':main()

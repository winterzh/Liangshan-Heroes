"""Synthetic stack contract and fake-owner refusal only; no native execution."""
from pathlib import Path
import argparse,copy,hashlib,json,sys
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT/'tools'));sys.dont_write_bytecode=True
from campaign_callback_controller_v1 import STACKS,matches_stack,CallbackController
from godot_debug_wire import WireError

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
 source=ROOT/'tools/campaign_callback_controller_v1.py';result={'schema':'callback_controller_synthetic_host_checks_v1','checks':checks,'count':len(checks),'all_passed':True,'script_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'synthetic_only':True,'socket_connected':False,'Popen_started':False,'native_started':False,'controller_pipeline_proven':False,'approved_stages':[]}
 with args.output.open('x',encoding='utf-8',newline='\n') as stream:json.dump(result,stream,ensure_ascii=False,indent=2);stream.write('\n')
 print(json.dumps({'synthetic_checks':len(checks),'all_passed':True,'native_started':False}))
if __name__=='__main__':main()

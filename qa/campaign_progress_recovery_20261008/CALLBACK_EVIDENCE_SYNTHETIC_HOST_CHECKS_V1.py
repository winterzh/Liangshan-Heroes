"""Fabricated packet files/metadata only; not native owner or full consumer proof."""
from pathlib import Path
import argparse,copy,hashlib,json,struct,sys,tempfile
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT/'tools'));sys.dont_write_bytecode=True
from campaign_callback_packet_evidence_v1 import replay_callback_packets
from campaign_callback_controller_v3 import STACKS,STOP
from campaign_natural_callback_evidence_v1 import NaturalCallbackEvidence
from prepare_campaign_callback_labels_v1 import build
from godot_debug_wire import encode,WireError
class SuiteFixture:
 def __init__(self,run):self.run=run;self.pins={};self.batch=type('BatchFixture',(),{'steps':[],'child':object()})()
 def freeze_bytes(self,p,h=None):
  raw=Path(p).read_bytes();digest=hashlib.sha256(raw).hexdigest();assert h is None or digest==h;key=str(Path(p).resolve());assert key not in self.pins or self.pins[key]==digest;self.pins[key]=digest;return raw

def fixture(root,tail=b''):
 run=Path(tempfile.mkdtemp(prefix='fixture-',dir=str(root)));out=run/'steps/callback_first';directory=out/'callback_packets';directory.mkdir(parents=True);suite=SuiteFixture(run);step={'pid':12345,'nonce':'a'*32,'output':str(out)};rows=[];identity={'save_eligible':True,'synthetic':True};user=run/'profiles/test/appdata/Godot/game';seal={'campaign_id':101,'level_record':{'cleared':True,'story_complete':True,'best_done':4}}
 def add(direction,raw):
  path=directory/('%04d_%s.bin'%(len(rows)+1,direction));path.write_bytes(raw);row={'order':len(rows)+1,'direction':direction,'path':str(path),'bytes':len(raw),'sha256':hashlib.sha256(raw).hexdigest()};rows.append(row);return row
 def network(msg):
  body=encode(msg);raw=struct.pack('<I',len(body))+body;add('receive_frame',raw);add('receive',raw);return body
 def send(msg):
  body=encode(msg);raw=struct.pack('<I',len(body))+body;row=add('send_attempt',raw);row['completion']=add('send_complete',b'CALLBACK_SEND_COMPLETE\n'+row['sha256'].encode('ascii'))
 case='callback_sees_new_memory';network(['set_pid',77,[12345]]);send(['breakpoint',77,[STOP['source'],STOP['line'],True]])
 ready={'campaign_id':101,'cloud_id':102,'identity':identity,'user_directory':str(user)};network(['lsh_callback19:ready',77,[12345,'a'*32,case,json.dumps(ready)]])
 network(['debug_enter',77,[True,'Breakpoint',True,77]]);send(['get_stack_dump',77,[]]);frames=copy.deepcopy(STACKS[case]);flat=[3*len(frames)]
 for f in frames:flat.extend([f['source'],f['line'],f['function']])
 network(['stack_dump',77,flat]);send(['lsh_callback19:read',77,[12345,'a'*32,case,1]])
 value={'schema':'campaign_callback_readonly_snapshot_v1','pid':12345,'nonce':'a'*32,'case':case,'sequence':1,'identity':identity,'user_directory':str(user),'campaign_id':101,'cloud_id':102,'campaign_memory':{'records':{'level1':seal['level_record']},'unlocked':2,'owner':''},'cloud_state':{'dirty':False,'pending_upload':False,'revision':0,'applying':False,'owner':'','shared_profile_pending':False},'campaign_persistence_busy':False,'time_scale':1.0,'physics_ticks':60,'original19_qualified':False,'SDK_reward_once_qualified':False,'overall_goal_qualified':False}
 snap=network(['lsh_callback19:snapshot',77,[12345,'a'*32,case,1,json.dumps(value)]]);send(['breakpoint',77,[STOP['source'],STOP['line'],False]]);send(['continue',77,[]]);tailrows=[]
 if tail:tailrows.append(add('terminal_tail_bytes',tail))
 add('terminal_transport_eof',b'CALLBACK_TERMINAL_TRANSPORT_EOF\n');step['callback_events']=rows;step['terminal_tail']=tailrows;step['callback_observation']={'case':case,'pid':12345,'nonce':'a'*32,'actual_frames':frames,'events':rows,'snapshot_sha256':hashlib.sha256(snap).hexdigest(),'observation':value,'actual_case_qualified':False,'original19_qualified':False,'SDK_reward_once_qualified':False,'overall_goal_qualified':False}
 return suite,step,identity,user,seal

def main():
 parser=argparse.ArgumentParser();parser.add_argument('--output',type=Path,default=Path(__file__).with_suffix('.json'));args=parser.parse_args();root=Path(tempfile.mkdtemp(prefix='lsh-callback-evidence-',dir='D:/CodexTemp'));checks=[]
 def passed(label):checks.append({'label':label,'passed':True})
 def refuse(label,action):
  try:action()
  except (WireError,ValueError,RuntimeError,AssertionError,KeyError):passed(label)
  else:raise AssertionError('Accepted '+label)
 f=fixture(root);v=replay_callback_packets(*f);assert not v['native_ownership_proven'] and not v['whole_suite_qualified'];passed('complete synthetic original request/reply/resume replay')
 noise=encode(['debug_exit',77,[]]);tail=struct.pack('<I',len(noise))+noise;v=replay_callback_packets(*fixture(root,tail));assert v['transport_eof']=='terminal';passed('valid complete terminal noise replay')
 refuse('truncated terminal body rejected',lambda:replay_callback_packets(*fixture(root,tail[:-1])))
 unknown=encode(['lsh_callback19:snapshot',77,[]]);refuse('late snapshot cannot add control claims',lambda:replay_callback_packets(*fixture(root,struct.pack('<I',len(unknown))+unknown)))
 f=fixture(root);f[1]['callback_observation']['actual_frames'][1]['line']+=1;refuse('metadata stack differs from raw original',lambda:replay_callback_packets(*f))
 f=fixture(root);f[1]['callback_observation']['observation']['campaign_memory']['unlocked']=3;refuse('metadata memory differs from raw original',lambda:replay_callback_packets(*f))
 f=fixture(root);f[1]['callback_observation']['overall_goal_qualified']=True;refuse('observation cannot grant whole qualification',lambda:replay_callback_packets(*f))
 f=fixture(root);f[4]['campaign_id']=999;refuse('seal uses different actual campaign object',lambda:replay_callback_packets(*f))
 f=fixture(root);f[4]['level_record']={'cleared':False};refuse('callback memory must equal original full report record',lambda:replay_callback_packets(*f))
 f=fixture(root);Path(f[1]['callback_events'][0]['path']).write_bytes(b'drift');refuse('original packet byte drift',lambda:replay_callback_packets(*f))
 f=fixture(root);(Path(f[1]['output'])/'callback_packets/extra.bin').write_bytes(b'x');refuse('unlisted packet file rejected',lambda:replay_callback_packets(*f))
 f=fixture(root);f[1]['callback_events'][0]['order']=True;refuse('Boolean event index rejected',lambda:replay_callback_packets(*f))
 f=fixture(root);firstsend=next(row for row in f[1]['callback_events'] if row['direction']=='send_attempt');firstsend['completion']=dict(firstsend['completion'],bytes=1);refuse('send completion metadata cannot be forged',lambda:replay_callback_packets(*f))
 contract=build();assert len(contract['complete_labels_by_mode']['first'])==80 and len(contract['preterminal_ready_labels_by_mode']['first'])==56 and len(contract['complete_labels_by_mode']['restart_first'])==21;passed('80/56/21 source contract rebuilt')
 suite=SuiteFixture(root);manifest=json.loads((ROOT/'qa/campaign_progress_recovery_20261008/callback_natural_driver_candidate_v1/SOURCE.json').read_bytes());suite.runtime_fields={k:0 for k in contract['identity_fields_order']};consumer=NaturalCallbackEvidence(suite,contract,manifest)
 fake_step={'mode':'first','label':'callback_first','pid':12345,'nonce':'a'*32,'process_terminal':True,'exit_code':0,'engine_errors':0};suite.batch.steps=[fake_step]
 refuse('fake terminal child cannot run complete consumer',lambda:consumer.validate(fake_step,'first'))
 result={'schema':'callback_evidence_synthetic_host_checks_v1','script_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'source_sha256':{n:hashlib.sha256((ROOT/'tools'/n).read_bytes()).hexdigest() for n in ['campaign_callback_packet_evidence_v1.py','campaign_natural_callback_evidence_v1.py','prepare_campaign_callback_labels_v1.py']},'checks':checks,'count':len(checks),'all_passed':True,'work':str(root),'classification':'fabricated packet files/metadata and fake-child rejection only, not actual native Popen/complete consumer pipeline','socket_connected':False,'Popen_started':False,'native_started':False,'actual_callback_qualified':False,'approved_stages':[]}
 with args.output.open('x',encoding='utf-8',newline='\n') as f:json.dump(result,f,ensure_ascii=False,indent=2);f.write('\n')
 print(json.dumps({'synthetic_checks':len(checks),'all_passed':True,'native_started':False}))
if __name__=='__main__':main()

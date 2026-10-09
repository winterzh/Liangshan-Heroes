"""Synthetic bounded telemetry and native-export markers; no owned engine."""
from pathlib import Path
import argparse,copy,hashlib,json,struct,sys,tempfile
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT/'tools'));sys.dont_write_bytecode=True
from campaign_callback_controller_v2 import CallbackController as OldController
from campaign_callback_controller_v3 import CallbackController,MAX_CUSTODY_EVENTS,MAX_CUSTODY_BYTES
from campaign_callback_native_exports_v1 import CallbackNativeExports,NAMES
from godot_debug_wire import encode,WireError
class SuiteFixture:
 def __init__(self,run):self.run=run;self.pins={};self.persist_count=0;self.batch=type('BatchFixture',(),{'steps':[]})()
 def freeze_bytes(self,p,expected=None):
  p=Path(p);raw=p.read_bytes();h=hashlib.sha256(raw).hexdigest();assert expected is None or h==expected;key=str(p.resolve()).casefold();assert key not in self.pins or self.pins[key]==h;self.pins[key]=h;return raw
 def persist(self):self.persist_count+=1

def controller_fixture(cls,parent):
 # Constructor bypass isolated to this disk-retention primitive, never owner proof.
 x=object.__new__(cls);x.suite=SuiteFixture(parent);x.directory=parent/'packets';x.directory.mkdir();x.events=[];x.total_bytes=0;return x

def main():
 parser=argparse.ArgumentParser();parser.add_argument('--output',type=Path,default=Path(__file__).with_suffix('.json'));args=parser.parse_args();work=Path(tempfile.mkdtemp(prefix='lsh-callback-budget-',dir='D:/CodexTemp'));checks=[]
 def passed(label):checks.append({'label':label,'passed':True})
 def refuse(label,action):
  try:action()
  except (WireError,AssertionError,ValueError,FileExistsError):passed(label)
  else:raise AssertionError('Accepted '+label)
 body=encode(['performance:profile_frame',77,[float(n) for n in range(40)]]);frame=struct.pack('<I',len(body))+body
 oldroot=work/'old';oldroot.mkdir();old=controller_fixture(OldController,oldroot)
 for n in range(128):old._retain('receive_frame',frame);old._retain('receive',frame)
 refuse('old 256 events reject frame129 before natural phase horizon',lambda:old._retain('receive_frame',frame));assert len(old.events)==256
 newroot=work/'new';newroot.mkdir();new=controller_fixture(CallbackController,newroot)
 for n in range(1800):new._retain('receive_frame',frame);new._retain('receive',frame)
 assert len(new.events)==3600 and new.total_bytes==3600*len(frame);passed('1800 one-Hz frame pairs retained with exact bytes')
 for n in range(496):new._retain('synthetic_control',b'SYNTHETIC_CONTROL\n')
 assert len(new.events)==MAX_CUSTODY_EVENTS==4096;passed('496 control/refusal reserve reaches bounded4096')
 refuse('new event overflow still refused',lambda:new._retain('receive_frame',frame));assert len(new.events)==4096
 byteroot=work/'byte_limit';byteroot.mkdir();bytec=controller_fixture(CallbackController,byteroot);bytec.total_bytes=MAX_CUSTODY_BYTES
 refuse('64MiB cumulative overflow refused before write',lambda:bytec._retain('receive_frame',frame));assert not bytec.events and not list(bytec.directory.iterdir())
 for row in new.events:
  raw=Path(row['path']).read_bytes();assert len(raw)==row['bytes'] and hashlib.sha256(raw).hexdigest()==row['sha256']
 passed('all4096 original disk records independently reread with sameSHA')
 def exports_fixture(name):
  run=work/name;output=run/'steps'/'first';output.mkdir(parents=True);suite=SuiteFixture(run);step={'pid':12345,'nonce':'a'*32,'output':str(output)};suite.batch.steps=[step];return suite,step,output,CallbackNativeExports(suite,step)
 def seed(output,step,names):
  lines=[]
  for name in names:
   raw=(json.dumps({'synthetic':True,'name':name})+'\n').encode();stage=output/(name+'.native-'+step['nonce']);stage.write_bytes(raw);lines.append('CAMPAIGN_FILE19_EXPORT 12345 '+step['nonce']+' '+name+' '+hashlib.sha256(raw).hexdigest())
  (output/'native.log').write_text('\n'.join(lines)+'\n',encoding='utf-8',newline='\n')
 suite,step,out,ex=exports_fixture('exports');seed(out,step,sorted(NAMES));ex.require_complete('callback_sees_new_memory');assert set(ex.rows)==NAMES
 for row in ex.rows.values():assert Path(row['native_stage']).read_bytes()==Path(row['published_path']).read_bytes()
 passed('four fixed synthetic closed stages publish exact JSON bytes');before=copy.deepcopy(ex.rows);ex.publish();assert ex.rows==before;passed('original four export hashes stable on reread')
 refuse('other callback cannot claim fixed natural exports',lambda:ex.require_complete('cloud_applying_callback_no_upload_claim'))
 suite,step,out,ex=exports_fixture('partial');seed(out,step,['callback_driver_ready.json']);ex.publish();assert set(ex.rows)=={'callback_driver_ready.json'};refuse('missing terminal exports refuse complete',lambda:ex.require_complete('callback_sees_new_memory'))
 suite,step,out,ex=exports_fixture('extra');seed(out,step,['restart_handoff.json']);refuse('unallowed restart marker refused',lambda:ex.publish())
 suite,step,out,ex=exports_fixture('duplicate');seed(out,step,['report.json']);log=out/'native.log';raw=log.read_bytes();log.write_bytes(raw+raw);refuse('duplicate export marker refused',lambda:ex.publish())
 suite,step,out,ex=exports_fixture('nonce');seed(out,step,['report.json']);log=out/'native.log';log.write_text(log.read_text(encoding='utf-8').replace('a'*32,'b'*32),encoding='utf-8');refuse('foreign synthetic nonce refused',lambda:ex.publish())
 suite,step,out,ex=exports_fixture('overwrite');seed(out,step,['report.json']);(out/'report.json').write_bytes(b'original');refuse('existing public file cannot be replaced',lambda:ex.publish());assert (out/'report.json').read_bytes()==b'original'
 result={'schema':'callback_budget_exports_synthetic_host_checks_v1','script_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'source_sha256':{n:hashlib.sha256((ROOT/'tools'/n).read_bytes()).hexdigest() for n in ['campaign_callback_controller_v3.py','campaign_callback_native_exports_v1.py']},'checks':checks,'count':len(checks),'all_passed':True,'work':str(work),'classification':'synthetic constructor-bypassed private disk retention and forged PID/nonce/JSON markers only; not native ownership or whole pipeline','telemetry_frame_bytes':len(frame),'new_events':len(new.events),'new_retained_bytes':new.total_bytes,'socket_connected':False,'Popen_started':False,'native_started':False,'actual_engine_traffic_verified':False,'performance_qualified':False,'approved_stages':[]}
 with args.output.open('x',encoding='utf-8',newline='\n') as f:json.dump(result,f,ensure_ascii=False,indent=2);f.write('\n')
 print(json.dumps({'synthetic_checks':len(checks),'original_disk_records_verified':4096,'native_started':False}))
if __name__=='__main__':main()

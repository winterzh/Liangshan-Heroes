"""Private host environment and terminal stream fixtures; no real native phase."""
from pathlib import Path
import argparse,copy,hashlib,json,socket,sys,time
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT/'tools'));sys.dont_write_bytecode=True
from campaign_callback_runtime_v1 import validate_callback_environment,completed_terminal_transition,drain_terminal_tail,sealed_document,CallbackSerialBatch
from campaign_natural_terminal_runtime_v1 import NaturalSerialBatch
from godot_debug_wire import WireError
class SuiteFixture:
 def __init__(self,run):
  self.run=run;self.identity_path=run/'identity.json';self.runtime_fields={'synthetic':True};self.installed_identity={'synthetic_complete':True};raw=(json.dumps({'runtime_fields':self.runtime_fields,'complete_identity':self.installed_identity})+'\n').encode();self.identity_path.write_bytes(raw);self.evidence_by_path={str(self.identity_path.resolve()).casefold():{'sha256':hashlib.sha256(raw).hexdigest()}};self.spec={'pins':[]}
 def read_fixed(self,p,expected=None):
  raw=Path(p).read_bytes();assert expected is None or hashlib.sha256(raw).hexdigest()==expected;return json.loads(raw)
class ChildFixture:
 pid=12345
 def __init__(self,code=0):self.code=code
 def poll(self):return self.code
class ControllerFixture:
 def __init__(self,child):self.child=child;self.complete=True;self.entered=None;self.waiting=False;self.events=[]
 def _retain(self,label,raw):self.events.append((label,raw));return {'label':label,'bytes':len(raw),'sha256':hashlib.sha256(raw).hexdigest()}
class StreamFixture:
 def __init__(self,chunks):self.chunks=list(chunks)
 def recv(self,n):
  v=self.chunks.pop(0)
  if isinstance(v,BaseException):raise v
  assert len(v)<=n;return v

def main():
 import tempfile
 parser=argparse.ArgumentParser();parser.add_argument('--output',type=Path,default=Path(__file__).with_suffix('.json'));args=parser.parse_args();run=Path(tempfile.mkdtemp(prefix='lsh-callback-runtime-',dir='D:/CodexTemp'));suite=SuiteFixture(run);checks=[]
 def passed(label):checks.append({'label':label,'passed':True})
 def refuse(label,action):
  try:action()
  except (RuntimeError,WireError,AssertionError):passed(label)
  else:raise AssertionError('Accepted '+label)
 step={'pid':12345,'nonce':'a'*32,'output':str(run/'steps/first'),'profile':str(run/'profiles/first')};pin=suite.evidence_by_path[str(suite.identity_path.resolve()).casefold()]
 values={'CAMPAIGN_CALLBACK_CASE':'callback_sees_new_memory','CAMPAIGN_TERMINAL_OUTPUT':step['output'],'CAMPAIGN_TERMINAL_NONCE':step['nonce'],'CAMPAIGN_TERMINAL_MODE':'first','CAMPAIGN_TERMINAL_PROFILE':step['profile'],'CAMPAIGN_TERMINAL_TOKEN':'','CAMPAIGN_TERMINAL_EXPECT_RECOVERY':'0','CAMPAIGN_TERMINAL_IDENTITY_FILE':str(suite.identity_path),'CAMPAIGN_TERMINAL_IDENTITY_SHA256':pin['sha256'],'CAMPAIGN_TERMINAL_PRIOR_HANDOFF_FILE':'','CAMPAIGN_TERMINAL_PRIOR_HANDOFF_SHA256':'','CAMPAIGN_TERMINAL_PRIOR_TOKEN':''}
 validate_callback_environment(suite,step,values);passed('exact synthetic phase environment')
 for key,badvalue in [('CAMPAIGN_CALLBACK_CASE','cloud_applying_callback_no_upload_claim'),('CAMPAIGN_TERMINAL_MODE','restart_first'),('CAMPAIGN_TERMINAL_PROFILE',step['profile']+'other'),('CAMPAIGN_TERMINAL_NONCE','b'*32),('CAMPAIGN_TERMINAL_IDENTITY_SHA256','0'*64)]:
  bad=values.copy();bad[key]=badvalue;refuse('changed '+key,lambda bad=bad:validate_callback_environment(suite,step,bad))
 for key in ['APPDATA','appdata','STEAM_DISABLED','CAMPAIGN_QA','camPAIGN_TERMINAL_MODE','EXTRA']:
  bad=values.copy();bad[key]='1';refuse('extra/alias '+key,lambda bad=bad:validate_callback_environment(suite,step,bad))
 doc=run/'manifest.json';doc.write_text('{"synthetic":true}',encoding='utf-8');h=hashlib.sha256(doc.read_bytes()).hexdigest();refuse('unsealed manifest rejected',lambda:sealed_document(suite,doc,h));suite.spec['pins']=[{'path':str(doc),'sha256':h}];assert sealed_document(suite,doc,h)=={'synthetic':True};passed('exact source pin document read')
 child=ChildFixture();controller=ControllerFixture(child);batch=type('BatchFixture',(),{'child':child})();error=WireError('Original owned Popen still live')
 assert completed_terminal_transition(error,batch,controller,step);passed('synthetic terminal race classification only')
 for bad in [WireError('different guard'),RuntimeError('Original owned Popen still live')]:assert not completed_terminal_transition(bad,batch,controller,step);passed('unrelated exception not terminal transition '+type(bad).__name__)
 bad=WireError('Original owned Popen still live');bad.add_note('synthetic custody failure');assert not completed_terminal_transition(bad,batch,controller,step);passed('custody-error note refuses terminal exception')
 for code in [None,1,-1]:child.code=code;assert not completed_terminal_transition(error,batch,controller,step);passed('nonzero/nonterminal race refused '+str(code))
 child.code=0;controller.waiting=True;assert not completed_terminal_transition(error,batch,controller,step);controller.waiting=False;passed('outstanding snapshot cannot become terminal success')
 receiver=type('ReceiverFixture',(),{'frames':type('FramesFixture',(),{'buffer':bytearray(b'prefix')})(),'stopped':False})();stream=StreamFixture([socket.timeout(),b'tail1',b'tail2',b'']);rows=drain_terminal_tail(suite,batch,controller,receiver,stream,time.monotonic()+1)
 assert controller.events==[('terminal_tail_prefix',b'prefix'),('terminal_tail_bytes',b'tail1'),('terminal_tail_bytes',b'tail2'),('terminal_transport_eof',b'CALLBACK_TERMINAL_TRANSPORT_EOF\n')] and receiver.stopped and len(rows)==2;passed('exact partial-prefix/tail/EOF custody in synthetic memory')
 controller.complete=False;refuse('tail refuses incomplete callback',lambda:drain_terminal_tail(suite,batch,controller,receiver,StreamFixture([b'']),time.monotonic()+1));controller.complete=True
 refuse('tail timeout does not assert EOF',lambda:drain_terminal_tail(suite,batch,controller,receiver,StreamFixture([b'']),time.monotonic()-1))
 assert CallbackSerialBatch.phase is NaturalSerialBatch.phase and CallbackSerialBatch.phase_with_exports is NaturalSerialBatch.phase_with_exports;passed('cold and ordinary restart methods inherited unchanged')
 source=ROOT/'tools/campaign_callback_runtime_v1.py';result={'schema':'callback_runtime_synthetic_host_checks_v1','checks':checks,'count':len(checks),'all_passed':True,'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'script_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'classification':'synthetic environment/terminal race and memory stream fixtures only, not actual constructor or complete phase','work':str(run),'socket_connected':False,'Popen_started':False,'native_started':False,'actual_phase_qualified':False,'approved_stages':[]}
 with args.output.open('x',encoding='utf-8',newline='\n') as f:json.dump(result,f,ensure_ascii=False,indent=2);f.write('\n')
 print(json.dumps({'synthetic_checks':len(checks),'all_passed':True,'native_started':False}))
if __name__=='__main__':main()

"""Pure stream fixtures; receiver constructor bypass is NOT ownership proof."""
from pathlib import Path
import argparse,hashlib,json,socket,struct,sys
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT/'tools'));sys.dont_write_bytecode=True
from campaign_callback_raw_receiver_v1 import FrameBuffer,CallbackRawReceiver
from godot_debug_wire import encode,decode,WireError,MAX_PACKET

class StreamFixture:
 def __init__(self,chunks):self.chunks=list(chunks);self.calls=[]
 def recv(self,n):
  self.calls.append(n);v=self.chunks.pop(0)
  if isinstance(v,BaseException):raise v
  if len(v)>n:self.chunks.insert(0,v[n:]);v=v[:n]
  return v
class ControllerFixture:
 def __init__(self,fail_decode=False,fail_retain=False):self.peer=type('PeerFixture',(),{'buffer':bytearray()})();self.events=[];self.fail_decode=fail_decode;self.fail_retain=fail_retain
 def live(self):pass
 def _retain(self,label,raw):
  if self.fail_retain:raise OSError('synthetic retention failure')
  self.events.append((label,raw));return {'direction':label,'sha256':hashlib.sha256(raw).hexdigest(),'bytes':len(raw)}
 def handle(self,raw):
  assert self.events[-1]==('receive_frame',struct.pack('<I',len(raw))+raw)
  self.events.append(('handle',raw))
  if self.fail_decode:raise WireError('synthetic semantic refusal')
  return decode(raw)

def fixture(chunks,**kw):
 # Explicit synthetic loop harness only. Actual constructor requires real socket/controller.
 c=ControllerFixture(**kw);s=StreamFixture(chunks);x=object.__new__(CallbackRawReceiver);x.controller=c;x.connection=s;x.frames=FrameBuffer();x.stopped=False;x.last_frame=None;return x,c,s

def main():
 parser=argparse.ArgumentParser();parser.add_argument('--output',type=Path,default=Path(__file__).with_suffix('.json'));args=parser.parse_args();checks=[]
 def passed(label):checks.append({'label':label,'passed':True})
 raw=encode(['set_pid',77,[12345]]);frame=struct.pack('<I',len(raw))+raw
 for split in range(1,len(frame)):
  x,c,s=fixture([frame[:split],socket.timeout(),frame[split:]])
  try:x.receive_one()
  except socket.timeout:assert bytes(x.frames.buffer)==frame[:split] and not x.stopped and not c.events
  else:raise AssertionError('timeout ignored')
  x.receive_one();assert c.events==[('receive_frame',frame),('handle',raw)] and not x.frames.buffer;passed('timeout keeps same fragments split '+str(split))
 for partial in [b'',frame[:1],frame[:3],frame[:4],frame[:7]]:
  x,c,s=fixture([partial,b''] if partial else [b''])
  try:x.receive_one()
  except EOFError:
   assert x.stopped and bytes(x.frames.buffer)==partial
   assert c.events==([('receive_eof',partial)] if partial else [])+[('transport_status',b'CALLBACK_TRANSPORT_RECEIVE_EOF\n')]
  else:raise AssertionError('EOF accepted')
  try:x.receive_one()
  except WireError:pass
  else:raise AssertionError('closed stream restarted')
  passed('partial EOF retained '+str(len(partial)))
 for size in [0,1,3,MAX_PACKET+1,0xffffffff]:
  header=struct.pack('<I',size);x,c,s=fixture([header])
  try:x.receive_one()
  except WireError:assert x.stopped and c.events[0]==('receive_bad_header',header) and s.calls==[4]
  else:raise AssertionError('bad length accepted')
  passed('bad header retained before allocation '+str(size))
 x,c,s=fixture([frame],fail_decode=True)
 try:x.receive_one()
 except WireError:assert x.stopped and c.events==[('receive_frame',frame),('handle',raw)]
 else:raise AssertionError('refused body accepted')
 passed('semantic refusal has original full frame custody')
 x,c,s=fixture([frame],fail_retain=True)
 try:x.receive_one()
 except OSError:assert x.stopped and bytes(x.frames.buffer)==frame and not c.events
 else:raise AssertionError('custody failure continued')
 passed('retention failure preserves buffer and forbids decode')
 x,c,s=fixture([frame[:6],OSError('synthetic IO')])
 try:x.receive_one()
 except OSError:assert x.stopped and c.events[0]==('receive_io_error',frame[:6])
 else:raise AssertionError('IO error accepted')
 passed('IO error retains partial bytes')
 x,c,s=fixture([frame,frame]);x.receive_one();x.receive_one();assert c.events==[('receive_frame',frame),('handle',raw)]*2;passed('sequential frames do not merge')
 x,c,s=fixture([frame]);c.peer.buffer.extend(b'x')
 try:x.receive_one()
 except WireError:assert not s.calls
 else:raise AssertionError('competing receiver accepted')
 passed('competing decoder buffer refused before receive')
 try:CallbackRawReceiver(object())
 except WireError:passed('fake controller rejected by real constructor')
 else:raise AssertionError('fake owner accepted')
 source=ROOT/'tools/campaign_callback_raw_receiver_v1.py';result={'schema':'callback_raw_receiver_synthetic_host_checks_v1','checks':checks,'count':len(checks),'all_passed':True,'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'script_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'classification':'synthetic constructor-bypassing loop and in-memory stream/custody fixtures only','socket_connected':False,'Popen_started':False,'native_started':False,'actual_owner_proven':False,'controller_pipeline_qualified':False,'approved_stages':[]}
 with args.output.open('x',encoding='utf-8',newline='\n') as stream:json.dump(result,stream,ensure_ascii=False,indent=2);stream.write('\n')
 print(json.dumps({'synthetic_checks':len(checks),'all_passed':True,'native_started':False}))
if __name__=='__main__':main()

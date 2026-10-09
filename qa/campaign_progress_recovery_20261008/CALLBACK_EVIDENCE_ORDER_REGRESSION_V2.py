"""Synthetic tail ordering counterexample/correction only; no actual native."""
from pathlib import Path
import argparse,hashlib,json,struct,sys,tempfile
ROOT=Path(__file__).resolve().parents[2];QA=Path(__file__).parent;sys.path.insert(0,str(ROOT/'tools'));sys.path.insert(0,str(QA));sys.dont_write_bytecode=True
from CALLBACK_EVIDENCE_SYNTHETIC_HOST_CHECKS_V1 import fixture
from campaign_callback_packet_evidence_v1 import replay_callback_packets as old_replay
from campaign_callback_packet_evidence_v2 import replay_callback_packets
from godot_debug_wire import encode,WireError

def add(step,kind,raw):
 rows=step['callback_events'];directory=Path(step['output'])/'callback_packets';path=directory/('%04d_%s.bin'%(len(rows)+1,kind));path.write_bytes(raw);row={'order':len(rows)+1,'direction':kind,'path':str(path),'bytes':len(raw),'sha256':hashlib.sha256(raw).hexdigest()};rows.append(row);return row

def start(root):
 f=fixture(root);step=f[1];row=step['callback_events'].pop();path=Path(row['path']);assert path.parent==(Path(step['output'])/'callback_packets');path.unlink();step['terminal_transition_guard_observed']=True;return f

def main():
 parser=argparse.ArgumentParser();parser.add_argument('--output',type=Path,default=Path(__file__).with_suffix('.json'));args=parser.parse_args();root=Path(tempfile.mkdtemp(prefix='lsh-callback-order-',dir='D:/CodexTemp'));checks=[]
 def passed(label):checks.append({'label':label,'passed':True})
 def refuse(label,f):
  try:replay_callback_packets(*f)
  except (WireError,ValueError,RuntimeError,AssertionError):passed(label)
  else:raise AssertionError('Accepted '+label)
 body=encode(['debug_exit',77,[]]);frame=struct.pack('<I',len(body))+body
 f=start(root);add(f[1],'terminal_tail_prefix',frame);add(f[1],'receive_gate_refused',b'BAD_PREFIX_NOT_A_FRAME');add(f[1],'transport_status',b'CALLBACK_TRANSPORT_RECEIVE_GATE_REFUSED\n');add(f[1],'terminal_transport_eof',b'CALLBACK_TERMINAL_TRANSPORT_EOF\n');v=old_replay(*f);assert v['transport_eof']=='terminal' and not v['native_ownership_proven'];passed('originalV1 counterexample accepted synthetic lost-prefix trace');refuse('V2 rejects prefix-before-refusal counterexample',f)
 f=start(root);prefix=frame[:3];add(f[1],'receive_gate_refused',prefix);add(f[1],'transport_status',b'CALLBACK_TRANSPORT_RECEIVE_GATE_REFUSED\n');add(f[1],'terminal_tail_prefix',prefix);row=add(f[1],'terminal_tail_bytes',frame[3:]);f[1]['terminal_tail']=[row];add(f[1],'terminal_transport_eof',b'CALLBACK_TERMINAL_TRANSPORT_EOF\n');v=replay_callback_packets(*f);assert v['transport_eof']=='terminal';passed('correct partial header/prefix/tail order fully replayed')
 f=start(root);add(f[1],'receive_gate_refused',frame[:3]);add(f[1],'transport_status',b'CALLBACK_TRANSPORT_RECEIVE_GATE_REFUSED\n');add(f[1],'terminal_tail_prefix',b'wrong');add(f[1],'terminal_transport_eof',b'CALLBACK_TERMINAL_TRANSPORT_EOF\n');refuse('different prefix bytes refused',f)
 f=start(root);add(f[1],'receive_gate_refused',frame[:3]);add(f[1],'transport_status',b'CALLBACK_TRANSPORT_RECEIVE_GATE_REFUSED\n');row=add(f[1],'terminal_tail_bytes',frame);f[1]['terminal_tail']=[row];add(f[1],'terminal_transport_eof',b'CALLBACK_TERMINAL_TRANSPORT_EOF\n');refuse('omitted explicit original prefix refused',f)
 v=replay_callback_packets(*fixture(root));assert not v['whole_suite_qualified'];passed('prior ordinary terminal trace unchanged')
 result={'schema':'callback_evidence_order_regression_v2','script_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'source_sha256':{n:hashlib.sha256((ROOT/'tools'/n).read_bytes()).hexdigest() for n in ['campaign_callback_packet_evidence_v1.py','campaign_callback_packet_evidence_v2.py','campaign_natural_callback_evidence_v2.py']},'checks':checks,'count':len(checks),'all_passed':True,'work':str(root),'synthetic_only':True,'socket_connected':False,'Popen_started':False,'native_started':False,'complete_pipeline_qualified':False,'approved_stages':[]}
 with args.output.open('x',encoding='utf-8',newline='\n') as f:json.dump(result,f,ensure_ascii=False,indent=2);f.write('\n')
 print(json.dumps({'synthetic_checks':len(checks),'all_passed':True,'native_started':False}))
if __name__=='__main__':main()

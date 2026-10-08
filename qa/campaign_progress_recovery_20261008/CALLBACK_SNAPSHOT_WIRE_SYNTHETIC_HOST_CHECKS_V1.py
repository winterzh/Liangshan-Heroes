"""Object-free snapshot command byte checks; no socket, Popen or Godot."""
from pathlib import Path
import argparse,hashlib,json,struct,sys
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT/'tools'));sys.dont_write_bytecode=True
from campaign_callback_snapshot_wire_v1 import CallbackSnapshotConnection,CASES,COMMAND
from godot_debug_wire import decode,WireError,DebugConnection

class SocketFixture:
    def __init__(self,host='127.0.0.1'):self.host=host;self.packets=[]
    def getpeername(self):return self.host,12345
    def sendall(self,value):self.packets.append(value)

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,default=Path(__file__).with_suffix('.json'));args=p.parse_args();checks=[]
    def passed(label):checks.append({'label':label,'passed':True})
    sock=SocketFixture();peer=CallbackSnapshotConnection(sock)
    for case in CASES:
        peer.request_snapshot(7,12345,'a'*32,case,1);raw=sock.packets[-1];size=struct.unpack('<I',raw[:4])[0]
        assert size==len(raw)-4 and decode(raw[4:])==[COMMAND,7,[12345,'a'*32,case,1]];passed('exact scalar-only snapshot packet '+case)
    def refuse(label,params):
        before=len(sock.packets)
        try:peer.request_snapshot(*params)
        except WireError:assert len(sock.packets)==before;passed(label)
        else:raise AssertionError('Unsafe snapshot parameters accepted: '+label)
    ordinary=[7,12345,'a'*32,CASES[0],1]
    for index,value,label in [(0,True,'bool thread'),(0,1<<70,'overflow thread'),(1,True,'bool PID'),(1,0,'zero PID'),(1,-1,'negative PID'),(2,'A'*32,'noncanonical uppercase nonce'),(2,'a'*31,'short nonce'),(2,'a'*31+'\x00','nonce control character'),(3,'evaluate','nonfixed case'),(4,True,'bool sequence'),(4,0,'zero sequence'),(4,9,'sequence above cap')]:
        row=ordinary.copy();row[index]=value;refuse(label,row)
    try:CallbackSnapshotConnection(SocketFixture('10.0.0.1'))
    except WireError:passed('nonloopback fixture rejected')
    else:raise AssertionError('Nonloopback accepted')
    for name in ['evaluate','set_variable','reload_scripts',COMMAND]:
        try:peer.command(name,7,[])
        except WireError:passed('inherited generic command cannot send '+name)
        else:raise AssertionError('Generic mutation/custom command accepted')
    assert DebugConnection.ALLOWED=={'get_stack_dump','continue','breakpoint'};passed('existing debugger allowed command set unchanged')
    value={'schema':'callback_snapshot_wire_synthetic_host_checks_v1','script_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'classification':'synthetic recording socket object and command bytes only; no connection or owned process proof','checks':checks,'count':len(checks),'all_passed':True,'socket_connected':False,'Popen_started':False,'Godot_started':False,'current_engine_compatibility_proven':False,'approved_stages':[]}
    with args.output.open('x',encoding='utf-8',newline='\n') as f:json.dump(value,f,ensure_ascii=False,indent=2);f.write('\n')
    print(json.dumps({'synthetic_wire_checks':len(checks),'all_passed':True,'native_started':False}))

if __name__=='__main__':main()

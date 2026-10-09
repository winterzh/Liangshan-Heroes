"""Synthetic arm messages and CPU controller state only, never actual ownership."""
from pathlib import Path
from types import SimpleNamespace
import argparse
import copy
import hashlib
import json
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools'))
sys.dont_write_bytecode = True
from campaign_cloud_arm_packets_v1 import CloudArmPackets, CASE, ARM_COMMAND, ARM_REPLY
from campaign_cloud_arm_controller_v1 import CloudArmController
from campaign_callback_controller_v3 import STACKS
from campaign_callback_packets_v2 import same
from godot_debug_wire import encode, decode, WireError

PID = 12345
NONCE = 'a'*32
THREAD = 77
IDENTITY = {'save_eligible':True,'synthetic_identity':True}
USER = 'D:/CodexTemp/synthetic-user'


def ready():
    return {'campaign_id':100,'cloud_id':200,'identity':IDENTITY,'user_directory':USER}


def ack():
    return {'schema':'campaign_cloud_callback_arm_received_v2','pid':PID,'nonce':NONCE,'case':CASE,'sequence':0,
            **ready(),'SDK_reward_once_qualified':False,'actual_callback_qualified':False,'overall_goal_qualified':False}


def packet(name,data,thread=THREAD):
    return encode([name,thread,data])


def arm_packet(value=None,data=None,thread=THREAD,text=None):
    return packet(ARM_REPLY,data if data is not None else [PID,NONCE,CASE,0,json.dumps(ack() if value is None else value) if text is None else text],thread)


def decoder():
    result = CloudArmPackets(PID,NONCE,CASE,IDENTITY,USER)
    result.consume_ready(packet('lsh_callback19:ready',[PID,NONCE,CASE,json.dumps(ready())]))
    return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output',type=Path,default=Path(__file__).with_suffix('.json'))
    args = parser.parse_args()
    checks = []
    def passed(label):
        checks.append({'label':label,'passed':True})
    def refuse(label,action):
        try:
            action()
        except (WireError,ValueError,RuntimeError,AssertionError):
            passed(label)
        else:
            raise AssertionError('Accepted '+label)
    d = decoder()
    result = d.consume_arm(arm_packet(),THREAD)
    assert result['raw'] == arm_packet() and not result['ownership_proven'] and not result['native_qualified'] and d.sequence == 0
    passed('exact arm bytes retained without native qualification or snapshot advance')
    refuse('duplicate arm reply',lambda:d.consume_arm(arm_packet(),THREAD))
    d = CloudArmPackets(PID,NONCE,CASE,IDENTITY,USER)
    refuse('arm before ready',lambda:d.consume_arm(arm_packet(),THREAD))
    refuse('snapshot before arm',lambda:decoder().consume_snapshot(b'not-a-packet',THREAD,1))
    changes = [('pid',PID+1),('pid',True),('nonce','b'*32),('case','callback_sees_new_memory'),('sequence',True),
               ('sequence',1),('campaign_id',101),('cloud_id',201),('campaign_id',True),('identity',{'save_eligible':True}),
               ('user_directory','other'),('schema','other'),('SDK_reward_once_qualified',True),
               ('actual_callback_qualified',True),('overall_goal_qualified',True)]
    for key,value in changes:
        d = decoder()
        modified = copy.deepcopy(ack())
        modified[key] = value
        refuse('changed arm '+key+' '+repr(value),lambda:d.consume_arm(arm_packet(modified),THREAD))
        assert d.arm is None and d.sequence == 0
    for label,raw in [('wrong thread',arm_packet(thread=THREAD+1)),
                      ('wrong outer nonce',arm_packet(data=[PID,'b'*32,CASE,0,json.dumps(ack())])),
                      ('outer bool sequence',arm_packet(data=[PID,NONCE,CASE,False,json.dumps(ack())])),
                      ('duplicate JSON key',arm_packet(text=json.dumps(ack())[:-1]+',"sequence":0}')),
                      ('nonfinite JSON',arm_packet(text=json.dumps(ack()).replace('"sequence": 0','"sequence": NaN'))),
                      ('isolated surrogate',arm_packet(text=json.dumps(ack()).replace(USER,'\\ud800')))]:
        d = decoder()
        refuse(label,lambda:d.consume_arm(raw,THREAD))
        assert d.arm is None
    refuse('fake owned controller constructor',lambda:CloudArmController(None,object(),{},None,CASE,None,None,None,None,None,None))
    # Deliberately bypass the constructor for CPU transition checks only.
    # This holder is fabricated, with no Popen/socket/file ledger or source proof.
    controller = CloudArmController.__new__(CloudArmController)
    controller.child = SimpleNamespace(pid=PID)
    controller.step = {'nonce':NONCE}
    controller.case = CASE
    controller.packets = CloudArmPackets(PID,NONCE,CASE,IDENTITY,USER)
    controller.armed = False
    controller.entered = None
    controller.waiting = False
    controller.complete = False
    controller.snapshot = None
    controller.frames = None
    controller.ready_thread = None
    controller.arm_request_sent = False
    controller.apply_ready = {'campaign_id':100,'cloud_id':200,'original_cloud':{'dirty':True,'pending_upload':True,'revision':3}}
    retained,sent = [],[]
    controller.live = lambda:None
    def retain(direction,raw):
        row = {'direction':direction,'sha256':hashlib.sha256(raw).hexdigest()}
        retained.append((row,raw))
        return row
    controller._retain = retain
    controller.peer = SimpleNamespace(connection=SimpleNamespace(sendall=lambda raw:sent.append(raw)))
    refuse('arm send before original breakpoint/ready',lambda:controller._send(ARM_COMMAND,THREAD,[PID,NONCE,CASE,0]))
    controller.handle(packet('set_pid',[PID]))
    controller.handle(packet('lsh_callback19:ready',[PID,NONCE,CASE,json.dumps(ready())]))
    assert [decode(raw[4:])[0] for raw in sent] == ['breakpoint',ARM_COMMAND]
    assert [v[0]['direction'] for v in retained] == ['receive','send_attempt','send_complete','receive','send_attempt','send_complete']
    passed('synthetic controller sends breakpoint before arm with both original completion rows')
    controller.handle(arm_packet())
    assert controller.packets.arm is not None
    passed('synthetic requested original-thread acknowledgment accepted')
    refuse('synthetic duplicate arm send',lambda:controller._send(ARM_COMMAND,THREAD,[PID,NONCE,CASE,0]))
    refuse('synthetic duplicate acknowledgment',lambda:controller.handle(arm_packet()))
    refuse('synthetic mutation command refused',lambda:controller._send('evaluate',THREAD,['change-game']))
    controller.handle(packet('debug_enter',[True,'Breakpoint',True,THREAD]))
    stack = STACKS[CASE]
    frames = [len(stack)*3]+[value for frame in stack for value in [frame['source'],frame['line'],frame['function']]]
    controller.handle(packet('stack_dump',frames))
    assert controller.waiting and decode(sent[-1][4:])[0] == 'lsh_callback19:read'
    passed('synthetic matching production stack after arm issues exact read request')
    snapshot = {'schema':'campaign_callback_readonly_snapshot_v1','pid':PID,'nonce':NONCE,'case':CASE,'sequence':1,
                **ready(),'campaign_memory':{'records':{},'unlocked':2,'owner':'1'},
                'cloud_state':{'dirty':True,'pending_upload':True,'revision':3,'applying':True,'owner':'1','shared_profile_pending':True},
                'campaign_persistence_busy':False,'time_scale':1,'physics_ticks':60,
                'original19_qualified':False,'SDK_reward_once_qualified':False,'overall_goal_qualified':False}
    changes = [('campaign_memory',{'records':{},'unlocked':1,'owner':'1'}),('campaign_persistence_busy',True)]
    for key,bad in [('dirty',False),('pending_upload',False),('revision',4),('applying',False),('owner','2'),('shared_profile_pending',False)]:
        cloud = copy.deepcopy(snapshot['cloud_state'])
        cloud[key] = bad
        changes.append(('cloud_state',cloud))
    for key,bad in changes:
        holder = copy.copy(controller)
        holder.packets = copy.deepcopy(controller.packets)
        value = copy.deepcopy(snapshot)
        value[key] = bad
        refuse('synthetic cloud boundary '+key+' '+repr(bad),lambda:holder.handle(packet('lsh_callback19:snapshot',[PID,NONCE,CASE,1,json.dumps(value)])))
        assert not holder.complete
    controller.handle(packet('lsh_callback19:snapshot',[PID,NONCE,CASE,1,json.dumps(snapshot)]))
    assert controller.complete and controller.entered is None and not controller.waiting
    assert [decode(raw[4:])[0] for raw in sent[-2:]] == ['breakpoint','continue']
    passed('synthetic valid new memory and unchanged upload boundary disables and resumes')
    assert not controller.observation_result()['breakpoint_installation_verified']
    passed('synthetic observation does not grant breakpoint installation proof')
    result = {'schema':'cloud_arm_synthetic_host_checks_v2','script_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
              'source_sha256':{name:hashlib.sha256((ROOT/'tools'/name).read_bytes()).hexdigest() for name in
                               ['campaign_cloud_arm_packets_v1.py','campaign_cloud_arm_controller_v1.py','campaign_cloud_arm_raw_receiver_v1.py',
                                'campaign_cloud_applying_exports_v1.py','campaign_cloud_applying_runtime_v1.py']},
              'checks':checks,'count':len(checks),'all_passed':True,
              'classification':'synthetic Variant packets and constructor-bypassed CPU state only; no actual ownership or file ledger',
              'actual_controller_constructed':False,'socket_opened':False,'Popen_started':False,'native_started':False,
              'complete_phase_called':False,'breakpoint_installation_verified':False,'approved_stages':[],'overall_goal_qualified':False}
    with args.output.open('x',encoding='utf-8',newline='\n') as out:
        json.dump(result,out,ensure_ascii=False,indent=2)
        out.write('\n')
    print(json.dumps({'synthetic_checks':len(checks),'all_passed':True,'native_started':False}))


if __name__ == '__main__':
    main()

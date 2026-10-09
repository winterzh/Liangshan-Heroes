"""Fabricated packet/CFG files only; no actual process, ConfigFile or pipeline."""
from pathlib import Path
from types import SimpleNamespace
import copy
import hashlib
import json
import struct
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]
QA = Path(__file__).parent
sys.path.insert(0,str(ROOT/'tools'))
sys.dont_write_bytecode = True
from campaign_cloud_arm_packet_evidence_v2 import replay_cloud_arm_packets, CASE
from campaign_cloud_arm_packet_evidence_v1 import replay_cloud_arm_packets as old_replay
from campaign_cloud_cfg_physical_v2 import strict_journal, journal_names, validate_cloud_post_cfg, capture_cloud_pre_apply
from campaign_cloud_cfg_physical_v1 import strict_journal as old_strict_journal, journal_names as old_journal_names
from campaign_cloud_apply_first_evidence_v4 import CloudApplyFirstEvidence
from campaign_cloud_cfg_semantics_v1 import ready_projection as old_projection
from campaign_cloud_cfg_semantics_v2 import ready_projection
from campaign_callback_controller_v3 import STACKS
from campaign_file_fault_records_v1 import ZERO
from godot_debug_wire import encode, WireError


def sha(raw):return hashlib.sha256(raw).hexdigest()


class SyntheticFiles:
    def __init__(self,root):
        self.run = root
        self.pins = {}
        self.runtime_fields = {'content_version':'source-v1:'+'a'*64,'engine_binary_sha256':'b'*64}
    def freeze_bytes(self,path,expected=None):
        raw = Path(path).read_bytes()
        assert expected is None or sha(raw) == expected
        key = str(Path(path).resolve())
        assert key not in self.pins or self.pins[key] == sha(raw)
        self.pins[key] = sha(raw)
        return raw


def fixture(root,arm=True,duplicate=False,completion=True,tail=b''):
    run = Path(tempfile.mkdtemp(prefix='packets-',dir=root))
    output = run/'steps/cloud_applying'
    directory = output/'callback_packets'
    directory.mkdir(parents=True)
    suite = SyntheticFiles(run)
    identity = {'save_eligible':True,'synthetic_identity':True}
    user = (run/'profiles/private/appdata/user').as_posix()
    pid,nonce,thread = 12345,'a'*32,77
    ready = {'campaign_id':100,'cloud_id':200,'identity':identity,'user_directory':str(user)}
    ack = {'schema':'campaign_cloud_callback_arm_received_v2','pid':pid,'nonce':nonce,'case':CASE,'sequence':0,
           **ready,'SDK_reward_once_qualified':False,'actual_callback_qualified':False,'overall_goal_qualified':False}
    snapshot = {'schema':'campaign_callback_readonly_snapshot_v1','pid':pid,'nonce':nonce,'case':CASE,'sequence':1,
                **ready,'campaign_memory':{'records':{},'unlocked':2,'owner':'1'},
                'cloud_state':{'dirty':True,'pending_upload':True,'revision':3,'applying':True,'owner':'1','shared_profile_pending':True},
                'campaign_persistence_busy':False,'time_scale':1,'physics_ticks':60,
                'original19_qualified':False,'SDK_reward_once_qualified':False,'overall_goal_qualified':False}
    rows = []
    def add(direction,raw):
        index = len(rows)+1
        path = directory/('%04d_%s.bin'%(index,direction))
        path.write_bytes(raw)
        row = {'order':index,'direction':direction,'path':str(path),'bytes':len(raw),'sha256':sha(raw)}
        rows.append(row)
        return row
    def frame(name,data):
        raw = encode([name,thread,data])
        return struct.pack('<I',len(raw))+raw
    def receive(name,data):
        raw = frame(name,data)
        add('receive_frame',raw)
        add('receive',raw)
        return raw[4:]
    def send(name,data):
        row = add('send_attempt',frame(name,data))
        row['completion'] = add('send_complete',(b'CALLBACK_SEND_COMPLETE\n' if completion else b'BAD_SEND_COMPLETE\n')+row['sha256'].encode())
    receive('set_pid',[pid])
    send('breakpoint',['res://scripts/steam_cloud.gd',230,True])
    receive('lsh_callback19:ready',[pid,nonce,CASE,json.dumps(ready)])
    if arm:
        send('lsh_callback19:arm',[pid,nonce,CASE,0])
        arm_raw = receive('lsh_callback19:armed',[pid,nonce,CASE,0,json.dumps(ack)])
        if duplicate:receive('lsh_callback19:armed',[pid,nonce,CASE,0,json.dumps(ack)])
    else:
        arm_raw = encode(['lsh_callback19:armed',thread,[pid,nonce,CASE,0,json.dumps(ack)]])
    receive('debug_enter',[True,'Breakpoint',True,thread])
    send('get_stack_dump',[])
    stack = STACKS[CASE]
    receive('stack_dump',[len(stack)*3]+[v for f in stack for v in [f['source'],f['line'],f['function']]])
    send('lsh_callback19:read',[pid,nonce,CASE,1])
    snapshot_raw = receive('lsh_callback19:snapshot',[pid,nonce,CASE,1,json.dumps(snapshot)])
    send('breakpoint',['res://scripts/steam_cloud.gd',230,False])
    send('continue',[])
    tails = [add('terminal_tail_bytes',tail)] if tail else []
    add('terminal_transport_eof',b'CALLBACK_TERMINAL_TRANSPORT_EOF\n')
    observation = {'case':CASE,'pid':pid,'nonce':nonce,'actual_frames':stack,'events':rows,'snapshot_sha256':sha(snapshot_raw),
                   'observation':snapshot,'actual_case_qualified':False,'original19_qualified':False,'SDK_reward_once_qualified':False,
                   'overall_goal_qualified':False,'arm_ack':ack,'arm_ack_sha256':sha(arm_raw),'breakpoint_installation_verified':False}
    step = {'output':str(output),'pid':pid,'nonce':nonce,'callback_events':rows,'callback_observation':observation,'terminal_tail':tails}
    apply = {'campaign_id':100,'cloud_id':200,'original_cloud':{'dirty':True,'pending_upload':True,'revision':3}}
    return suite,step,identity,user,apply


def envelope(document,generation,previous):
    payload = json.dumps(document,separators=(',',':'))
    env = {'magic':'LH_CAMPAIGN_CFG_TRANSACTION','version':'1','app':'5088120','owner':'1','revision':str(generation),
           'previous_sha256':previous,'payload_bytes':str(len(payload.encode())),'payload_sha256':sha(payload.encode()),'payload':payload}
    return json.dumps(env).encode()


def cfg_fixture(root,wrong_original=False,wrong_owner=False):
    run = Path(tempfile.mkdtemp(prefix='cfg-',dir=root))
    suite = SyntheticFiles(run)
    output = run/'steps/cloud_applying'
    output.mkdir(parents=True)
    user = run/'profiles/private/appdata/user'
    directory = user/'campaign_cfg_transactions/v1/5088120/1'
    directory.mkdir(parents=True)
    (user/'campaign_cfg_candidates/v1').mkdir(parents=True)
    # Deliberately fabricated binary/text CFG bytes, not actual ConfigFile parse.
    candidate = b'[progress]\nschema=2\nunlocked=2\nowner="1"\nrecords={}\n'
    (user/'campaign.cfg').write_bytes(candidate)
    base = {'schema':'campaign_cfg_transaction_v1','transaction':'a'*32,'original_sha256':'c'*64 if wrong_original else ZERO,
            'candidate_sha256':sha(candidate),'semantics_sha256':'d'*64,'original_owner':'','target_owner':'2' if wrong_owner else '1',
            'content_version':suite.runtime_fields['content_version'],'engine_sha256':suite.runtime_fields['engine_binary_sha256'],
            'operation':'cloud','run_token':'','intent_sha256':''}
    first = envelope({**base,'generation':1,'state':'prepared'},1,ZERO)
    second = envelope({**base,'generation':2,'state':'applied'},2,sha(first))
    (directory/'record_0000000001.json').write_bytes(first)
    (directory/'record_0000000002.json').write_bytes(second)
    step = {'output':str(output),'cloud_cfg_before':{'schema':'cloud_cfg_original_before_apply_v1','cfg':None,'journals':[],
                                                   'pruned_ancestor_bytes_available':True,'native_semantics_independently_verified':False}}
    return suite,step,user,sha(candidate)


def main():
    root = Path(tempfile.mkdtemp(prefix='lsh-cloud-first-evidence-',dir='D:/CodexTemp'))
    checks = []
    def passed(label):checks.append({'label':label,'passed':True})
    def refuse(label,action):
        try:action()
        except (WireError,RuntimeError,ValueError,AssertionError):passed(label)
        else:raise AssertionError('Accepted '+label)
    value = replay_cloud_arm_packets(*fixture(root))
    assert value['native_ownership_proven'] is False and value['breakpoint_installation_verified'] is False
    passed('complete fabricated original arm/callback/EOF files replay without ownership qualification')
    refuse('missing original arm request/reply',lambda:replay_cloud_arm_packets(*fixture(root,arm=False)))
    refuse('duplicate original arm reply',lambda:replay_cloud_arm_packets(*fixture(root,duplicate=True)))
    refuse('failed original send completion marker',lambda:replay_cloud_arm_packets(*fixture(root,completion=False)))
    for label,mutation in [('arm SHA metadata',lambda s:s['callback_observation'].update(arm_ack_sha256='0'*64)),
                           ('arm node metadata',lambda s:s['callback_observation']['arm_ack'].update(campaign_id=101)),
                           ('false breakpoint qualification',lambda s:s['callback_observation'].update(breakpoint_installation_verified=True))]:
        f = fixture(root)
        mutation(f[1])
        refuse(label,lambda:replay_cloud_arm_packets(*f))
    raw = encode(['debug_exit',77,[]])
    frame = struct.pack('<I',len(raw))+raw
    assert not replay_cloud_arm_packets(*fixture(root,tail=frame))['whole_suite_qualified']
    passed('valid original terminal noise frame fully decoded')
    refuse('truncated original terminal header',lambda:replay_cloud_arm_packets(*fixture(root,tail=b'\x01')))
    raw = encode(['lsh_callback19:armed',77,[]])
    refuse('late terminal arm control',lambda:replay_cloud_arm_packets(*fixture(root,tail=struct.pack('<I',len(raw))+raw)))
    f = fixture(root)
    (Path(f[1]['output'])/'callback_packets/unlisted.bin').write_bytes(b'extra')
    refuse('unlisted original packet artifact',lambda:replay_cloud_arm_packets(*f))
    f = cfg_fixture(root)
    value = validate_cloud_post_cfg(*f)
    assert value['native_semantics_independently_verified'] is False and value['restart_qualified'] is False
    assert f[0].freeze_bytes(value['cfg']['copy_path']) == (f[2]/'campaign.cfg').read_bytes()
    passed('fabricated physical candidate and full fourteen-field pair copied byte-exact without semantics/restart claim')
    refuse('wrong physical original CFG hash',lambda:validate_cloud_post_cfg(*cfg_fixture(root,wrong_original=True)))
    refuse('wrong target owner in original journal',lambda:validate_cloud_post_cfg(*cfg_fixture(root,wrong_owner=True)))
    f = cfg_fixture(root)
    path = f[2]/'campaign_cfg_transactions/v1/5088120/1/record_0000000001.json'
    raw = path.read_bytes()
    duplicate = raw[:-1]+b',"owner":"1"}'
    refuse('duplicate native envelope key',lambda:strict_journal(duplicate,1,ZERO))
    fake = SimpleNamespace(batch=SimpleNamespace(child=object()))
    refuse('fake pre-arm capture holder',lambda:capture_cloud_pre_apply(fake,{},SimpleNamespace(child=fake.batch.child)))
    contract = json.loads((QA/'cloud_applying_driver_candidate_v2/COMPLETE_LABEL_CONTRACT_V2.json').read_bytes())
    manifest = json.loads((QA/'cloud_applying_driver_candidate_v2/SOURCE.json').read_bytes())
    step = {'label':'cloud_applying','mode':'first','case':CASE}
    fake = SimpleNamespace(runtime_fields=dict.fromkeys(contract['identity_fields_order']),batch=SimpleNamespace(child=object(),steps=[step]))
    consumer = CloudApplyFirstEvidence(fake,contract,manifest)
    refuse('metadata-only terminal holder cannot enter first full-report consumer',lambda:consumer.validate_first(step))
    f = cfg_fixture(root)
    raw = (f[2]/'campaign_cfg_transactions/v1/5088120/1/record_0000000001.json').read_bytes()
    document = json.loads(json.loads(raw)['payload'])
    overflow = 2147483649
    modified = {**document,'generation':overflow}
    oversized = envelope(modified,overflow,ZERO)
    assert old_strict_journal(oversized,overflow,ZERO)['generation'] == overflow
    passed('V1 native generation overflow counterexample reproduced')
    refuse('V2 rejects original native generation overflow',lambda:strict_journal(oversized,overflow,ZERO))
    modified = {**document,'generation':2147483647}
    assert strict_journal(envelope(modified,2147483647,ZERO),2147483647,ZERO)['generation'] == 2147483647
    passed('V2 exact native upper bound single prepared document accepted')
    for generation in [0,-1,True,1.0]:
        refuse('V2 refuses invalid generation '+repr(generation),lambda:strict_journal(raw,generation,ZERO))
    for first,label in [(2147483645,'largest complete native pair'),(2147483647,'overflow applied generation'),(2147483649,'both generations overflow')]:
        directory = root/label.replace(' ','_')
        directory.mkdir()
        for generation in [first,first+1]:(directory/('record_%010d.json'%generation)).write_bytes(b'filename-only synthetic fixture')
        assert len(old_journal_names(directory)) == 2
        if first == 2147483645:
            assert len(journal_names(directory)) == 2
            passed('V2 largest complete native prepared/applied filename pair accepted')
        else:refuse('V2 refuses '+label,lambda:journal_names(directory))
    f = fixture(root)
    assert '/' in f[3] and str(Path(f[3])) != f[3], 'Windows-native Path separator regression must actually be present'
    refuse('old replay reconstructs different Windows Path text',lambda:old_replay(f[0],f[1],f[2],Path(f[3]),f[4]))
    assert not replay_cloud_arm_packets(*f)['native_ownership_proven']
    passed('new replay preserves forward-slash original native protocol text')
    refuse('new replay rejects Path object instead of original text',lambda:replay_cloud_arm_packets(f[0],f[1],f[2],Path(f[3]),f[4]))
    sections = {'progress':{'schema':{'variant_type':2,'canonical':'synthetic 2'},'unlocked':{'variant_type':2,'canonical':'synthetic 2'},
                            'records':{'variant_type':27,'canonical':'synthetic empty dictionary'},'owner':{'variant_type':4,'canonical':'synthetic owner1'}}}
    original,expected = '{}',json.dumps(sections)
    text = 'D:/CodexTemp/fabricated-native-user'
    identity = {'save_eligible':True,'synthetic_identity':True}
    ready = {'schema':'campaign_cloud_CFG_semantics_ready_v1','pid':12345,'nonce':'a'*32,'case':CASE,'identity':identity,
             'user_directory':text,'original_present':False,'original_cfg_sha256':'','original_sections_json':original,
             'original_semantics_sha256':sha(original.encode()),'expected_sections_json':expected,'expected_semantics_sha256':sha(expected.encode()),
             'full_case_qualified':False,'SDK_reward_once_qualified':False,'overall_goal_qualified':False}
    assert old_projection(ready,12345,'a'*32,identity,text,'')
    passed('old projection accepts supplied original native string')
    refuse('old projection rejects reconstructed equivalent Windows Path',lambda:old_projection(ready,12345,'a'*32,identity,Path(text),''))
    assert ready_projection(ready,12345,'a'*32,identity,text,'')
    passed('new projection accepts original native text without normalization')
    refuse('new projection refuses Path object input',lambda:ready_projection(ready,12345,'a'*32,identity,Path(text),''))
    refuse('new projection refuses changed directory text',lambda:ready_projection(ready,12345,'a'*32,identity,text+'-other',''))
    result = {'schema':'cloud_native_user_text_synthetic_host_checks_v1','script_sha256':sha(Path(__file__).read_bytes()),
              'source_sha256':{name:sha((ROOT/'tools'/name).read_bytes()) for name in
                               ['campaign_cloud_arm_packet_evidence_v2.py','campaign_cloud_cfg_physical_v2.py',
                                'campaign_cloud_applying_runtime_v5.py','campaign_cloud_cfg_semantics_v2.py','campaign_cloud_apply_first_evidence_v4.py']},
              'checks':checks,'count':len(checks),'all_passed':True,'work':str(root),
              'classification':'fabricated private packet/journal/binary files and fake-owner refusal only',
              'actual_Popen_started':False,'socket_opened':False,'native_started':False,'complete_consumer_validate_run':False,
              'actual_cloud_phase_run':False,'native_full_CFG_semantics_verified':False,'restart_qualified':False,'approved_stages':[]}
    with Path(__file__).with_suffix('.json').open('x',encoding='utf-8',newline='\n') as out:
        json.dump(result,out,ensure_ascii=False,indent=2)
        out.write('\n')
    print(json.dumps({'synthetic_file_checks':len(checks),'all_passed':True,'native_started':False}))


if __name__ == '__main__':main()

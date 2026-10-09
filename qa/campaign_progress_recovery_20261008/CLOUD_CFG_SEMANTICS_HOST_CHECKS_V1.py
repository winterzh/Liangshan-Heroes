"""Synthetic native-projection strings only; no Godot ConfigFile or process."""
from pathlib import Path
from types import SimpleNamespace
import copy
import hashlib
import json
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools'))
sys.dont_write_bytecode = True
from campaign_cloud_cfg_semantics_v1 import projection, expected_delta, ready_projection, validate_native_semantics, bind_pre_arm_semantics, CASE
from godot_debug_wire import WireError


def sha(text):return hashlib.sha256(text.encode()).hexdigest()
def row(kind,text):return {'variant_type':kind,'canonical':text}


def fixture():
    # Probe text is deliberately fabricated; never inferred as actual engine output.
    original = {'unknown "section"':{'vector':row(5,'synthetic Vector2 probe'),'float':row(3,'synthetic 2.0 probe')},
                'progress':{'unknown':row(34,'synthetic packed string probe'),'schema':row(2,'synthetic 1 probe')}}
    expected = copy.deepcopy(original)
    expected['progress'].update(schema=row(2,'synthetic 2 probe'),unlocked=row(2,'synthetic 2 probe'),records=row(27,'synthetic {} probe'),owner=row(4,'synthetic owner1 probe'))
    a,b = json.dumps(original),json.dumps(expected)
    identity = {'save_eligible':True,'synthetic_identity':True}
    ready = {'schema':'campaign_cloud_CFG_semantics_ready_v1','pid':12345,'nonce':'a'*32,'case':CASE,'identity':identity,
             'user_directory':'D:/CodexTemp/fabricated-user','original_present':True,'original_cfg_sha256':'b'*64,
             'original_sections_json':a,'original_semantics_sha256':sha(a),'expected_sections_json':b,'expected_semantics_sha256':sha(b),
             'full_case_qualified':False,'SDK_reward_once_qualified':False,'overall_goal_qualified':False}
    final = {'final_sections_json':b,'final_semantics_sha256':sha(b)}
    physical = {'journals':[{'document':{'semantics_sha256':sha(b)}},{'document':{'semantics_sha256':sha(b)}}]}
    return ready,final,12345,'a'*32,identity,'D:/CodexTemp/fabricated-user','b'*64,physical


def main():
    checks = []
    def passed(label):checks.append({'label':label,'passed':True})
    def refuse(label,action):
        try:action()
        except (WireError,RuntimeError,ValueError,AssertionError):passed(label)
        else:raise AssertionError('Accepted '+label)
    args = fixture()
    result = validate_native_semantics(*args)
    assert result['all_original_unknown_keys_preserved'] and not result['native_ownership_proven'] and not result['host_ConfigFile_parsed'] and not result['whole_case_qualified']
    passed('fabricated complete unknown-section projections compare without native/parser qualification')
    for label,change in [('missing unknown section',lambda v:v.pop('unknown "section"')),
                         ('changed unknown vector type',lambda v:v['unknown "section"']['vector'].update(variant_type=3)),
                         ('changed original float probe text',lambda v:v['unknown "section"']['float'].update(canonical='changed')),
                         ('missing unknown progress key',lambda v:v['progress'].pop('unknown')),
                         ('extra invented section',lambda v:v.update(invented={})),
                         ('wrong target owner Variant type',lambda v:v['progress']['owner'].update(variant_type=2))]:
        ready = fixture()[0]
        original = projection(ready['original_sections_json'],ready['original_semantics_sha256'])
        expected = projection(ready['expected_sections_json'],ready['expected_semantics_sha256'])
        change(expected)
        refuse(label,lambda:expected_delta(original,expected))
    for label,kind in [('bool kind',True),('floating kind',2.0),('negative kind',-1),('future kind',39),('RID',23),('Object',24),('Callable',25),('Signal',26)]:
        text = json.dumps({'s':{'k':row(kind,'fabricated')}})
        refuse(label,lambda:projection(text,sha(text)))
    for label,text in [('duplicate section','{"s":{},"s":{}}'),('duplicate canonical field','{"s":{"k":{"variant_type":2,"canonical":"a","canonical":"b"}}}')]:
        refuse(label,lambda:projection(text,sha(text)))
    refuse('wrong original serialized projection SHA',lambda:projection('{}','0'*64))
    args = fixture()
    changed = json.loads(args[1]['final_sections_json'])
    changed['unknown "section"']['vector']['canonical'] = 'different'
    args[1].update(final_sections_json=json.dumps(changed),final_semantics_sha256=sha(json.dumps(changed)))
    refuse('final changes preserved value despite internally matching JSON SHA',lambda:validate_native_semantics(*args))
    args = fixture()
    args[-1]['journals'][1]['document']['semantics_sha256'] = 'c'*64
    refuse('one original production journal semantics SHA differs',lambda:validate_native_semantics(*args))
    args = fixture()
    args[-1]['journals'] = []
    refuse('absent original journals cannot prove semantics',lambda:validate_native_semantics(*args))
    args = fixture()
    args[0]['original_present'] = False
    args[0]['original_cfg_sha256'] = ''
    refuse('declared absent CFG cannot contain original unknown sections',lambda:ready_projection(args[0],args[2],args[3],args[4],args[5],''))
    args = fixture()
    args[0]['nonce'] = 'd'*32
    refuse('different original native nonce',lambda:validate_native_semantics(*args))
    args = fixture()
    args[0]['full_case_qualified'] = True
    refuse('projection record cannot claim complete case',lambda:validate_native_semantics(*args))
    refuse('fake owned pre-arm semantics binder',lambda:bind_pre_arm_semantics(SimpleNamespace(batch=SimpleNamespace(child=object())),{},None,{}))
    result = {'schema':'cloud_CFG_semantics_synthetic_host_checks_v1','script_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
              'source_sha256':{name:hashlib.sha256((ROOT/'tools'/name).read_bytes()).hexdigest() for name in
                               ['campaign_cloud_cfg_semantics_v1.py','campaign_cloud_applying_exports_v2.py',
                                'campaign_cloud_applying_runtime_v4.py','campaign_cloud_apply_first_evidence_v3.py']},
              'checks':checks,'count':len(checks),'all_passed':True,'classification':'fabricated serialized projection strings and fake owner refusal only',
              'actual_Godot_CFG_semantics_executed':False,'actual_Popen_started':False,'socket_opened':False,'native_started':False,
              'complete_first_consumer_executed':False,'ordinary_restart_qualified':False,'approved_stages':[]}
    with Path(__file__).with_suffix('.json').open('x',encoding='utf-8',newline='\n') as out:
        json.dump(result,out,ensure_ascii=False,indent=2)
        out.write('\n')
    print(json.dumps({'synthetic_projection_checks':len(checks),'all_passed':True,'native_started':False}))


if __name__ == '__main__':main()

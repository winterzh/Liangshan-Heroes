"""Pure untrusted JSON counterexamples, never a native or full-consumer test."""
import copy
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools'))
sys.dont_write_bytecode = True
from campaign_cloud_failure_evidence_v1 import failure_structure, native_object_id, ZERO

def main():
    identity = {'fixture_only':True}
    runtime = {'content_version':'source-v1:'+'1'*64,'engine_binary_sha256':'2'*64}
    scope = {'operation':'cloud','run_token':'','intent_sha256':'','target_owner':'1',
             'content_version':runtime['content_version'],'engine_sha256':runtime['engine_binary_sha256']}
    payload = {'owner':'1','schema':1,'updated_at':1,'settings_text':'fixture settings','language_text':'fixture language',
               'campaign':{'schema':2,'unlocked':2,'records':{}},'unknown_input':{'kept':['original',7]}}
    shared = {'profile':copy.deepcopy(payload),'source_profile':copy.deepcopy(payload),'identity':identity,
              'kind':'apply','phase':'apply','original_owner':'','binding_sha':'','marker_owner':'',
              'confirmation':{},'current_owner':'1'}
    value = {'campaign_id':101,'cloud_id':102,'writer_id':-(1<<63)+3,'proposal_id':-(1<<63)+4,
             'original_memory':{'records':{},'unlocked':1,'owner':''},
             'original_cloud':{'dirty':False,'pending_upload':False,'revision':0},
             'original_shared_pending':shared,'original_cfg_sha256':'','blocker_sha256':'3'*64,
             'apply_returned':False,'writer_error':'CFG_STAGE_PARENT',
             'retry_error':{'ok':False,'code':'CLOUD_RETRY_SCOPE_CHANGED','config_pending':True},
             'writer_scope':scope,'writer_active':{'request':copy.deepcopy(scope),'original_sha256':ZERO,
               'original_owner':'','transaction':'4'*32,'stage':'staging','semantics_sha256':'5'*64},
             'writer_pending_record':{},'proposal_semantics':{'ok':True,'sections':{'progress':{
               k:{'variant_type':t,'canonical':'opaque fixture native text'}
               for k,t in {'schema':2,'unlocked':2,'records':27,'owner':4}.items()}}},
             'final_memory':{'records':{},'unlocked':1,'owner':''},
             'final_cloud':{'dirty':False,'pending_upload':False,'revision':0},
             'final_shared_pending':copy.deepcopy(shared),'final_cfg_sha256':'',
             'same_pending_writer_retained':True,'real_fault_repaired':True,'successful_authorized_retry':False}
    result = failure_structure(value,identity,runtime)
    assert result['structural_contract_verified'] and not result['native_execution_proven'] and not result['full_case_qualified']
    assert native_object_id(-(1<<63)) and native_object_id((1<<63)-1)
    for bad in [True,False,0,1.0,-(1<<63)-1,1<<63]: assert not native_object_id(bad)
    def at(row,path,new):
        for key in path[:-1]:row=row[key]
        row[path[-1]]=new
    counterexamples = [
        (['writer_id'],True),(['proposal_id'],0),(['writer_id'],float(value['writer_id'])),
        (['proposal_id'],1<<63),(['campaign_id'],-101),(['proposal_id'],value['writer_id']),
        (['final_shared_pending','profile','unknown_input','kept'],['changed',7]),
        (['final_shared_pending','identity'],{'fixture_only':False}),
        (['writer_active','request','target_owner'],'2'),
        (['original_memory','unlocked'],1.0),(['successful_authorized_retry'],True),
        (['proposal_semantics','sections','progress','owner','variant_type'],True),
    ]
    refused = 0
    for path,new in counterexamples:
        mutated = copy.deepcopy(value);at(mutated,path,new)
        try:failure_structure(mutated,identity,runtime)
        except AssertionError:refused+=1
        else:raise AssertionError('Counterexample accepted: '+repr(path))
    assert refused == len(counterexamples)
    output = Path(__file__).with_suffix('.json')
    record = {'schema':'cloud_failure_pure_data_counterexamples_v1','signed_refcounted_ID_fixture_accepted':True,
              'zero_bool_float_and_out_of_range_IDs_rejected':True,'counterexamples_refused':refused,
              'unknown_nested_shared_data_drift_rejected':True,'fixtures_are_synthetic_untrusted_JSON':True,
              'actual_Popen_created':False,'full_consumer_constructed_or_called':False,
              'physical_profile_or_journal_checked':False,'Godot_ConfigFile_parsed':False,
              'native_started':False,'original19_qualified':False,'overall_goal_qualified':False}
    with output.open('x',encoding='utf-8',newline='\n') as stream:
        json.dump(record,stream,indent=2);stream.write('\n')
    print(json.dumps(record))

if __name__ == '__main__': main()

"""Pure hostile-report tests. Never construct Suite/consumer/Popen or SDK."""
from copy import deepcopy
import argparse
import hashlib
import json
from pathlib import Path
import uuid

from campaign_real_sdk_bootstrap_evidence_v2 import (
    ContractError, decode_report, no_links, report_structure, source_contract,
)


def run(work_root):
    root=Path(__file__).resolve().parents[1]
    no_links(work_root)
    assert work_root.is_absolute() and not work_root.resolve().is_relative_to(root.resolve())
    output=work_root/('evidence_'+uuid.uuid4().hex);output.mkdir(parents=True,exist_ok=False)
    probe=root/'qa/campaign_progress_recovery_20261008/real_sdk_bootstrap_candidate_v3/real_sdk_bootstrap_v3.gd'
    catalog=root/'scripts/steam_achievement_catalog.gd'
    contract=source_contract(probe,catalog)
    identity={'ok':True,'code':'OK','identity_schema':1,'identity_scope':'installed_inputs',
              'content_version':'source-v1:'+'a'*64,'source_sha256':'a'*64,
              'engine_binary_sha256':'d'*64,'source_mode':False,'save_eligible':True,
              'save_code':'OK','rules_sha256':'b'*64,'file_count':1,'total_bytes':1,
              'provider_sha256':'c'*64,'optional_content':[
                  {'path':p,'present':False,'bytes':0,'sha256':''}
                  for p in ('content/units.json','content/abilities.json')]}
    descriptor={'schema':'campaign_real_sdk_bootstrap_descriptor_v2','case':'bootstrap_only',
                'nonce':uuid.uuid4().hex,'private_user_directory':str(output/'synthetic_profile'/'appdata'/'Godot'/'app_userdata'/'fixture'),
                'private_windows_roots':{key:str(output/'synthetic_profile'/key.lower()) for key in ('APPDATA','LOCALAPPDATA','TEMP','TMP')},
                'executable':str(output/'not_a_real_export.exe'),'executable_sha256':'d'*64,
                'installed_identity':identity,'expected_account':'1',
                'normal_startup_account_side_effects_acknowledged':True}
    snapshot={'ok':True,'owner':'1','source':'current_cache','handle':'',
              'stats':{key:0 for key in contract['stat_fields']},
              'unlocked':{key:False for key in contract['achievement_ids']}}
    sample={'schema':'campaign_real_sdk_bootstrap_v3','passed':True,
            'checks':contract['required_labels'],'failures':[],'pid':123,
            'nonce':descriptor['nonce'],'descriptor_sha256':'e'*64,'account':'1','app_id':5088120,
            'identity':identity,'user_directory':descriptor['private_user_directory'],
            'initial_native_stats':deepcopy(snapshot),'final_native_stats':deepcopy(snapshot),
            'executable':descriptor['executable'],'executable_sha256':'d'*64,'elapsed_ms':4000,
            'time_scale':1.0,'physics_ticks':60,'native_bootstrap_observed':True,
            'windows_environment':deepcopy(descriptor['private_windows_roots']),
            'successful_cloud_retry_qualified':False,'same_profile_restart_qualified':False,
            'SDK_reward_once_qualified':False,'original19_qualified':False,'overall_goal_qualified':False}
    def check(value):return report_structure(value,descriptor,'e'*64,123,contract)
    def encode(value):return (json.dumps(value,ensure_ascii=False,indent=2)+'\n').encode()
    checked=check(decode_report(encode(sample)))
    assert checked['native_execution_proven'] is False
    evolving=deepcopy(sample);evolving['final_native_stats']['stats']['TOTAL_WINS']=1
    evolving['final_native_stats']['unlocked']['ACH_CLEAR_LEVEL_1']=True
    check(evolving) # Startup synchronization is not assumed to leave values equal.
    results=[]
    def rejects(label,callback):
        try:callback()
        except (ContractError,OSError):results.append({'label':label,'rejected':True})
        else:raise AssertionError('accepted '+label)
    for label,key,value in [
        ('wrong schema','schema','campaign_real_sdk_bootstrap_v1'),('false passed','passed',False),
        ('numeric passed','passed',1),('unknown field','extra',0),('lost label','checks',sample['checks'][:-1]),
        ('reordered labels','checks',list(reversed(sample['checks']))),('declared failure','failures',['failure']),
        ('PID bool','pid',True),('wrong PID','pid',124),('wrong nonce','nonce','f'*32),
        ('wrong descriptor','descriptor_sha256','f'*64),('wrong owner','account','2'),
        ('numeric account','account',1),('other AppID','app_id',1),('AppID float','app_id',5088120.0),
        ('user drift','user_directory',str(output/'other')),
        ('executable drift','executable',str(output/'other.exe')),
        ('binary drift','executable_sha256','f'*64),('time bool','time_scale',True),
        ('accelerated time','time_scale',2.0),('physics fractional','physics_ticks',60.0),
        ('elapsed fractional','elapsed_ms',1.5),('elapsed exceeded','elapsed_ms',180001),
        ('rewards claimed','SDK_reward_once_qualified',True),('cloud retry claimed','successful_cloud_retry_qualified',True),
        ('restart claimed','same_profile_restart_qualified',True),('whole19 claimed','original19_qualified',True),
        ('overall claimed','overall_goal_qualified',True),
    ]:
        bad=deepcopy(sample);bad[key]=value;rejects(label,lambda bad=bad:check(bad))
    for label,key,value in [('missing stat','stats',{}),('missing achievement','unlocked',{}),
                            ('other snapshot owner','owner','2'),('requested snapshot','source','requested_user_cache'),
                            ('nonempty handle','handle','a'*32),('numeric snapshot OK','ok',1)]:
        bad=deepcopy(sample);bad['initial_native_stats'][key]=value;rejects(label,lambda bad=bad:check(bad))
    for label,value in [('bool stat',True),('fractional stat',1.5),('negative stat',-1),('overflow stat',2147483648)]:
        bad=deepcopy(sample);bad['final_native_stats']['stats']['TOTAL_WINS']=value;rejects(label,lambda bad=bad:check(bad))
    bad=deepcopy(sample);bad['final_native_stats']['unlocked']['ACH_CLEAR_LEVEL_1']=1
    rejects('numeric unlocked',lambda:check(bad))
    for label,value in [('missing actual env root',{}),('outside actual temp',dict(descriptor['private_windows_roots'],TEMP=str(output/'outside'))),('numeric actual temp',dict(descriptor['private_windows_roots'],TEMP=1))]:
        bad=deepcopy(sample);bad['windows_environment']=value;rejects(label,lambda bad=bad:check(bad))
    bad=deepcopy(sample);bad['identity']['source_mode']=True
    rejects('source-backed identity',lambda:check(bad))
    raw=encode(sample)
    rejects('duplicate report field',lambda:decode_report(raw.replace(b'"pid": 123',b'"pid": 123,"pid":123')))
    rejects('nested duplicate stat',lambda:decode_report(raw.replace(b'"TOTAL_WINS": 0',b'"TOTAL_WINS":0,"TOTAL_WINS":0')))
    rejects('invalid UTF8',lambda:decode_report(b'{"bad":"\xff"}'))
    rejects('BOM',lambda:decode_report(b'\xef\xbb\xbf'+raw))
    rejects('nonfinite clock',lambda:decode_report(raw.replace(b'"time_scale": 1.0',b'"time_scale": NaN')))
    rejects('overflow exponent',lambda:decode_report(raw.replace(b'"time_scale": 1.0',b'"time_scale": 1e999')))
    result={'schema':'real_sdk_bootstrap_evidence_cpu_regression_v2','passed':True,
            'rejection_count':len(results),'rejections':results,'source_contract':contract,
            'ordinary_cache_changes_allowed':True,'synthetic_data_are_not_native_evidence':True,
            'consumer_constructed':False,'full_validate_run':False,'Popen_constructed':False,
            'native_started':False,'SDK_reward_once_qualified':False,'overall_goal_qualified':False,
            'run':str(output)}
    (output/'report.json').write_bytes(encode(result))
    return result


if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--work-root',type=Path,required=True)
    print(json.dumps(run(parser.parse_args().work_root),ensure_ascii=False))

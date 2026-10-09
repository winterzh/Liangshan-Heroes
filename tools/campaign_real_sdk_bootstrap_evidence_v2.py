"""Full bootstrap V3 report contract and held-original-process consumer.

No process launcher or SDK calls. A future producer must seal the real export,
successful durable prior, specific native admission and account protections.
Current-cache snapshots never qualify server upload or once-only rewards.
"""
from __future__ import annotations
import ast
import hashlib
import json
import math
from pathlib import Path
import re
import subprocess

from campaign_real_sdk_bootstrap_contract_v3 import (
    ContractError, decode_descriptor, exact_absolute_path, no_links, require,
    validate_compiled_identity,
)
from durable_campaign_full_runtime import OwnedSerialBatch, error_count

REPORT_FIELDS = frozenset({
    'schema','passed','checks','failures','pid','nonce','descriptor_sha256','account',
    'app_id','identity','user_directory','initial_native_stats','final_native_stats',
    'executable','executable_sha256','elapsed_ms','time_scale','physics_ticks',
    'native_bootstrap_observed','windows_environment','successful_cloud_retry_qualified',
    'same_profile_restart_qualified','SDK_reward_once_qualified',
    'original19_qualified','overall_goal_qualified',
})
BROADER_FLAGS = ('successful_cloud_retry_qualified','same_profile_restart_qualified',
                 'SDK_reward_once_qualified','original19_qualified','overall_goal_qualified')
STAT_FIELDS = ('TOTAL_WINS','TOTAL_KILLS','DEFENSE_WINS','AI_WINS')


def typed_same(left,right):
    if type(left) is not type(right): return False
    if type(left) is dict:
        return left.keys()==right.keys() and all(typed_same(left[k],right[k]) for k in left)
    if type(left) is list:
        return len(left)==len(right) and all(typed_same(a,b) for a,b in zip(left,right))
    return left==right


def source_contract(probe: Path, catalog: Path) -> dict:
    """Read the fixed GD source labels/catalog declaration, not native results."""
    probe=exact_absolute_path(str(probe)); catalog=exact_absolute_path(str(catalog))
    probe_raw=probe.read_bytes(); catalog_raw=catalog.read_bytes()
    source=probe_raw.decode('utf-8',errors='strict')
    text=catalog_raw.decode('utf-8',errors='strict')
    labels=re.findall(r'"([^"\n]+)"\): (?:_finish\(\)|get_tree\(\)\.quit\(2\))',source)
    require(len(labels)==len(set(labels))==18 and 'campaign_real_sdk_bootstrap_v3' in source,
            'FIXED_V2_COMPLETE_LABEL_SOURCE')
    match=re.search(r'^const STATS := (.+)$',text,re.M)
    require(match is not None and ast.literal_eval(match.group(1))==list(STAT_FIELDS),
            'EXACT_FOUR_STAT_SOURCE')
    require('const APP_ID := 5088120' in text and 'for i in range(8):' in text
            and '"ACH_CLEAR_LEVEL_%d" % (i + 1)' in text
            and '"ACH_STORY_LEVEL_%d" % (i + 1)' in text
            and '_entry("ACH_ALL_CLEAR"' in text and '_entry("ACH_ALL_STORY"' in text
            and 'for n in [30, 60]:' in text and '_entry("ACH_DEFENSE_%d" % n' in text,
            'FIXED_CAMPAIGN_AND_DEFENSE_CATALOG_SOURCE')
    rows=re.search(r'^\s*for row in (\[.+\]):$',text,re.M)
    require(rows is not None and '"ACH_%s_%d" % [row[1], n]' in text,
            'STAT_ACHIEVEMENT_SOURCE')
    threshold_rows=ast.literal_eval(rows.group(1))
    require(typed_same([[row[0],row[1],row[2]] for row in threshold_rows], [
        ['TOTAL_WINS','WINS',[10,50,100]], ['TOTAL_KILLS','KILLS',[1000,10000,100000]],
        ['DEFENSE_WINS','DEFENSE_WINS',[10,50]],['AI_WINS','AI_WINS',[1,10]]]),
        'EXACT_STAT_THRESHOLD_SOURCE')
    ids=[f'ACH_{kind}_LEVEL_{i}' for i in range(1,9) for kind in ('CLEAR','STORY')]
    ids += ['ACH_ALL_CLEAR','ACH_ALL_STORY','ACH_DEFENSE_30','ACH_DEFENSE_60']
    ids += [f'ACH_{row[1]}_{n}' for row in threshold_rows for n in row[2]]
    require(len(ids)==len(set(ids))==30,'EXACT_THIRTY_ACHIEVEMENT_SOURCE')
    def pin(path,raw):
        return {'path':str(path),'bytes':len(raw),'sha256':hashlib.sha256(raw).hexdigest()}
    return {'schema':'real_sdk_bootstrap_report_source_contract_v2',
            'probe':pin(probe,probe_raw),'catalog':pin(catalog,catalog_raw),
            'required_labels':labels,'stat_fields':list(STAT_FIELDS),'achievement_ids':ids,
            'native_execution_proven':False}


def decode_report(raw: bytes) -> dict:
    require(type(raw) is bytes and 0<len(raw)<=1048576,'REPORT_BYTE_BUDGET')
    def pairs(rows):
        result={}
        for key,value in rows:
            require(key not in result,'REPORT_DUPLICATE_KEY'); result[key]=value
        return result
    def constant(token):
        raise ContractError('REPORT_NONFINITE:'+token)
    def floating(token):
        value=float(token);require(math.isfinite(value),'REPORT_NONFINITE');return value
    try:
        text=raw.decode('utf-8',errors='strict')
        require(not text.startswith('\ufeff'),'REPORT_UTF8_BOM')
        result=json.loads(text,object_pairs_hook=pairs,parse_constant=constant,parse_float=floating)
        require(type(result) is dict and set(result)==REPORT_FIELDS,'REPORT_EXACT_FIELDS')
    except ContractError:
        raise
    except (UnicodeError,ValueError,RecursionError) as error:
        raise ContractError('REPORT_UTF8_OR_JSON') from error
    return result


def snapshot_structure(value: dict, account: str, contract: dict) -> None:
    require(type(value) is dict and set(value)=={'ok','owner','source','handle','stats','unlocked'}
            and value['ok'] is True and value['owner']==account
            and value['source']=='current_cache' and value['handle']=='',
            'WHOLE_ORIGINAL_CURRENT_CACHE_SNAPSHOT')
    require(type(value['stats']) is dict and set(value['stats'])==set(contract['stat_fields'])
            and all(type(v) is int and 0<=v<=2147483647 for v in value['stats'].values()),
            'WHOLE_FOUR_NATIVE_STAT_VALUES')
    require(type(value['unlocked']) is dict
            and set(value['unlocked'])==set(contract['achievement_ids'])
            and all(type(v) is bool for v in value['unlocked'].values()),
            'WHOLE_THIRTY_NATIVE_ACHIEVEMENT_VALUES')


def report_structure(value: dict, descriptor: dict, descriptor_sha256: str,
                     pid: int, contract: dict) -> dict:
    """Pure untrusted shape check; PID/source inputs supplied here prove no process."""
    require(type(value) is dict and set(value)==REPORT_FIELDS,'REPORT_EXACT_FIELDS')
    require(value['schema']=='campaign_real_sdk_bootstrap_v3' and value['passed'] is True
            and value['native_bootstrap_observed'] is True and value['failures']==[]
            and type(value['failures']) is list,'COMPLETE_V3_BOOTSTRAP_REPORT')
    require(type(value['checks']) is list and value['checks']==contract['required_labels']
            and all(type(v) is str for v in value['checks']), 'ALL_EIGHTEEN_ORDERED_CHECKS')
    require(type(pid) is int and pid>0 and type(value['pid']) is int and value['pid']==pid
            and value['nonce']==descriptor['nonce']
            and value['descriptor_sha256']==descriptor_sha256,'EXACT_PID_NONCE_DESCRIPTOR')
    require(type(value['app_id']) is int and value['app_id']==5088120
            and type(value['account']) is str and value['account']==descriptor['expected_account'],
            'EXACT_OBSERVED_ACCOUNT_AND_APP')
    require(exact_absolute_path(value['user_directory'])==exact_absolute_path(descriptor['private_user_directory'])
            and exact_absolute_path(value['executable'])==exact_absolute_path(descriptor['executable'])
            and value['executable_sha256']==descriptor['executable_sha256'],'EXACT_RUNTIME_PATHS_AND_EXE')
    require(type(value['windows_environment']) is dict
            and set(value['windows_environment'])=={'APPDATA','LOCALAPPDATA','TEMP','TMP'}
            and all(type(v) is str and v for v in value['windows_environment'].values())
            and typed_same(value['windows_environment'],descriptor['private_windows_roots']),
            'ACTUAL_FOUR_NATIVE_ENV_ROOTS')
    validate_compiled_identity(value['identity'],descriptor['executable_sha256'])
    require(typed_same(value['identity'],descriptor['installed_identity']),'EXACT_COMPLETE_NATIVE_IDENTITY')
    require(type(value['elapsed_ms']) is int and 0<=value['elapsed_ms']<=180000
            and type(value['time_scale']) in (int,float) and value['time_scale']==1
            and type(value['physics_ticks']) is int and value['physics_ticks']==60,
            'BOUNDED_NORMAL_CLOCK')
    require(all(value[key] is False for key in BROADER_FLAGS),'NO_BROADER_QUALIFICATION')
    snapshot_structure(value['initial_native_stats'],value['account'],contract)
    snapshot_structure(value['final_native_stats'],value['account'],contract)
    # Normal initialization may synchronize values. Equality or monotonicity is
    # not a once-only reward invariant and is deliberately not invented here.
    return {'structure_verified':True,'native_execution_proven':False,
            'SDK_reward_once_qualified':False,'overall_goal_qualified':False}


class BootstrapEvidence:
    """Consume while the original owned Popen and lease are still retained.

    Future Suite API: run/batch/spec/descriptor/path/pin, remember/freeze_bytes,
    integrity. spec['bootstrap_report_contract'] is sealed before export/run.
    No current complete Suite/launcher is asserted by this component.
    """
    def __init__(self,suite):
        self.suite=suite; self.completed=False
        self.contract=suite.spec['bootstrap_report_contract']
        require(isinstance(suite.batch,OwnedSerialBatch),'ORIGINAL_OWNED_SERIAL_BATCH')
        actual=source_contract(Path(self.contract['probe']['path']),Path(self.contract['catalog']['path']))
        require(typed_same(actual,self.contract),'EXACT_SEALED_PROBE_AND_CATALOG_CONTRACT')
        for key in ('probe','catalog'): suite.remember(self.contract[key])

    def validate(self,step):
        suite=self.suite;batch=suite.batch;child=batch.child
        require(not self.completed and step is batch.steps[-1]
                and step['label']=='real_sdk_bootstrap' and step['phase_kind']=='normal_exported_sdk'
                and step['complete'] is False and step['process_terminal'] is True
                and type(step['exit_code']) is int and step['exit_code']==0
                and batch.locked and batch.lease_ready,'ORIGINAL_HELD_TERMINAL_STEP_AND_LEASE')
        require(type(child) is subprocess.Popen and child.pid==step['pid']
                and child.poll()==0 and child.wait(timeout=0)==0 and child.returncode==0,
                'ORIGINAL_ACTUAL_POPEN_TERMINAL_HANDLE')
        executable=exact_absolute_path(suite.descriptor['executable'])
        require(child.args==step['command']==[str(executable)]
                and batch.engine==executable and batch.engine_sha256==suite.descriptor['executable_sha256'],
                'EXACT_NORMAL_EXPORTED_COMMAND')
        output=exact_absolute_path(step['output']);profile=exact_absolute_path(step['profile'])
        require(output.is_relative_to(exact_absolute_path(str(suite.run))/'steps')
                and profile.is_relative_to(exact_absolute_path(str(suite.run))/'profiles'),
                'ORIGINAL_OUTPUT_AND_PROFILE_CUSTODY')
        user=exact_absolute_path(suite.descriptor['private_user_directory'])
        require(user.is_relative_to(profile/'appdata'),'EXACT_PRIVATE_RUNTIME_USER_DIRECTORY')
        expected_roots={key:str(profile/key.lower()) for key in ('APPDATA','LOCALAPPDATA','TEMP','TMP')}
        require(typed_same(suite.descriptor['private_windows_roots'],expected_roots),
                'DESCRIPTOR_ROOTS_MATCH_ACTUAL_PHASE_PROFILE')
        expected_env={**expected_roots,'LSH_REAL_SDK_DESCRIPTOR':str(suite.descriptor_path),
                      'LSH_REAL_SDK_DESCRIPTOR_SHA256':suite.descriptor_pin['sha256']}
        require(typed_same(step['environment_overrides'],expected_env),
                'ORIGINAL_PHASE_EXACT_PRIVATE_ENV_AND_DESCRIPTOR')
        log=output/'native.log';no_links(log)
        original_log=suite.freeze_bytes(log,step['log_sha256'])
        require(error_count(log)==step['engine_errors']==0,'ORIGINAL_ZERO_ERROR_NATIVE_LOG')
        nonce=suite.descriptor['nonce']
        require(nonce==step['nonce'],'ORIGINAL_DESCRIPTOR_PHASE_NONCE')
        marker=f'REAL_SDK_BOOTSTRAP_COMPLETE {step["pid"]} {nonce} 18 true'
        require(original_log.decode('utf-8',errors='strict').splitlines().count(marker)==1,
                'EXACT_ONE_ORIGINAL_COMPLETE_MARKER')
        descriptor_raw=suite.freeze_bytes(suite.descriptor_path,suite.descriptor_pin['sha256'])
        require(hashlib.sha256(descriptor_raw).hexdigest()==suite.descriptor_pin['sha256'],
                'ORIGINAL_DESCRIPTOR_BYTES_STILL_BOUND')
        require(typed_same(decode_descriptor(descriptor_raw),suite.descriptor),
                'WHOLE_ORIGINAL_DESCRIPTOR_DICTIONARY')
        report=user/f'real_sdk_bootstrap_{nonce}.json';no_links(report)
        raw=suite.freeze_bytes(report)
        value=decode_report(raw)
        report_structure(value,suite.descriptor,suite.descriptor_pin['sha256'],child.pid,self.contract)
        suite.integrity()
        self.completed=True
        return {'schema':'real_sdk_bootstrap_closed_report_v2','report_sha256':hashlib.sha256(raw).hexdigest(),
                'pid':child.pid,'nonce':nonce,'checks':18,'closed_bootstrap_report_verified':True,
                'snapshot_source':'current_cache','SDK_reward_once_qualified':False,
                'successful_cloud_retry_qualified':False,'overall_goal_qualified':False}

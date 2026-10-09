"""Compare original native full-CFG projections; never parse CFG on the host.

Supplied projections alone do not prove a native process or ConfigFile load.
The report consumer must bind actual Popen/source/exports and physical hashes.
"""
import hashlib
from pathlib import Path
import subprocess

from campaign_callback_packets_v2 import json_value, same
from campaign_file_fault_records_v1 import hex_value
from durable_campaign_full_matrices import require

CASE = 'cloud_applying_callback_no_upload_claim'
FIELDS = {'schema','pid','nonce','case','identity','user_directory','original_present','original_cfg_sha256',
          'original_sections_json','original_semantics_sha256','expected_sections_json','expected_semantics_sha256',
          'full_case_qualified','SDK_reward_once_qualified','overall_goal_qualified'}
TARGET_TYPES = {'schema':2,'unlocked':2,'records':27,'owner':4}
DATA_TYPES = set(range(23)) | set(range(27,39))


def projection(text,digest):
    require(type(text) is str and hex_value(digest) and hashlib.sha256(text.encode('utf-8')).hexdigest() == digest,
            'Original native full projection JSON bytes/SHA')
    value = json_value(text)
    require(type(value) is dict, 'Whole native sections dictionary')
    for section,keys in value.items():
        require(type(section) is str and type(keys) is dict, 'Original full section/key maps')
        for key,row in keys.items():
            require(type(key) is str and type(row) is dict and set(row) == {'variant_type','canonical'}
                    and type(row['variant_type']) is int and row['variant_type'] in DATA_TYPES
                    and type(row['canonical']) is str and row['canonical'], 'Full supported data-Variant type and original canonical probe text')
    return value


def expected_delta(original,expected):
    require(set(expected) == set(original) | {'progress'}, 'Expected cloud proposal preserves every original section')
    for section,keys in original.items():
        if section != 'progress':
            require(same(expected[section],keys), 'Unknown original section and all typed values preserved')
    old = original.get('progress',{})
    new = expected['progress']
    require(set(new) == set(old) | set(TARGET_TYPES), 'Expected cloud proposal preserves unknown progress keys')
    for key,row in old.items():
        if key not in TARGET_TYPES:
            require(same(new[key],row), 'Original unknown progress value/type/canonical preserved')
    require(all(new[key]['variant_type'] == kind for key,kind in TARGET_TYPES.items()), 'Native proposal has exact target progress Variant kinds')


def ready_projection(value,pid,nonce,identity,user,original_sha):
    require(type(user) is str and user, 'Original native user-directory text required, never reconstructed Path text')
    require(type(value) is dict and set(value) == FIELDS and value['schema'] == 'campaign_cloud_CFG_semantics_ready_v1'
            and type(value['pid']) is int and value['pid'] == pid and value['nonce'] == nonce and value['case'] == CASE
            and same(value['identity'],identity) and value['user_directory'] == user
            and type(value['original_present']) is bool and value['original_present'] is bool(original_sha)
            and value['original_cfg_sha256'] == original_sha
            and all(value[key] is False for key in ['full_case_qualified','SDK_reward_once_qualified','overall_goal_qualified']),
            'Whole original native semantics-ready binding and limited qualification')
    original = projection(value['original_sections_json'],value['original_semantics_sha256'])
    expected = projection(value['expected_sections_json'],value['expected_semantics_sha256'])
    require(value['original_present'] or original == {}, 'Physically absent original CFG projects to empty sections')
    expected_delta(original,expected)
    return original,expected


def bind_pre_arm_semantics(suite,step,controller,published):
    child = suite.batch.child
    require(isinstance(child,subprocess.Popen) and child is controller.child and child.poll() is None
            and child.pid == step['pid'] and controller.arm_request_sent is False and controller.packets.ready is None,
            'Actual original held process before arm and ready dispatch')
    controller.live()
    path = Path(published['published_path'])
    require(path == Path(step['output'])/'cloud_cfg_semantics_ready.json', 'Current original native semantics-ready export')
    raw = suite.freeze_bytes(path,published['sha256'])
    value = json_value(raw.decode('utf-8-sig'))
    ready_projection(value,step['pid'],step['nonce'],controller.packets.identity,controller.packets.user,controller.apply_ready['original_cfg_sha256'])
    step['cloud_cfg_semantics_ready'] = {'path':str(path),'sha256':published['sha256'],'bytes':len(raw)}
    suite.persist()


def validate_native_semantics(ready,final,pid,nonce,identity,user,original_sha,physical):
    require(type(physical) is dict and type(physical.get('journals')) is list and len(physical['journals']) == 2,
            'Both original production journal projections required')
    _,expected = ready_projection(ready,pid,nonce,identity,user,original_sha)
    require(type(final) is dict and set(final) == {'final_sections_json','final_semantics_sha256'}, 'Whole original final native semantics report')
    current = projection(final['final_sections_json'],final['final_semantics_sha256'])
    require(same(current,expected), 'Entire independently loaded final CFG equals expected original-preserving proposal')
    require(all(row['document']['semantics_sha256'] == final['final_semantics_sha256'] for row in physical['journals']),
            'Native full final projection SHA equals both original production journal semantics hashes')
    return {'native_final_projection_sha256':final['final_semantics_sha256'],
            'all_original_unknown_keys_preserved':True,'native_ownership_proven':False,
            'host_ConfigFile_parsed':False,'whole_case_qualified':False}

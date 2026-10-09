"""Freeze a real cloud-storage failure boundary candidate, without launching it."""
from pathlib import Path
import ast
import hashlib
import json
import re
import sys

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).parent
QA = HERE.parent
sys.path.insert(0,str(ROOT/'tools'))
sys.dont_write_bytecode = True
from run_durable_campaign_chain_v12 import canonical, verify_pin
from prepare_campaign_file_fault_labels_v3 import check_arguments, IDENTITY_FIELDS

def pin(path):
    raw = path.read_bytes()
    return {'path':str(path),'bytes':len(raw),'sha256':hashlib.sha256(raw).hexdigest()}

def functions(path):
    text = path.read_text(encoding='utf-8')
    return {part.split('(')[0]:part[part.index('\n')+1:] for part in re.split(r'(?m)^func ',text)[1:]}

def main():
    recipe_file = QA/'CLOUD_CASE_PRODUCER_SOURCE_RECIPE_V1.json'
    original = json.loads(recipe_file.read_bytes())
    recipe = original['recipe']
    assert canonical(recipe) == original['recipe_sha256']
    for row in recipe['pins']: verify_pin(row)
    first = json.loads((QA/'cloud_applying_driver_candidate_v3/SOURCE.json').read_bytes())
    gd = HERE/'campaign_original19_cloud_write_failure_v1.gd'
    parent = Path(first['parent_GD']['path'])
    assert pin(parent) == first['parent_GD']
    assert gd.read_text(encoding='utf-8').splitlines()[0] == 'extends "res://tools/campaign_original19_first_repeat_v1.gd"'
    child = functions(gd)
    assert '_run' not in child and '_restart' not in child
    inherited = check_arguments(functions(parent)['_run'])
    assert len(inherited) == 7
    header = [r['label_prefix'] for r in inherited[:3]]
    header += [inherited[3]['label_prefix']+field for field in IDENTITY_FIELDS]
    header += [r['label_prefix'] for r in inherited[4:]]
    inventory = {name:check_arguments(body) for name,body in child.items()}
    ordered = header + [r['label_prefix'] for r in inventory['_fresh']] + [r['label_prefix'] for r in inventory['_finish']]
    assert len(ordered) == len(set(ordered))
    rows = {r['path']:r for r in recipe['pins']}
    for path in [gd,Path(__file__),recipe_file,QA/'ORIGINAL19_R12_ADAPTATION_REQUIREMENTS_V1.json']:
        row = pin(path)
        assert row['path'] not in rows or rows[row['path']] == row
        rows[row['path']] = row
    inputs = json.loads(json.dumps(recipe['inputs']))
    inputs['schema'] = 'cloud_write_failure_inputs_recipe_v1'
    overlays = inputs['runtime_and_harness_overlays']
    alias = 'tools/'+gd.name
    assert alias not in {r['runtime_path'] for r in overlays}
    parent_alias = 'tools/'+parent.name
    assert any(r['runtime_path']==parent_alias and r['sha256']==pin(parent)['sha256'] for r in overlays)
    overlays.append({**pin(gd),'runtime_path':alias})
    inputs['execution_contract'] = {
        'case':'legacy_real_cloud_apply_failure_boundary','mode':'first',
        'Steam_disabled':True,'QA_mode_enabled':False,'synthetic_local_owner':'1',
        'implemented_scope':'real write failure, retained proposal and unauthorized real-UI retry boundary',
        'successful_authorized_same_writer_retry_required':True,
        'successful_authorized_same_writer_retry_implemented':False,
        'restart_implemented':False,'host_producer_implemented':False,
    }
    for row in rows.values(): verify_pin(row)
    source = {
        'schema':'cloud_write_failure_candidate_source_v1','candidate':pin(gd),'parent_GD':pin(parent),
        'builder':pin(Path(__file__)),'source_recipe_basis':pin(recipe_file),
        'source_recipe_basis_logical_sha256':original['recipe_sha256'],
        'case':'legacy_real_cloud_apply_failure_boundary','required_mode':'first',
        'closed_exports':['report.json'],'report_schema':'campaign_original19_cloud_write_failure_probe_v1',
        'pins':sorted(rows.values(),key=lambda row:row['path']),'inputs':inputs,
        'original19_full_case_implemented':False,'successful_authorized_retry_required':True,
        'successful_authorized_retry_implemented':False,'same_profile_restart_implemented':False,
        'host_producer_implemented':False,'host_consumer_implemented':False,
        'source_only':True,'GD_parsed':False,'native_started':False,
        'original19_qualified':False,'SDK_reward_once_qualified':False,'overall_goal_qualified':False,
        'approved_stages':[],
    }
    contract = {
        'schema':'cloud_write_failure_source_label_contract_v1','GD':pin(gd),'parent_GD':pin(parent),
        'builder':pin(Path(__file__)),'inherited_header_labels':header,
        'literal_check_inventory':inventory,'complete_local_boundary_labels':ordered,
        'source_label_count':len(ordered),'actual_pass_count':None,
        'full_case_qualification':False,'GD_parsed':False,'native_started':False,'approved_stages':[],
    }
    for name,value in [('SOURCE.json',source),('LOCAL_BOUNDARY_LABEL_CONTRACT_V1.json',contract)]:
        with (HERE/name).open('x',encoding='utf-8',newline='\n') as stream:
            json.dump(value,stream,ensure_ascii=False,indent=2);stream.write('\n')
    result={'source_preparation':True,'source_file':pin(HERE/'SOURCE.json'),
            'source_logical_sha256':canonical(source),'source_pins':len(rows),
            'runtime_aliases':len(overlays),'local_boundary_source_labels':len(ordered),
            'native_started':False,'full_original19_case_implemented':False}
    with (HERE/'PREPARATION_V1.json').open('x',encoding='utf-8',newline='\n') as stream:
        json.dump(result,stream,ensure_ascii=False,indent=2);stream.write('\n')
    print(json.dumps(result))

if __name__ == '__main__': main()
